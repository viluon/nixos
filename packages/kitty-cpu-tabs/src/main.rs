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
use nanoserde::DeJson;

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

const COLOR_HALF_LIFE: Duration = Duration::from_millis(250);

type Rgb = [f64; 3];

fn mix(start: Rgb, end: Rgb, weight: f64) -> Rgb {
    std::array::from_fn(|channel| start[channel] + (end[channel] - start[channel]) * weight)
}

fn hex(color: Rgb) -> String {
    let [red, green, blue] = color.map(|channel| channel.round() as u8);
    format!("#{red:02x}{green:02x}{blue:02x}")
}

#[derive(DeJson, Clone, Copy)]
struct TabColors {
    background: Rgb,
    foreground: Rgb,
}

impl TabColors {
    fn ease_towards(self, target: TabColors, elapsed: Duration) -> TabColors {
        let progress = 1.0 - 0.5_f64.powf(elapsed.div_duration_f64(COLOR_HALF_LIFE));
        TabColors {
            background: mix(self.background, target.background, progress),
            foreground: mix(self.foreground, target.foreground, progress),
        }
    }
}

fn kitty_color_args([active, inactive]: [TabColors; 2]) -> [String; 4] {
    [
        format!("active_bg={}", hex(active.background)),
        format!("inactive_bg={}", hex(inactive.background)),
        format!("active_fg={}", hex(active.foreground)),
        format!("inactive_fg={}", hex(inactive.foreground)),
    ]
}

#[derive(DeJson)]
struct Palette {
    active: TabColors,
    inactive: TabColors,
    heat: [Rgb; 3],
    hot_text: Rgb,
}

struct Heatmap {
    palette: Palette,
    max_usage: f64,
}

impl Heatmap {
    fn shade(&self, idle: TabColors, usage: f64) -> TabColors {
        if usage < 10.0 {
            return idle;
        }
        let heat = self.palette.heat;
        let position = ((usage - 10.0) / (self.max_usage - 10.0)).clamp(0.0, 1.0) * 2.0;
        let segment = (position as usize).min(1);
        TabColors {
            background: mix(heat[segment], heat[segment + 1], position - segment as f64),
            foreground: self.palette.hot_text,
        }
    }

    fn idle_colors(&self) -> [TabColors; 2] {
        [self.palette.active, self.palette.inactive]
    }

    fn colors(&self, usage: f64) -> [TabColors; 2] {
        self.idle_colors().map(|idle| self.shade(idle, usage))
    }
}

fn load_palette(path: &Path) -> Result<Palette> {
    Ok(Palette::deserialize_json(&fs::read_to_string(path)?)?)
}

#[derive(Clone, Copy)]
struct TabReading {
    usage: f64,
    shown: [TabColors; 2],
    shown_at: Instant,
}

#[derive(Default)]
struct Readings {
    processes: HashMap<(u32, u64), (u64, Instant)>,
    tabs: HashMap<(PathBuf, u64), TabReading>,
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

fn update(
    socket: &Path,
    previous: &Readings,
    current: &mut Readings,
    clock_ticks: f64,
    heatmap: &Heatmap,
    snapshot: &mut Option<Vec<Connection>>,
) -> Result<()> {
    let bytes = remote(socket, &["ls", "--match", "state:active"])?;
    let windows = Vec::<OsWindow>::deserialize_json(str::from_utf8(&bytes)?)
        .context("invalid Kitty response")?;
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
        let usage = (usage + old.map_or(usage, |old| old.usage)) / 2.0;
        let now = Instant::now();
        let shown = old.map_or(heatmap.idle_colors(), |old| old.shown);
        let elapsed = old.map_or(COLOR_HALF_LIFE, |old| now.duration_since(old.shown_at));
        let target = heatmap.colors(usage);
        let eased = std::array::from_fn(|role| shown[role].ease_towards(target[role], elapsed));
        let color_args = kitty_color_args(eased);
        if old.is_none() || kitty_color_args(shown) != color_args {
            let window_match = format!("window_id:{}", window.id);
            let mut command = vec!["set-tab-color", "--match", &window_match];
            command.extend(color_args.iter().map(String::as_str));
            remote(socket, &command)?;
        }
        current.tabs.insert(
            key,
            TabReading {
                usage,
                shown: eased,
                shown_at: now,
            },
        );
    }
    Ok(())
}

fn main() -> Result<()> {
    let runtime =
        PathBuf::from(env::var_os("XDG_RUNTIME_DIR").context("XDG_RUNTIME_DIR is unset")?);
    let clock_ticks = unsafe { libc::sysconf(libc::_SC_CLK_TCK) };
    ensure!(clock_ticks > 0, "cannot determine kernel clock tick rate");
    let palette_path = PathBuf::from(
        env::args_os()
            .nth(1)
            .context("usage: kitty-cpu-tabs PALETTE_JSON")?,
    );
    let heatmap = Heatmap {
        palette: load_palette(&palette_path)
            .with_context(|| format!("cannot load palette {}", palette_path.display()))?,
        max_usage: 95.0
            * thread::available_parallelism()
                .context("cannot determine available CPU count")?
                .get() as f64,
    };
    let mut previous = Readings::default();
    loop {
        let started = Instant::now();
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
                    &heatmap,
                    &mut snapshot,
                ) {
                    eprintln!("kitty-cpu-tabs: {}: {error:#}", socket.display());
                }
            }
        }
        previous = current;
        thread::sleep(Duration::from_millis(250).saturating_sub(started.elapsed()));
    }
}
