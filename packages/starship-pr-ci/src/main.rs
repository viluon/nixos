// Async prompt backend: reads a cache and spawns a detached refresh, never blocking
// on the network. Cache line is tab-separated: sha, state, detail, detail_url, pr_url.

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
}

impl Status {
    fn none() -> Self {
        Status {
            state: "none".into(),
            ..Default::default()
        }
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
    }
}

fn query_pr(host: &str) -> Option<Status> {
    let out = Command::new("gh")
        .args(["pr", "view", "--json", "state,statusCheckRollup,url"])
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
    query_pr(&host).unwrap_or_else(|| query_head(&host, &slug))
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
    let line = format!(
        "{head_sha}\t{}\t{}\t{}\t{}\n",
        st.state, st.detail, st.detail_url, st.pr_url
    );
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
        Some(c) => {
            let line = c.lines().next().unwrap_or("");
            let f: Vec<&str> = line.split('\t').collect();
            let get = |i: usize| f.get(i).copied().unwrap_or("").to_string();
            (
                get(0),
                Status {
                    state: get(1),
                    detail: get(2),
                    detail_url: get(3),
                    pr_url: get(4),
                },
            )
        }
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
                let num = st.pr_url.rsplit('/').next().unwrap_or("");
                osc8(&st.pr_url, &format!("{PR_ICON} #{num}"));
            }
        }
        "is-pr" => {
            if resolve().pr_url.is_empty() {
                std::process::exit(1);
            }
        }
        "is" => {
            let want = args.get(2).map(String::as_str).unwrap_or("");
            if resolve().state != want {
                std::process::exit(1);
            }
        }
        _ => {
            eprintln!("usage: starship-pr-ci [read|detail|link|is-pr|is <state>]");
            std::process::exit(2);
        }
    }
}
