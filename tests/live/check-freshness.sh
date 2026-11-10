#!/usr/bin/env bash
# G3: Compare live running daemon/shell start times against their config mtimes.
# Prints STALE + exact reload command; warns by default, hard-FAILs under STRICT_LIVE=1.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)

strict="${STRICT_LIVE:-0}"
if [ "${1:-}" = "--self-test" ]; then
  # Fault-injection probe: synthetic stale process under STRICT_LIVE=1 must return non-zero,
  # and a reload stamp must only count for the exact (pid, start_ticks) with stamp_mtime >= cfg_mtime.
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
    # 1. No stamp + proc_start < cfg_mtime => stale
    assert is_stale(100.0, 200.0, st, my_pid, my_ticks)
    # 2. Wrong ticks => still stale
    st.write_text(f"{my_pid}:WRONG_TICKS:250\n", encoding="utf-8")
    os.utime(st, (250.0, 250.0))
    assert is_stale(100.0, 200.0, st, my_pid, my_ticks)
    # 3. Matching (pid, ticks) with stamp_mtime >= cfg_mtime => NOT stale
    st.write_text(f"{my_pid}:{my_ticks}:250\n", encoding="utf-8")
    os.utime(st, (250.0, 250.0))
    assert not is_stale(100.0, 200.0, st, my_pid, my_ticks)
    # 4. Subsequent edit pushes cfg_mtime > stamp_mtime => STALE again
    assert is_stale(100.0, 300.0, st, my_pid, my_ticks)
print("STALE [self-test] pid=99999 proc_start=100 < cfg_mtime=200  -> run: stack-reload", file=sys.stderr)
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
import os, pathlib, subprocess, sys, time

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
    ("tmux", [repo / ".config/tmux/tmux.conf", repo / ".config/tmux/scripts", repo / ".config/tmux/colors-nightfox.conf", repo / ".config/tmux/colors-matugen.conf"], "stack-reload  (or detach & restart tmux server: tmux kill-server)"),
    ("kitty", [repo / ".config/kitty/kitty.conf", repo / ".config/kitty/custom.conf", repo / ".config/kitty/tab_bar.py", repo / ".config/kitty/themes/nightfox.conf"], "stack-reload  (or restart Kitty for restart-only options like listen_on)"),
    ("wezterm", [repo / ".config/wezterm"], "stack-reload  (auto-reloads live wezterm-gui)"),
    ("nvim", [repo / ".config/nvim/init.lua", repo / ".config/nvim/lua"], "restart stale nvim session(s)"),
    ("zsh", [repo / "shell/zshrc", repo / "shell/zshenv", repo / "shell/omni-aliases.zsh"], "exec zsh  (inside stale interactive shell(s))"),
]

ps = subprocess.run(
    ["ps", "-u", str(uid), "-o", "pid=,etimes=,comm=,args="],
    capture_output=True,
    text=True,
    check=True,
)

procs: list[tuple[int, float, str, str]] = []
for line in ps.stdout.splitlines():
    parts = line.strip().split(None, 3)
    if len(parts) < 3:
        continue
    pid = int(parts[0])
    etimes = float(parts[1])
    comm = parts[2]
    args = parts[3] if len(parts) > 3 else comm
    procs.append((pid, now - etimes, comm, args))

stale_hits: list[str] = []
reloaded_ok = 0
for layer, cfg_paths, reload_cmd in targets:
    cfg_mtime, cfg_file = newest_mtime(cfg_paths)
    if cfg_mtime <= 0:
        continue
    matching = []
    for pid, pstart, comm, args in procs:
        if layer == "tmux" and (comm.startswith("tmux") or "tmux: server" in args):
            matching.append((pid, pstart, comm))
        elif layer == "kitty" and comm == "kitty":
            matching.append((pid, pstart, comm))
        elif layer == "wezterm" and comm in ("wezterm-gui", "wezterm"):
            matching.append((pid, pstart, comm))
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

for msg in stale_hits:
    print(msg, file=sys.stderr if strict else sys.stdout)

if stale_hits and strict:
    print(f"FAIL live: freshness ({len(stale_hits)} stale live process(es) under STRICT_LIVE=1)", file=sys.stderr)
    sys.exit(1)

print(f"live: freshness checked ({len(stale_hits)} stale advisory, {reloaded_ok} verified via reload stamp)")
PY
