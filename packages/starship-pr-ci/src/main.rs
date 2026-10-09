// Async prompt backend: reads a cache and spawns a detached refresh, never blocking
// on the network. Cache line is tab-separated: sha, state, detail, detail_url, pr_url, unresolved, queued.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime};

use serde_json::Value;

const TTL: Duration = Duration::from_secs(15);
const PRUNE_AGE: Duration = Duration::from_secs(30 * 24 * 60 * 60);
const LOCK_STALE: Duration = Duration::from_secs(60);
const PR_ICON: &str = "\u{f407}";
const QUEUED_PR_ICON: &str = "\u{f4db}";
const UNRESOLVED_ICON: &str = "\u{f41f}";

const PR_DETAILS_QUERY: &str = r#"
query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      mergeQueueEntry { id }
      reviewThreads(first:100){ nodes { isResolved } }
    }
  }
}
"#;

const GRAPHQL_QUERY: &str = r#"
query($owner:String!,$name:String!,$oid:GitObjectID!){
  repository(owner:$owner,name:$name){
    object(oid:$oid){ ... on Commit {
      statusCheckRollup { contexts(first:100){ nodes {
        __typename
        ... on CheckRun { name status conclusion detailsUrl }
        ... on StatusContext { context state targetUrl }
      } } }
    } }
  }
}
"#;

#[derive(Default, Clone)]
struct Status {
    state: String,
    detail: String,
    detail_url: String,
    pr_url: String,
    unresolved: String,
    queued: bool,
}

impl Status {
    fn none() -> Self {
        Status {
            state: "none".into(),
            ..Default::default()
        }
    }

    fn cache_line(&self, head_sha: &str) -> String {
        format!(
            "{head_sha}\t{}\t{}\t{}\t{}\t{}\t{}\n",
            self.state, self.detail, self.detail_url, self.pr_url, self.unresolved, self.queued
        )
    }

    fn from_cache(line: &str) -> (String, Self) {
        let fields: Vec<&str> = line.split('\t').collect();
        let get = |i: usize| fields.get(i).copied().unwrap_or("").to_string();
        (
            get(0),
            Self {
                state: get(1),
                detail: get(2),
                detail_url: get(3),
                pr_url: get(4),
                unresolved: get(5),
                queued: fields.get(6) == Some(&"true"),
            },
        )
    }

    fn pr_label(&self) -> String {
        let icon = if self.queued { QUEUED_PR_ICON } else { PR_ICON };
        let number = self.pr_url.rsplit('/').next().unwrap_or("");
        format!("{icon} #{number}")
    }
}

fn git(args: &[&str]) -> Option<String> {
    let out = Command::new("git")
        .args(args)
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
    if s.is_empty() { None } else { Some(s) }
}

fn cache_dir() -> PathBuf {
    let base = env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default()).join(".cache"));
    base.join("starship-pr-ci")
}

fn age(path: &Path) -> Option<Duration> {
    let mtime = fs::metadata(path).ok()?.modified().ok()?;
    SystemTime::now().duration_since(mtime).ok()
}

fn parse_remote(url: &str) -> (String, String) {
    let mut s = url;
    if let Some(i) = s.find("://") {
        s = &s[i + 3..];
    }
    if let Some(i) = s.find('@') {
        s = &s[i + 1..];
    }
    let sep = s.find(|c| c == '/' || c == ':');
    let (host, rest) = match sep {
        Some(i) => (&s[..i], &s[i + 1..]),
        None => (s, ""),
    };
    let slug = rest.strip_suffix(".git").unwrap_or(rest);
    (host.to_string(), slug.to_string())
}

fn remote_url() -> Option<String> {
    let branch = git(&["symbolic-ref", "--quiet", "--short", "HEAD"])?;
    let remote = git(&["config", &format!("branch.{branch}.remote")])
        .unwrap_or_else(|| "origin".to_string());
    git(&["remote", "get-url", &remote])
}

#[derive(PartialEq, Clone, Copy)]
enum St {
    Success,
    Failure,
    Pending,
}

impl St {
    fn label(self) -> &'static str {
        match self {
            St::Success => "success",
            St::Failure => "failure",
            St::Pending => "pending",
        }
    }
}

struct Check {
    name: String,
    url: String,
    st: St,
}

fn node(n: &Value) -> Check {
    let name = n["name"]
        .as_str()
        .or_else(|| n["context"].as_str())
        .unwrap_or("check")
        .to_string();
    let url = n["detailsUrl"]
        .as_str()
        .or_else(|| n["targetUrl"].as_str())
        .unwrap_or("")
        .to_string();
    let st = match n["__typename"].as_str().unwrap_or("") {
        "CheckRun" => {
            if n["status"].as_str() != Some("COMPLETED") {
                St::Pending
            } else {
                match n["conclusion"].as_str().unwrap_or("") {
                    "SUCCESS" | "NEUTRAL" | "SKIPPED" => St::Success,
                    _ => St::Failure,
                }
            }
        }
        "StatusContext" => match n["state"].as_str().unwrap_or("") {
            "SUCCESS" => St::Success,
            "PENDING" => St::Pending,
            _ => St::Failure,
        },
        _ => St::Pending,
    };
    Check { name, url, st }
}

// Winning state is failure > pending > success; detail is the sole winner's name
// (else the winner count), with a link only when that winner is unique.
fn verdict(nodes: &[Value]) -> Status {
    let checks: Vec<Check> = nodes.iter().map(node).collect();
    if checks.is_empty() {
        return Status::none();
    }
    let winning = if checks.iter().any(|c| c.st == St::Failure) {
        St::Failure
    } else if checks.iter().any(|c| c.st == St::Pending) {
        St::Pending
    } else {
        St::Success
    };
    let members: Vec<&Check> = checks.iter().filter(|c| c.st == winning).collect();
    let (detail, detail_url) = if members.len() == 1 {
        (members[0].name.clone(), members[0].url.clone())
    } else {
        (members.len().to_string(), String::new())
    };
    Status {
        state: winning.label().into(),
        detail,
        detail_url,
        pr_url: String::new(),
        unresolved: String::new(),
        queued: false,
    }
}

fn pr_details(pr: &Value) -> Option<(String, bool)> {
    let nodes = pr["reviewThreads"]["nodes"].as_array()?;
    let count = nodes
        .iter()
        .filter(|t| t["isResolved"].as_bool() == Some(false))
        .count();
    let unresolved = if count == 0 {
        String::new()
    } else {
        count.to_string()
    };
    Some((unresolved, pr["mergeQueueEntry"].is_object()))
}

fn query_pr_details(host: &str, owner: &str, name: &str, number: i64) -> Option<(String, bool)> {
    let out = Command::new("gh")
        .args(["api", "graphql"])
        .args([
            "-F",
            &format!("owner={owner}"),
            "-F",
            &format!("name={name}"),
            "-F",
            &format!("number={number}"),
        ])
        .args(["-f", &format!("query={PR_DETAILS_QUERY}")])
        .env("GH_HOST", host)
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let v: Value = serde_json::from_slice(&out.stdout).ok()?;
    pr_details(&v["data"]["repository"]["pullRequest"])
}

fn query_pr(host: &str, slug: &str) -> Option<Status> {
    let out = Command::new("gh")
        .args(["pr", "view", "--json", "state,statusCheckRollup,url,number"])
        .env("GH_HOST", host)
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    let v: Value = serde_json::from_slice(&out.stdout).ok()?;
    if v["state"].as_str() != Some("OPEN") {
        return None;
    }
    let mut st = verdict(v["statusCheckRollup"].as_array()?);
    st.pr_url = v["url"].as_str().unwrap_or("").to_string();
    if let (Some((owner, name)), Some(number)) = (slug.split_once('/'), v["number"].as_i64()) {
        if let Some((unresolved, queued)) = query_pr_details(host, owner, name, number) {
            st.unresolved = unresolved;
            st.queued = queued;
        }
    }
    Some(st)
}

fn query_head(host: &str, slug: &str) -> Status {
    let (owner, name) = match slug.split_once('/') {
        Some((o, n)) => (o, n),
        None => return Status::none(),
    };
    let sha = match git(&["rev-parse", "--quiet", "--verify", "HEAD"]) {
        Some(s) => s,
        None => return Status::none(),
    };
    let out = Command::new("gh")
        .args(["api", "graphql"])
        .args([
            "-F",
            &format!("owner={owner}"),
            "-F",
            &format!("name={name}"),
            "-F",
            &format!("oid={sha}"),
        ])
        .args(["-f", &format!("query={GRAPHQL_QUERY}")])
        .env("GH_HOST", host)
        .stderr(Stdio::null())
        .output();
    let out = match out {
        Ok(o) if o.status.success() => o,
        _ => return Status::none(),
    };
    let v: Value = match serde_json::from_slice(&out.stdout) {
        Ok(v) => v,
        Err(_) => return Status::none(),
    };
    match v["data"]["repository"]["object"]["statusCheckRollup"]["contexts"]["nodes"].as_array() {
        Some(nodes) => verdict(nodes),
        None => Status::none(),
    }
}

fn gh_authed(host: &str) -> bool {
    Command::new("gh")
        .args(["auth", "status", "--hostname", host])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn query_ci() -> Status {
    let url = match remote_url() {
        Some(u) => u,
        None => return Status::none(),
    };
    let (host, slug) = parse_remote(&url);
    if host.is_empty() || !gh_authed(&host) {
        return Status::none();
    }
    query_pr(&host, &slug).unwrap_or_else(|| query_head(&host, &slug))
}

fn refresh(repo_root: &str, head_sha: &str, cache_file: &Path) {
    let lock = cache_file.with_extension("lock");
    if let Some(a) = age(&lock) {
        if a > LOCK_STALE {
            let _ = fs::remove_file(&lock);
        }
    }
    if fs::OpenOptions::new()
        .create_new(true)
        .write(true)
        .open(&lock)
        .is_err()
    {
        return;
    }
    let _ = env::set_current_dir(repo_root);
    let st = query_ci();
    let line = st.cache_line(head_sha);
    let tmp = cache_file.with_extension("tmp");
    if fs::write(&tmp, line).is_ok() {
        let _ = fs::rename(&tmp, cache_file);
    }
    prune();
    let _ = fs::remove_file(&lock);
}

fn prune() {
    let dir = cache_dir();
    if let Ok(entries) = fs::read_dir(&dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.is_file() {
                if let Some(a) = age(&p) {
                    if a > PRUNE_AGE {
                        let _ = fs::remove_file(&p);
                    }
                }
            }
        }
    }
}

fn spawn_refresh(repo_root: &str, head_sha: &str, cache_file: &Path) {
    let exe = match env::current_exe() {
        Ok(p) => p,
        Err(_) => return,
    };
    let _ = Command::new("setsid")
        .arg("-f")
        .arg(exe)
        .arg("__refresh")
        .arg(repo_root)
        .arg(head_sha)
        .arg(cache_file)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}

fn resolve() -> Status {
    let info = match git(&[
        "rev-parse",
        "--show-toplevel",
        "HEAD",
        "--abbrev-ref",
        "HEAD",
    ]) {
        Some(i) => i,
        None => return Status::none(),
    };
    let mut lines = info.lines();
    let (repo_root, head_sha, branch) = match (lines.next(), lines.next(), lines.next()) {
        (Some(r), Some(s), Some(b)) => (r, s, b),
        _ => return Status::none(),
    };

    let mut hasher = DefaultHasher::new();
    repo_root.hash(&mut hasher);
    branch.hash(&mut hasher);
    let cache_file = cache_dir().join(format!("{:016x}", hasher.finish()));

    let cached = fs::read_to_string(&cache_file).ok();
    let (cached_sha, status) = match &cached {
        Some(c) => Status::from_cache(c.lines().next().unwrap_or("")),
        None => (String::new(), Status::none()),
    };

    let stale = cached_sha != head_sha || age(&cache_file).map(|a| a >= TTL).unwrap_or(true);
    if stale {
        let _ = fs::create_dir_all(cache_dir());
        spawn_refresh(repo_root, head_sha, &cache_file);
    }

    if status.state.is_empty() {
        Status::none()
    } else {
        status
    }
}

fn osc8(url: &str, text: &str) {
    if url.is_empty() {
        print!("{text}");
    } else {
        print!("\x1b]8;;{url}\x1b\\{text}\x1b]8;;\x1b\\");
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let cmd = args.get(1).map(String::as_str).unwrap_or("read");

    match cmd {
        "__refresh" => {
            if let (Some(root), Some(sha), Some(cache)) = (args.get(2), args.get(3), args.get(4)) {
                refresh(root, sha, Path::new(cache));
            }
        }
        "read" => print!("{}", resolve().state),
        "detail" => {
            let st = resolve();
            osc8(&st.detail_url, &st.detail);
        }
        "link" => {
            let st = resolve();
            if !st.pr_url.is_empty() {
                osc8(&st.pr_url, &st.pr_label());
            }
        }
        "is-pr" => {
            if resolve().pr_url.is_empty() {
                std::process::exit(1);
            }
        }
        "is-queued" => {
            let st = resolve();
            if st.pr_url.is_empty() || !st.queued {
                std::process::exit(1);
            }
        }
        "has-unresolved" => {
            if resolve().unresolved.is_empty() {
                std::process::exit(1);
            }
        }
        "unresolved" => {
            let st = resolve();
            if !st.unresolved.is_empty() {
                let url = if st.pr_url.is_empty() {
                    String::new()
                } else {
                    format!("{}/files", st.pr_url)
                };
                osc8(&url, &format!("{UNRESOLVED_ICON} {}", st.unresolved));
            }
        }
        "is" => {
            let want = args.get(2).map(String::as_str).unwrap_or("");
            if resolve().state != want {
                std::process::exit(1);
            }
        }
        _ => {
            eprintln!(
                "usage: starship-pr-ci [read|detail|link|is-pr|is-queued|unresolved|has-unresolved|is <state>]"
            );
            std::process::exit(2);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn queue_membership_and_unresolved_threads() {
        let mut pr = json!({
            "mergeQueueEntry": null,
            "reviewThreads": {
                "nodes": [{"isResolved": false}, {"isResolved": true}]
            }
        });
        assert_eq!(pr_details(&pr), Some(("1".into(), false)));
        pr["mergeQueueEntry"] = json!({"id": "queue-entry"});
        assert_eq!(pr_details(&pr), Some(("1".into(), true)));
        pr["reviewThreads"]["nodes"] = json!([]);
        assert_eq!(pr_details(&pr), Some((String::new(), true)));
        assert_eq!(pr_details(&Value::Null), None);
    }

    #[test]
    fn cache_round_trip_preserves_queue_and_existing_fields() {
        for queued in [false, true] {
            let status = Status {
                state: "pending".into(),
                detail: "build".into(),
                detail_url: "https://github.com/owner/repo/actions/runs/1".into(),
                pr_url: "https://github.com/owner/repo/pull/42".into(),
                unresolved: "2".into(),
                queued,
            };
            let line = status.cache_line("head-sha");
            let (sha, cached) = Status::from_cache(line.trim_end_matches('\n'));
            assert_eq!(sha, "head-sha");
            assert_eq!(cached.cache_line(&sha), line);
        }
    }

    #[test]
    fn old_cache_defaults_to_unqueued() {
        let (_, status) = Status::from_cache(
            "head-sha\tsuccess\tbuild\t\thttps://github.com/owner/repo/pull/42\t2",
        );
        assert!(!status.queued);
        assert_eq!(status.unresolved, "2");
        assert_eq!(status.pr_label(), "\u{f407} #42");
    }

    #[test]
    fn queued_pr_uses_queue_icon() {
        let status = Status {
            pr_url: "https://github.com/owner/repo/pull/42".into(),
            queued: true,
            ..Status::none()
        };
        assert_eq!(status.pr_label(), "\u{f4db} #42");
    }
}
