use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::net::SocketAddr;
use std::os::unix::fs::FileTypeExt;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::str;
use std::thread;
use std::time::{Duration, Instant};

use anyhow::{Context, Result, ensure};
use nanoserde::{DeJson, DeJsonState, DeJsonTok};

#[derive(DeJson)]
struct OsWindow {
    tabs: Vec<Tab>,
}

#[derive(DeJson)]
struct Tab {
    id: u64,
    windows: Vec<Window>,
}

#[derive(DeJson)]
struct Window {
    id: u64,
    foreground_processes: Vec<Process>,
}

#[derive(DeJson)]
struct Process {
    pid: u32,
    cmdline: Option<Vec<String>>,
}

impl Process {
    fn is_mill_launcher(&self) -> bool {
        self.cmdline
            .iter()
            .flatten()
            .any(|arg| arg.starts_with("mill.main.cli=") || arg.starts_with("-Dmill.main.cli="))
    }
}

struct Connection {
    local: SocketAddr,
    peer: SocketAddr,
    pids: Vec<u32>,
}

#[derive(Default)]
struct Readings {
    processes: HashMap<(u32, u64), (u64, Instant)>,
    tabs: HashMap<(PathBuf, u64), f64>,
}

fn run(args: &[&str]) -> Result<Vec<u8>> {
    let output = Command::new("timeout")
        .args(["--kill-after=1s", "2s"])
        .args(args)
        .output()
        .with_context(|| format!("cannot run {}", args[0]))?;
    ensure!(
        output.status.success(),
        "{} exited with {}: {}",
        args[0],
        output.status,
        String::from_utf8_lossy(&output.stderr)
    );
    Ok(output.stdout)
}

fn remote(socket: &Path, args: &[&str]) -> Result<Vec<u8>> {
    let address = format!("unix:{}", socket.display());
    let mut command = vec!["kitten", "@", "--to", &address];
    command.extend_from_slice(args);
    run(&command)
}

fn connections() -> Result<Vec<Connection>> {
    let bytes = run(&[
        "ss",
        "-Hntp",
        "state",
        "established",
        "( src 127.0.0.1 or src [::1] or src [::ffff:127.0.0.1] )",
    ])?;
    str::from_utf8(&bytes)?
        .lines()
        .map(|line| {
            let mut fields = line.split_whitespace().skip(2);
            let mut local: SocketAddr = fields.next().context("missing local endpoint")?.parse()?;
            let mut peer: SocketAddr = fields.next().context("missing peer endpoint")?.parse()?;
            local.set_ip(local.ip().to_canonical());
            peer.set_ip(peer.ip().to_canonical());
            let pids = line
                .split(",pid=")
                .skip(1)
                .map(|owner| {
                    Ok(owner
                        .split_once(',')
                        .context("invalid socket owner")?
                        .0
                        .parse()?)
                })
                .collect::<Result<_>>()?;
            Ok(Connection { local, peer, pids })
        })
        .collect()
}

fn mill_daemon(pid: u32, snapshot: &mut Option<Vec<Connection>>) -> Result<Option<u32>> {
    let sockets = match snapshot {
        Some(sockets) => sockets,
        None => snapshot.insert(connections()?),
    };
    for client in sockets
        .iter()
        .filter(|connection| connection.pids.contains(&pid))
    {
        let Some(server) = sockets
            .iter()
            .find(|connection| connection.local == client.peer && connection.peer == client.local)
        else {
            continue;
        };
        for &daemon in &server.pids {
            let bytes = match fs::read(format!("/proc/{daemon}/cmdline")) {
                Ok(bytes) => bytes,
                Err(error)
                    if error.kind() == std::io::ErrorKind::NotFound
                        || error.raw_os_error() == Some(libc::ESRCH) =>
                {
                    continue;
                }
                Err(error) => return Err(error).context("cannot identify socket peer"),
            };
            if bytes
                .split(|byte| *byte == 0)
                .any(|arg| arg == b"mill.daemon.MillDaemonMain")
            {
                return Ok(Some(daemon));
            }
        }
    }
    Ok(None)
}

fn process_stat(bytes: &[u8]) -> Result<(u64, u64)> {
    let end = bytes
        .iter()
        .rposition(|byte| *byte == b')')
        .context("missing process name")?;
    let fields: Vec<_> = str::from_utf8(&bytes[end + 1..])?
        .split_whitespace()
        .collect();
    ensure!(fields.len() > 19, "incomplete process stat");
    Ok((
        fields[19].parse()?,
        fields[11].parse::<u64>()? + fields[12].parse::<u64>()?,
    ))
}

fn cpu_usage(
    pids: &HashSet<u32>,
    previous: &Readings,
    current: &mut Readings,
    clock_ticks: f64,
) -> Result<f64> {
    let mut ticks_per_second = 0.0;
    for &pid in pids {
        let bytes = match fs::read(format!("/proc/{pid}/stat")) {
            Ok(bytes) => bytes,
            Err(error)
                if error.kind() == std::io::ErrorKind::NotFound
                    || error.raw_os_error() == Some(libc::ESRCH) =>
            {
                continue;
            }
            Err(error) => return Err(error).context("cannot read process stat"),
        };
        let (start, ticks) = process_stat(&bytes)?;
        let key = (pid, start);
        let now = Instant::now();
        if let Some((old_ticks, old_time)) = previous.processes.get(&key) {
            let elapsed = now.duration_since(*old_time).as_secs_f64();
            if elapsed > 0.0 {
                ticks_per_second += ticks.saturating_sub(*old_ticks) as f64 / elapsed;
            }
        }
        current.processes.insert(key, (ticks, now));
    }
    Ok(100.0 * ticks_per_second / clock_ticks)
}

fn tab_color(usage: f64) -> &'static str {
    match usage {
        usage if usage < 10.0 => "NONE",
        usage if usage < 75.0 => "#f9e2af",
        _ => "#f38ba8",
    }
}

fn update(
    socket: &Path,
    previous: &Readings,
    current: &mut Readings,
    clock_ticks: f64,
    snapshot: &mut Option<Vec<Connection>>,
) -> Result<()> {
    let bytes = remote(socket, &["ls", "--match", "state:active"])?;
    let mut input = str::from_utf8(&bytes)?.chars();
    let mut state = DeJsonState::default();
    state.next(&mut input);
    state.next_tok(&mut input)?;
    let windows = Vec::<OsWindow>::de_json(&mut state, &mut input)?;
    ensure!(
        state.tok == DeJsonTok::Eof,
        "trailing data in Kitty response"
    );
    for tab in windows.into_iter().flat_map(|window| window.tabs) {
        let Some(window) = tab.windows.first() else {
            continue;
        };
        let key = (socket.to_path_buf(), tab.id);
        let old = previous.tabs.get(&key).copied();
        let mut pids = window
            .foreground_processes
            .iter()
            .map(|process| process.pid)
            .collect::<HashSet<_>>();
        for process in window
            .foreground_processes
            .iter()
            .filter(|process| process.is_mill_launcher())
        {
            if let Some(daemon) = mill_daemon(process.pid, snapshot)? {
                pids.remove(&process.pid);
                pids.insert(daemon);
            }
        }
        let usage = cpu_usage(&pids, previous, current, clock_ticks)?;
        let usage = (usage + old.unwrap_or(usage)) / 2.0;
        let color = tab_color(usage);
        if old.map(tab_color) != Some(color) {
            let foreground = if color == "NONE" { "NONE" } else { "#1e1e2e" };
            remote(
                socket,
                &[
                    "set-tab-color",
                    "--match",
                    &format!("window_id:{}", window.id),
                    &format!("active_bg={color}"),
                    &format!("inactive_bg={color}"),
                    &format!("active_fg={foreground}"),
                    &format!("inactive_fg={foreground}"),
                ],
            )?;
        }
        current.tabs.insert(key, usage);
    }
    Ok(())
}

fn main() -> Result<()> {
    let runtime =
        PathBuf::from(env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR is unset")?);
    let clock_ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) };
    ensure!(clock_ticks > 0, "cannot determine kernel clock tick rate");
    let mut previous = Readings::default();
    loop {
        let mut current = Readings::default();
        let mut snapshot = None;
        for entry in fs::read_dir(&runtime)? {
            let entry = entry?;
            if entry
                .file_name()
                .to_string_lossy()
                .starts_with("kitty-cpu-")
                && entry.file_type()?.is_socket()
            {
                let socket = entry.path();
                if let Err(error) = update(
                    &socket,
                    &previous,
                    &mut current,
                    clock_ticks as f64,
                    &mut snapshot,
                ) {
                    eprintln!("kitty-cpu-tabs: {}: {error:#}", socket.display());
                }
            }
        }
        previous = current;
        thread::sleep(Duration::from_secs(1));
    }
}
