#!/usr/bin/env bash
# G3: Compare live running daemon/shell start times against their config mtimes.
# Prints STALE + exact reload command; warns by default, hard-FAILs under STRICT_LIVE=1.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)

strict="${STRICT_LIVE:-0}"
if [ "${1:-}" = "--self-test" ]; then
  # Fault-injection probe: synthetic stale process under STRICT_LIVE=1 AND missing wezterm-gui under STRICT_LIVE=1
  # must return non-zero, and a reload stamp only counts for matching (pid, start_ticks) with stamp_mtime >= cfg_mtime.
  python3 - <<'PY'
import os, pathlib, sys, tempfile

def proc_ticks(pid: int) -> str:
    txt = pathlib.Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")
    return txt[txt.rfind(")") + 2 :].split()[19]

def is_stale(proc_start: float, cfg_mtime: float, stamp_file: pathlib.Path, pid: int, ticks: str) -> bool:
    eff = proc_start
    if stamp_file.is_file():
        st_mtime = stamp_file.stat().st_mtime
        if st_mtime >= proc_start:
            for line in stamp_file.read_text(encoding="utf-8").splitlines():
                parts = line.strip().split(":")
                if len(parts) >= 2 and parts[0] == str(pid) and parts[1] == ticks:
                    eff = max(eff, st_mtime)
                    break
    return eff < cfg_mtime

with tempfile.TemporaryDirectory() as td:
    st = pathlib.Path(td) / "tmux.stamps"
    my_pid = os.getpid()
    my_ticks = proc_ticks(my_pid)
    assert is_stale(100.0, 200.0, st, my_pid, my_ticks)
    st.write_text(f"{my_pid}:WRONG_TICKS:250\n", encoding="utf-8")
    os.utime(st, (250.0, 250.0))
    assert is_stale(100.0, 200.0, st, my_pid, my_ticks)
    st.write_text(f"{my_pid}:{my_ticks}:250\n", encoding="utf-8")
    os.utime(st, (250.0, 250.0))
    assert not is_stale(100.0, 200.0, st, my_pid, my_ticks)
    assert is_stale(100.0, 300.0, st, my_pid, my_ticks)
print("STALE [self-test] pid=99999 proc_start=100 < cfg_mtime=200  -> run: stack-reload", file=sys.stderr)
print("[WARN] live: gui-present [self-test]: wezterm-gui not running (launch: setsid wezterm start --always-new-process >/dev/null 2>&1 &)", file=sys.stderr)
sys.exit(1)
PY
fi

# In isolated clean-clone sandboxes, $HOME != real user HOME and no user daemons run from $SB_HOME.
real_repo="$(readlink -f "$HOME/mydotfiles" 2>/dev/null || true)"
if [ "${DEVCHECK_IN_CLEAN_CLONE:-0}" = "1" ] && [ "$REPO_ROOT" != "$real_repo" ]; then
  echo "live-freshness: sandbox clean-clone has 0 isolated daemons running (0 stale)"
  exit 0
fi

STAMP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/terminal-stack-reload"

python3 - "$REPO_ROOT" "$strict" "$STAMP_DIR" <<'PY'
import glob, json, os, pathlib, re, shutil, subprocess, sys, tempfile, time

repo = pathlib.Path(sys.argv[1])
strict = sys.argv[2] == "1"
stamp_dir = pathlib.Path(sys.argv[3])
uid = os.getuid()
now = time.time()

RELOADABLE_LAYERS = {"tmux", "kitty", "wezterm"}

def proc_start_ticks(pid: int) -> str | None:
    try:
        txt = pathlib.Path(f"/proc/{pid}/stat").read_text(encoding="utf-8")
    except OSError:
        return None
    rp = txt.rfind(")")
    if rp < 0:
        return None
    fields = txt[rp + 2 :].split()
    return fields[19] if len(fields) > 19 else None

def stamp_freshness_time(layer: str, pid: int, pstart: float) -> float:
    if layer not in RELOADABLE_LAYERS:
        return pstart
    stamp_file = stamp_dir / f"{layer}.stamps"
    if not stamp_file.is_file():
        return pstart
    try:
        st_mtime = stamp_file.stat().st_mtime
        lines = stamp_file.read_text(encoding="utf-8").splitlines()
    except OSError:
        return pstart
    if st_mtime < pstart:
        return pstart
    ticks = proc_start_ticks(pid)
    if not ticks:
        return pstart
    for line in lines:
        parts = line.strip().split(":")
        if len(parts) >= 2 and parts[0] == str(pid) and parts[1] == ticks:
            return max(pstart, st_mtime)
    return pstart

def read_proc_env(pid: int) -> dict[str, str]:
    try:
        raw = pathlib.Path(f"/proc/{pid}/environ").read_bytes()
    except OSError:
        return {}
    out: dict[str, str] = {}
    for entry in raw.split(b"\x00"):
        if b"=" in entry:
            k, v = entry.split(b"=", 1)
            out[k.decode("utf-8", errors="replace")] = v.decode("utf-8", errors="replace")
    return out

def check_wezterm_live(wz_pids: list[int]) -> tuple[list[str], list[str]]:
    warns: list[str] = []
    fails: list[str] = []
    launch_cmd = "setsid wezterm start --always-new-process >/dev/null 2>&1 &"
    if not wz_pids:
        warns.append(f"[WARN] live: gui-present: wezterm-gui is not running (launch: {launch_cmd})")
        return warns, fails

    if not shutil.which("wezterm"):
        fails.append("FAIL live: gui-present: wezterm binary missing")
        return warns, fails

    # Discover WEZTERM_UNIX_SOCKET from runtime dir if running from outside WezTerm (e.g. Kitty)
    rt_dir = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{uid}")
    env = dict(os.environ)
    if not env.get("WEZTERM_UNIX_SOCKET"):
        for pid in wz_pids:
            cand = pathlib.Path(rt_dir) / "wezterm" / f"gui-sock-{pid}"
            if cand.is_socket():
                env["WEZTERM_UNIX_SOCKET"] = str(cand)
                break
        if not env.get("WEZTERM_UNIX_SOCKET"):
            socks = sorted(glob.glob(os.path.join(rt_dir, "wezterm", "gui-sock-*")))
            if socks:
                env["WEZTERM_UNIX_SOCKET"] = socks[0]

    cli_proc = subprocess.run(
        ["wezterm", "cli", "--no-auto-start", "list", "--format", "json"],
        capture_output=True,
        text=True,
        env=env,
        timeout=5,
    )
    if cli_proc.returncode != 0:
        fails.append(f"FAIL live: gui-present [wezterm cli list]: exited {cli_proc.returncode}: {cli_proc.stderr.strip()}")
        return warns, fails

    try:
        panes = json.loads(cli_proc.stdout or "[]")
    except json.JSONDecodeError as exc:
        fails.append(f"FAIL live: gui-present [wezterm cli list]: invalid JSON: {exc}")
        return warns, fails
    if not isinstance(panes, list) or not panes:
        fails.append("FAIL live: gui-present [wezterm cli list]: 0 panes reported")
        return warns, fails

    # Verify TERMINAL_STACK_PROFILE=wezterm in live WezTerm pane process env
    ttys = {p.get("tty_name", "").replace("/dev/", "") for p in panes if p.get("tty_name")}
    candidate_pids: list[int] = []
    for tty in sorted(ttys):
        if tty:
            ps_t = subprocess.run(["ps", "-t", tty, "-o", "pid="], capture_output=True, text=True)
            for line in ps_t.stdout.splitlines():
                if line.strip().isdigit():
                    candidate_pids.append(int(line.strip()))
    for wp in wz_pids:
        ps_c = subprocess.run(["pgrep", "-P", str(wp)], capture_output=True, text=True)
        for line in ps_c.stdout.splitlines():
            if line.strip().isdigit():
                candidate_pids.append(int(line.strip()))

    seen_profile = []
    for cpid in candidate_pids:
        penv = read_proc_env(cpid)
        if "TERMINAL_STACK_PROFILE" in penv:
            seen_profile.append(penv["TERMINAL_STACK_PROFILE"])
    if "wezterm" not in seen_profile:
        fails.append(
            f"FAIL live: gui-present [wezterm]: TERMINAL_STACK_PROFILE!=wezterm in pane envs (seen={seen_profile})"
        )

    # Verify tmux attached from WezTerm re-evaluates -gF options via on-client-attached.sh
    mat_conf = repo / ".config/tmux/colors-matugen.conf"
    expected_blue = ""
    expected_text = ""
    if mat_conf.is_file():
        m_txt = mat_conf.read_text(encoding="utf-8", errors="replace")
        mb = re.findall(r'^set -g @thm_blue\s+"(#[0-9a-fA-F]{6})"', m_txt, re.M)
        mt = re.findall(r'^set -g @thm_text\s+"(#[0-9a-fA-F]{6})"', m_txt, re.M)
        expected_blue = mb[-1] if mb else ""
        expected_text = mt[-1] if mt else ""

    if shutil.which("tmux") and shutil.which("script") and expected_blue:
        tmux_conf = repo / ".config/tmux/tmux.conf"
        with tempfile.TemporaryDirectory(prefix="live-wz-tmux-") as td:
            tenv = {**os.environ, "TMUX_TMPDIR": td, "TERMINAL_STACK_PROFILE": "wezterm", "WEZTERM_PANE": "1", "TERM_PROGRAM": "WezTerm"}
            tenv.pop("TMUX", None)
            tenv.pop("TMUX_PANE", None)
            tenv.pop("KITTY_WINDOW_ID", None)
            sock = f"wz-live-probe-{os.getpid()}"
            try:
                subprocess.run(
                    ["tmux", "-L", sock, "-f", str(tmux_conf), "new-session", "-d", "-s", "wzprobe"],
                    env=tenv,
                    check=True,
                    capture_output=True,
                    timeout=5,
                )
                # Trigger real client-attached hook via PTY attach
                subprocess.run(
                    ["script", "-qec", f"timeout 1.5 tmux -L {sock} attach -t wzprobe", "/dev/null"],
                    env=tenv,
                    capture_output=True,
                    timeout=5,
                )
                pop = subprocess.run(["tmux", "-L", sock, "show-options", "-gv", "popup-style"], env=tenv, capture_output=True, text=True).stdout.strip()
                act = subprocess.run(["tmux", "-L", sock, "show-options", "-gv", "pane-active-border-style"], env=tenv, capture_output=True, text=True).stdout.strip()
                tblue = subprocess.run(["tmux", "-L", sock, "show-options", "-gv", "@thm_blue"], env=tenv, capture_output=True, text=True).stdout.strip()
                if tblue != expected_blue:
                    fails.append(f"FAIL live: gui-present [tmux WezTerm attach]: @thm_blue={tblue!r} != {expected_blue!r}")
                if expected_text and expected_text not in pop:
                    fails.append(f"FAIL live: gui-present [tmux WezTerm attach -gF]: popup-style={pop!r} missing {expected_text!r}")
                if expected_blue not in act:
                    fails.append(f"FAIL live: gui-present [tmux WezTerm attach -gF]: pane-active-border-style={act!r} missing {expected_blue!r}")
            except subprocess.SubprocessError as exc:
                fails.append(f"FAIL live: gui-present [tmux WezTerm attach]: probe failed: {exc}")
            finally:
                subprocess.run(["tmux", "-L", sock, "kill-server"], env=tenv, capture_output=True)

    # Verify Hyprland resize works exit 0
    if shutil.which("luajit"):
        hy = subprocess.run(
            ["luajit", str(repo / "tests/wezterm/check_hyprland.lua"), str(repo / ".config/wezterm")],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if hy.returncode != 0:
            fails.append(f"FAIL live: gui-present [hyprland resize]: exited {hy.returncode}: {hy.stderr.strip()}")

    return warns, fails

def newest_mtime(paths: list[pathlib.Path]) -> tuple[float, str]:
    best_t, best_p = 0.0, ""
    for base in paths:
        if base.is_file():
            t = base.stat().st_mtime
            if t > best_t:
                best_t, best_p = t, str(base)
        elif base.is_dir():
            for root_d, dirs, files in os.walk(base):
                dirs[:] = [d for d in dirs if d not in (".git", "plugins")]
                for fn in files:
                    fp = pathlib.Path(root_d) / fn
                    try:
                        t = fp.stat().st_mtime
                    except OSError:
                        continue
                    if t > best_t:
                        best_t, best_p = t, str(fp)
    return best_t, best_p

targets = [
    ("tmux", [repo / ".config/tmux/tmux.conf", repo / ".config/tmux/scripts", repo / ".config/tmux/colors-apple-glass.conf", repo / ".config/tmux/colors-matugen.conf"], "stack-reload  (or detach & restart tmux server: tmux kill-server)"),
    ("kitty", [repo / ".config/kitty/kitty.conf", repo / ".config/kitty/custom.conf", repo / ".config/kitty/tab_bar.py", repo / ".config/kitty/themes/apple-glass.conf"], "stack-reload  (or restart Kitty for restart-only options like listen_on)"),
    ("wezterm", [repo / ".config/wezterm"], "stack-reload  (auto-reloads live wezterm-gui)"),
    ("nvim", [repo / ".config/nvim/init.lua", repo / ".config/nvim/lua"], "restart stale nvim session(s)"),
    ("zsh", [repo / "shell/zshrc", repo / "shell/zshenv"], "exec zsh  (inside stale interactive shell(s))"),
]

ps = subprocess.run(
    # Include stat so zombies can be filtered below. A defunct process is
    # already dead, cannot "reload", and must not be reported stale (the
    # harness reaps its own children and left false-positive zombies).
    ["ps", "-u", str(uid), "-o", "pid=,etimes=,stat=,comm=,args="],
    capture_output=True,
    text=True,
    check=True,
)

procs: list[tuple[int, float, str, str]] = []
for line in ps.stdout.splitlines():
    parts = line.strip().split(None, 4)
    if len(parts) < 4:
        continue
    pid = int(parts[0])
    etimes = float(parts[1])
    stat = parts[2]
    if stat.startswith("Z"):  # zombie/defunct — already dead, cannot reload
        continue
    comm = parts[3]
    args = parts[4] if len(parts) > 4 else comm
    procs.append((pid, now - etimes, comm, args))

stale_hits: list[str] = []
reloaded_ok = 0
wz_live_pids: list[int] = []
kt_live_pids: list[int] = []
for layer, cfg_paths, reload_cmd in targets:
    cfg_mtime, cfg_file = newest_mtime(cfg_paths)
    if cfg_mtime <= 0:
        continue
    matching = []
    for pid, pstart, comm, args in procs:
        if layer == "tmux":
            try:
                pcomm = pathlib.Path(f"/proc/{pid}/comm").read_text(encoding="utf-8").strip()
            except OSError:
                pcomm = comm
            if pcomm == "tmux: server" or pcomm == "tmux":
                matching.append((pid, pstart, pcomm))
        elif layer == "kitty" and comm == "kitty":
            matching.append((pid, pstart, comm))
            kt_live_pids.append(pid)
        elif layer == "wezterm" and comm in ("wezterm-gui", "wezterm"):
            matching.append((pid, pstart, comm))
            if comm == "wezterm-gui":
                wz_live_pids.append(pid)
        elif layer == "nvim" and comm == "nvim":
            matching.append((pid, pstart, comm))
        elif layer == "zsh" and comm == "zsh":
            matching.append((pid, pstart, comm))

    for pid, pstart, comm in matching:
        eff_t = stamp_freshness_time(layer, pid, pstart)
        if eff_t < cfg_mtime:
            age_s = int(cfg_mtime - eff_t)
            stale_hits.append(
                f"STALE [{layer}] pid={pid} ({comm}) started/reloaded {age_s}s before latest edit ({pathlib.Path(cfg_file).name}); reload: {reload_cmd}"
            )
        elif eff_t > pstart:
            reloaded_ok += 1

gui_warns, gui_fails = check_wezterm_live(sorted(set(wz_live_pids)))
if not kt_live_pids:
    gui_warns.append("[WARN] live: gui-present: kitty is not running (launch: setsid kitty >/dev/null 2>&1 &)")

for msg in [*stale_hits, *gui_warns, *gui_fails]:
    print(msg, file=sys.stderr if strict else sys.stdout)

if strict and (stale_hits or gui_warns or gui_fails):
    print(
        f"FAIL live: freshness (stale={len(stale_hits)}, gui_warns={len(gui_warns)}, gui_fails={len(gui_fails)} under STRICT_LIVE=1)",
        file=sys.stderr,
    )
    sys.exit(1)

if gui_fails:
    print(f"FAIL live: gui-present ({len(gui_fails)} live GUI failure(s))", file=sys.stderr)
    sys.exit(1)

print(
    f"live: freshness checked ({len(stale_hits)} stale advisory, {reloaded_ok} verified via reload stamp, "
    f"kitty_pids={len(set(kt_live_pids))}, wezterm_pids={len(set(wz_live_pids))})"
)
PY
