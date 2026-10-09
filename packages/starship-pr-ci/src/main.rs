// Async prompt backend: reads a cache and spawns a detached refresh, never blocking
// on the network.

use std::collections::hash_map::DefaultHasher;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime};

use anyhow::{Context, Result, ensure};
use atomicwrites::{AllowOverwrite, AtomicFile};
use clap::{Parser, Subcommand, ValueEnum};
use nanoserde::{DeJson, DeJsonState, DeJsonTok, SerJson};

const TTL: Duration = Duration::from_secs(15);
const PRUNE_AGE: Duration = Duration::from_secs(30 * 24 * 60 * 60);
const PR_ICON: &str = "\u{f407}";
const QUEUED_PR_ICON: &str = "\u{f4db}";
const UNRESOLVED_ICON: &str = "\u{f41f}";

const CHECKS_JQ: &str = r#"
(. // []) | map({
  name: (.name // .context),
  url: (.detailsUrl // .targetUrl),
  kind: {(.__typename): .}
})
"#;

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

#[derive(Parser)]
struct Cli {
    #[command(subcommand)]
    command: Option<PromptCommand>,
}

#[derive(Subcommand)]
enum PromptCommand {
    Read,
    Detail,
    Link,
    IsPr,
    IsQueued,
    HasUnresolved,
    Unresolved,
    Is {
        #[arg(value_enum)]
        state: State,
    },
    #[command(name = "__refresh", hide = true)]
    Refresh {
        repo_root: PathBuf,
        head_sha: String,
        cache_file: PathBuf,
    },
}

#[derive(Default, DeJson, SerJson)]
struct Status {
    state: State,
    detail: String,
    detail_url: String,
    pr_url: String,
    unresolved: usize,
    queued: bool,
}

#[derive(DeJson, SerJson)]
struct Cache {
    head_sha: String,
    status: Status,
}

impl Status {
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
    base.join("starship-pr-ci").join("v3")
}

fn age(path: &Path) -> Option<Duration> {
    let mtime = fs::metadata(path).ok()?.modified().ok()?;
    SystemTime::now().duration_since(mtime).ok()
}

fn parse_remote(url: &str) -> (String, String) {
    let authority = url.split_once("://").map_or(url, |(_, rest)| rest);
    let remote = authority
        .split_once('@')
        .map_or(authority, |(_, rest)| rest);
    let (host, path) = remote.split_once(['/', ':']).unwrap_or((remote, ""));
    let slug = path.strip_suffix(".git").unwrap_or(path);
    (host.to_string(), slug.to_string())
}

fn remote_url() -> Option<String> {
    let branch = git(&["symbolic-ref", "--quiet", "--short", "HEAD"])?;
    let remote = git(&["config", &format!("branch.{branch}.remote")])
        .unwrap_or_else(|| "origin".to_string());
    git(&["remote", "get-url", &remote])
}

#[derive(Default, PartialEq, Eq, PartialOrd, Ord, Clone, DeJson, SerJson, ValueEnum)]
#[cfg_attr(test, derive(Debug))]
enum State {
    #[default]
    #[nserde(rename = "none")]
    None,
    #[nserde(rename = "success")]
    Success,
    #[nserde(rename = "pending")]
    Pending,
    #[nserde(rename = "failure")]
    Failure,
}

impl State {
    fn label(self) -> &'static str {
        match self {
            Self::None => "none",
            Self::Success => "success",
            Self::Pending => "pending",
            Self::Failure => "failure",
        }
    }
}

#[derive(DeJson)]
struct Check {
    name: String,
    url: Option<String>,
    kind: CheckKind,
}

#[derive(DeJson)]
enum CheckKind {
    CheckRun {
        status: String,
        conclusion: Option<String>,
    },
    StatusContext {
        state: String,
    },
}

impl CheckKind {
    fn state(&self) -> State {
        match self {
            CheckKind::CheckRun { status, .. } if status != "COMPLETED" => State::Pending,
            CheckKind::CheckRun { conclusion, .. } => match conclusion.as_deref() {
                Some("SUCCESS" | "NEUTRAL" | "SKIPPED") => State::Success,
                _ => State::Failure,
            },
            CheckKind::StatusContext { state } => match state.as_str() {
                "SUCCESS" => State::Success,
                "PENDING" => State::Pending,
                _ => State::Failure,
            },
        }
    }
}

fn verdict(checks: &[Check]) -> Status {
    let Some(winning) = checks.iter().map(|check| check.kind.state()).max() else {
        return Status::default();
    };
    let members: Vec<&Check> = checks
        .iter()
        .filter(|c| c.kind.state() == winning)
        .collect();
    let (detail, detail_url) = match members.as_slice() {
        [check] => (check.name.clone(), check.url.clone().unwrap_or_default()),
        checks => (checks.len().to_string(), String::new()),
    };
    Status {
        state: winning,
        detail,
        detail_url,
        ..Status::default()
    }
}

#[derive(DeJson)]
struct ReviewThreads {
    nodes: Vec<ReviewThread>,
}

#[derive(DeJson)]
struct ReviewThread {
    #[nserde(rename = "isResolved")]
    is_resolved: bool,
}

#[derive(DeJson)]
struct PrDetails {
    #[nserde(rename = "reviewThreads")]
    review_threads: ReviewThreads,
    #[nserde(rename = "mergeQueueEntry")]
    queued: bool,
}

#[derive(DeJson)]
struct PullRequest {
    state: String,
    #[nserde(rename = "statusCheckRollup")]
    status_check_rollup: Option<Vec<Check>>,
    url: String,
    number: u64,
}

fn decode_json<T: DeJson>(bytes: &[u8]) -> Result<T> {
    let mut input = std::str::from_utf8(bytes)?.chars();
    let mut state = DeJsonState::default();
    state.next(&mut input);
    state.next_tok(&mut input)?;
    let value = T::de_json(&mut state, &mut input)?;
    ensure!(state.tok == DeJsonTok::Eof, "trailing data in JSON");
    Ok(value)
}

fn gh<T: DeJson>(host: &str, args: &[&str]) -> Option<T> {
    let out = Command::new("gh")
        .args(args)
        .env("GH_HOST", host)
        .stderr(Stdio::null())
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    decode_json(&out.stdout)
        .inspect_err(|error| eprintln!("starship-pr-ci: invalid GitHub response: {error}"))
        .ok()
}

fn graphql<T: DeJson>(
    host: &str,
    slug: &str,
    query: &str,
    selector: &str,
    variable: &str,
    value: &str,
) -> Option<T> {
    let (owner, name) = slug.split_once('/')?;
    gh(
        host,
        &[
            "api",
            "graphql",
            "-F",
            &format!("owner={owner}"),
            "-F",
            &format!("name={name}"),
            "-F",
            &format!("{variable}={value}"),
            "-f",
            &format!("query={query}"),
            "--jq",
            selector,
        ],
    )
}

fn query_pr(host: &str, slug: &str) -> Option<Status> {
    let pr: PullRequest = gh(
        host,
        &[
            "pr",
            "view",
            "--json",
            "state,statusCheckRollup,url,number",
            "--jq",
            &format!(".statusCheckRollup |= ({CHECKS_JQ})"),
        ],
    )?;
    if pr.state != "OPEN" {
        return None;
    }
    let mut status = verdict(pr.status_check_rollup.as_deref().unwrap_or_default());
    status.pr_url = pr.url;
    if let Some(details) = graphql::<PrDetails>(
        host,
        slug,
        PR_DETAILS_QUERY,
        ".data.repository.pullRequest | .mergeQueueEntry = (.mergeQueueEntry != null)",
        "number",
        &pr.number.to_string(),
    ) {
        status.unresolved = details
            .review_threads
            .nodes
            .iter()
            .filter(|t| !t.is_resolved)
            .count();
        status.queued = details.queued;
    }
    Some(status)
}

fn query_head(host: &str, slug: &str) -> Option<Status> {
    let sha = git(&["rev-parse", "--quiet", "--verify", "HEAD"])?;
    let checks: Vec<Check> = graphql(
        host,
        slug,
        GRAPHQL_QUERY,
        &format!(".data.repository.object.statusCheckRollup.contexts.nodes | {CHECKS_JQ}"),
        "oid",
        &sha,
    )?;
    Some(verdict(&checks))
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

fn query_ci() -> Option<Status> {
    let url = remote_url()?;
    let (host, slug) = parse_remote(&url);
    if host.is_empty() || !gh_authed(&host) {
        return None;
    }
    query_pr(&host, &slug).or_else(|| query_head(&host, &slug))
}

fn refresh(repo_root: &Path, head_sha: &str, cache_file: &Path) -> Result<()> {
    let lock = fs::OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .open(cache_file.with_extension("lock"))
        .context("cannot open cache lock")?;
    match lock.try_lock() {
        Ok(()) => {}
        Err(fs::TryLockError::WouldBlock) => return Ok(()),
        Err(fs::TryLockError::Error(error)) => {
            return Err(error).context("cannot lock cache");
        }
    }
    env::set_current_dir(repo_root).context("cannot enter repository")?;
    let cache = Cache {
        head_sha: head_sha.to_string(),
        status: query_ci().unwrap_or_default(),
    };
    AtomicFile::new(cache_file, AllowOverwrite)
        .write(|file| file.write_all(cache.serialize_json().as_bytes()))
        .context("cannot write cache")?;
    prune();
    Ok(())
}

fn prune() {
    let dir = cache_dir();
    if let Ok(entries) = fs::read_dir(&dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().is_none_or(|extension| extension != "lock") && p.is_file() {
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
        None => return Status::default(),
    };
    let mut lines = info.lines();
    let (repo_root, head_sha, branch) = match (lines.next(), lines.next(), lines.next()) {
        (Some(r), Some(s), Some(b)) => (r, s, b),
        _ => return Status::default(),
    };

    let mut hasher = DefaultHasher::new();
    repo_root.hash(&mut hasher);
    branch.hash(&mut hasher);
    let cache_file = cache_dir().join(format!("{:016x}", hasher.finish()));

    let cached = fs::read(&cache_file).ok().and_then(|bytes| {
        decode_json::<Cache>(&bytes)
            .inspect_err(|error| eprintln!("starship-pr-ci: invalid cache: {error}"))
            .ok()
    });
    let stale = cached
        .as_ref()
        .is_none_or(|cache| cache.head_sha != head_sha)
        || age(&cache_file).is_none_or(|age| age >= TTL);
    if stale {
        let _ = fs::create_dir_all(cache_dir());
        spawn_refresh(repo_root, head_sha, &cache_file);
    }

    cached.map(|cache| cache.status).unwrap_or_default()
}

fn osc8(url: &str, text: &str) {
    if url.is_empty() {
        print!("{text}");
    } else {
        print!("\x1b]8;;{url}\x1b\\{text}\x1b]8;;\x1b\\");
    }
}

fn main() -> Result<()> {
    match Cli::parse().command.unwrap_or(PromptCommand::Read) {
        PromptCommand::Refresh {
            repo_root,
            head_sha,
            cache_file,
        } => {
            refresh(&repo_root, &head_sha, &cache_file)?;
        }
        PromptCommand::Read => print!("{}", resolve().state.label()),
        PromptCommand::Detail => {
            let st = resolve();
            osc8(&st.detail_url, &st.detail);
        }
        PromptCommand::Link => {
            let st = resolve();
            if !st.pr_url.is_empty() {
                osc8(&st.pr_url, &st.pr_label());
            }
        }
        PromptCommand::IsPr => {
            if resolve().pr_url.is_empty() {
                std::process::exit(1);
            }
        }
        PromptCommand::IsQueued => {
            let st = resolve();
            if st.pr_url.is_empty() || !st.queued {
                std::process::exit(1);
            }
        }
        PromptCommand::HasUnresolved => {
            if resolve().unresolved == 0 {
                std::process::exit(1);
            }
        }
        PromptCommand::Unresolved => {
            let st = resolve();
            if st.unresolved > 0 {
                let url = if st.pr_url.is_empty() {
                    String::new()
                } else {
                    format!("{}/files", st.pr_url)
                };
                osc8(&url, &format!("{UNRESOLVED_ICON} {}", st.unresolved));
            }
        }
        PromptCommand::Is { state } => {
            if resolve().state != state {
                std::process::exit(1);
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cache_rejects_trailing_documents() {
        let cache = Cache {
            head_sha: "head".into(),
            status: Status::default(),
        }
        .serialize_json();
        assert!(decode_json::<Cache>(format!("{cache} \n").as_bytes()).is_ok());
        assert!(decode_json::<Cache>(format!("{cache} {{}}").as_bytes()).is_err());
    }

    #[test]
    fn remote_transports_resolve_to_same_repository() {
        for remote in [
            "git@github.com:owner/repo.git",
            "ssh://git@github.com/owner/repo.git",
            "https://github.com/owner/repo.git",
            "https://github.com/owner/repo",
        ] {
            assert_eq!(
                parse_remote(remote),
                ("github.com".into(), "owner/repo".into())
            );
        }
    }

    #[test]
    fn pr_icon_reflects_queue_membership() {
        let mut status = Status {
            pr_url: "https://github.com/owner/repo/pull/42".into(),
            ..Status::default()
        };
        assert_eq!(status.pr_label(), "\u{f407} #42");
        status.queued = true;
        assert_eq!(status.pr_label(), "\u{f4db} #42");
    }

    #[test]
    fn check_runs_classify_completion_and_conclusion() {
        for (status, conclusion, expected) in [
            ("QUEUED", None, State::Pending),
            ("IN_PROGRESS", Some("SUCCESS"), State::Pending),
            ("COMPLETED", Some("SUCCESS"), State::Success),
            ("COMPLETED", Some("NEUTRAL"), State::Success),
            ("COMPLETED", Some("SKIPPED"), State::Success),
            ("COMPLETED", Some("FAILURE"), State::Failure),
            ("COMPLETED", Some("CANCELLED"), State::Failure),
            ("COMPLETED", Some("TIMED_OUT"), State::Failure),
            ("COMPLETED", None, State::Failure),
        ] {
            let kind = CheckKind::CheckRun {
                status: status.into(),
                conclusion: conclusion.map(String::from),
            };
            assert_eq!(kind.state(), expected);
        }
    }

    #[test]
    fn status_contexts_classify_errors_as_failures() {
        for (state, expected) in [
            ("SUCCESS", State::Success),
            ("PENDING", State::Pending),
            ("FAILURE", State::Failure),
            ("ERROR", State::Failure),
        ] {
            let kind = CheckKind::StatusContext {
                state: state.into(),
            };
            assert_eq!(kind.state(), expected);
        }
    }

    #[test]
    fn verdict_uses_highest_priority_and_links_only_unique_winner() {
        let mut checks = Vec::<Check>::deserialize_json(r#"[
            {"name": "pass", "kind": {"StatusContext": {"state": "SUCCESS"}}},
            {"name": "wait", "kind": {"StatusContext": {"state": "PENDING"}}},
            {"name": "fail", "url": "https://example.com/fail", "kind": {"StatusContext": {"state": "FAILURE"}}}
        ]"#).unwrap();
        let status = verdict(&checks);
        assert_eq!(status.state, State::Failure);
        assert_eq!(status.detail, "fail");
        assert_eq!(status.detail_url, "https://example.com/fail");
        checks.push(
            Check::deserialize_json(
                r#"{"name": "error", "kind": {"StatusContext": {"state": "ERROR"}}}"#,
            )
            .unwrap(),
        );
        let status = verdict(&checks);
        assert_eq!(status.detail, "2");
        assert!(status.detail_url.is_empty());
        assert_eq!(verdict(&checks[..2]).state, State::Pending);
        assert_eq!(verdict(&checks[..1]).state, State::Success);
        assert_eq!(verdict(&[]).state, State::None);
    }
}
