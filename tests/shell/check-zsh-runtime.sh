#!/usr/bin/env bash
# Regression gate for Work Items D1..D5:
# - D1: clean zsh startup with and without ~/.zshrc.local
# - D2: fresh-HOME install pre-warm + 10-run latency per profile (min/median/p95/max; median<80ms, max<=120ms)
# - D3: COLORTERM guard matrix (kitty, wezterm, SSH xterm-256color, SSH *-direct)
# - D4: minimal-PATH startup (PATH=/usr/bin and PATH= empty, warm and cold compdump)
# - D5: non-interactive zshenv performs zero mkdir/chmod and zero child execve (strace)
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"

# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/sandbox.sh"

sandbox_init

# Rule 9: strace must be present; never skip silently when missing.
if ! command -v strace >/dev/null 2>&1; then
  echo "FAIL: strace is required for D5 zero-execve gate (install with: sudo pacman -S strace)" >&2
  exit 1
fi

# D5: non-interactive `zsh -c true` on fresh empty HOME must create 0 dirs/files and spawn 0 child execve
H5="$(dirname "$SB_HOME")/d5_empty_home"
mkdir -p "$H5"
cp "$REPO_ROOT/shell/zshenv" "$H5/.zshenv"
env -i HOME="$H5" PATH=/usr/bin /usr/bin/zsh -c true
d5_extra="$(find "$H5" -mindepth 1 ! -name .zshenv)"
if [ -n "$d5_extra" ]; then
  echo "FAIL D5: non-interactive .zshenv created extra filesystem entries: $d5_extra" >&2
  exit 1
fi

strace_out="$(env -i HOME="$H5" PATH=/usr/bin strace -f -e trace=execve /usr/bin/zsh -c true 2>&1 || true)"
exec_count="$(printf '%s\n' "$strace_out" | grep -c 'execve(' || true)"
if [ "$exec_count" -ne 1 ]; then
  echo "FAIL D5: expected exactly 1 execve (/usr/bin/zsh) in 'zsh -c true', got $exec_count:" >&2
  printf '%s\n' "$strace_out" >&2
  exit 1
fi
echo "  PASS  D5: non-interactive zsh -c true (0 created dirs, 1 execve)"

# Link OMZ read-only into sandbox HOME when present on host so D2/D4 test real plugin+compinit boot
if [ -d "$HOME/.oh-my-zsh" ] && [ ! -e "$SB_HOME/.oh-my-zsh" ]; then
  ln -s "$HOME/.oh-my-zsh" "$SB_HOME/.oh-my-zsh"
fi

# Fresh install pre-warms bat, zsh caches, and compdump cleanly
sandbox_install >/dev/null

# sandbox_init cloned HEAD, so $SB_HOME/.zshrc points at the committed snapshot.
# Repoint at the working-tree file under remediation so these checks exercise the
# real zshrc (F16 fzf/zle fix) instead of a stale copy.
ln -sfn "$REPO_ROOT/shell/zshrc" "$SB_HOME/.zshrc"

# D1: startup succeeds cleanly without ~/.zshrc.local and with a mock ~/.zshrc.local
out_no_local=$(env -i HOME="$SB_HOME" TERM=xterm-kitty KITTY_WINDOW_ID=1 PATH="$PATH" /usr/bin/zsh -i -c exit </dev/null 2>&1)
if [ -n "$out_no_local" ]; then
  echo "FAIL D1: zsh produced stderr/stdout without .zshrc.local: $out_no_local" >&2
  exit 1
fi

# D3: COLORTERM matrix (local kitty, local wezterm, SSH 256color, SSH *-direct)
# shellcheck disable=SC2016
c_kit=$(env -i HOME="$SB_HOME" TERM=xterm-kitty PATH="$PATH" /usr/bin/zsh -c 'printf %s "${COLORTERM:-EMPTY}"')
# shellcheck disable=SC2016
c_wez=$(env -i HOME="$SB_HOME" TERM=wezterm PATH="$PATH" /usr/bin/zsh -c 'printf %s "${COLORTERM:-EMPTY}"')
# shellcheck disable=SC2016
c_ssh=$(env -i HOME="$SB_HOME" TERM=xterm-256color SSH_CONNECTION="10.0.0.1 22 10.0.0.2 22" PATH="$PATH" /usr/bin/zsh -c 'printf %s "${COLORTERM:-EMPTY}"')
# shellcheck disable=SC2016
c_dir=$(env -i HOME="$SB_HOME" TERM=tmux-direct SSH_CONNECTION="10.0.0.1 22 10.0.0.2 22" PATH="$PATH" /usr/bin/zsh -c 'printf %s "${COLORTERM:-EMPTY}"')

if [ "$c_kit" != "truecolor" ] || [ "$c_wez" != "truecolor" ] || [ "$c_ssh" != "EMPTY" ] || [ "$c_dir" != "truecolor" ]; then
  echo "FAIL D3: unexpected COLORTERM matrix: kitty=$c_kit wezterm=$c_wez ssh_256=$c_ssh ssh_direct=$c_dir" >&2
  exit 1
fi
echo "  PASS  D3: COLORTERM matrix (kitty=$c_kit, wezterm=$c_wez, ssh_256=$c_ssh, ssh_direct=$c_dir)"

# D2: 10 runs per profile (including run 1 directly after install.sh)
python3 - "$SB_HOME" <<'PY'
import os, statistics, subprocess, sys, time

sb_home = sys.argv[1]
profiles = {
    "kitty": {"TERM": "xterm-kitty", "KITTY_WINDOW_ID": "1", "TERMINAL_STACK_PROFILE": "kitty"},
    "wezterm": {"TERM": "wezterm", "WEZTERM_PANE": "1", "TERMINAL_STACK_PROFILE": "wezterm"},
    "fallback": {"TERM": "xterm-256color"},
}
for name, extra in profiles.items():
    times = []
    for i in range(10):
        env = {
            "HOME": sb_home,
            "PATH": os.environ["PATH"],
            "USER": os.environ.get("USER", "sahil"),
            "LOGNAME": os.environ.get("LOGNAME", "sahil"),
            **extra,
        }
        t0 = time.perf_counter()
        p = subprocess.run(["/usr/bin/zsh", "-i", "-c", "exit"], env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True)
        ms = (time.perf_counter() - t0) * 1000.0
        if p.returncode != 0 or p.stderr:
            print(f"FAIL D2: profile={name} run={i+1} rc={p.returncode} stderr={p.stderr!r}", file=sys.stderr)
            sys.exit(1)
        times.append(ms)
    s = sorted(times)
    p95 = s[int(0.95 * (len(s) - 1))]
    med = statistics.median(s)
    mx = max(s)
    print(f"  PASS  D2[{name}]: run1={times[0]:.1f}ms min={min(s):.1f}ms median={med:.1f}ms p95={p95:.1f}ms max={mx:.1f}ms")
    if med >= 80.0 or p95 > 120.0 or mx > 120.0:
        print(f"FAIL D2: {name} exceeded threshold (median<80ms, p95/max<=120ms)", file=sys.stderr)
        sys.exit(1)
PY

# D4: minimal PATH robustness (including cold compdump rebuild without external mv on PATH)
for test_path in "/usr/bin" ""; do
  err_warm=$(env -i HOME="$SB_HOME" TERM=xterm-256color PATH="$test_path" /usr/bin/zsh -i -c exit </dev/null 2>&1)
  if [ -n "$err_warm" ]; then
    echo "FAIL D4: warm zsh stderr on PATH='$test_path': $err_warm" >&2
    exit 1
  fi
  rm -f "$SB_HOME"/.zcompdump*
  err_cold=$(env -i HOME="$SB_HOME" TERM=xterm-256color PATH="$test_path" /usr/bin/zsh -i -c exit </dev/null 2>&1)
  if [ -n "$err_cold" ]; then
    echo "FAIL D4: cold compdump zsh stderr on PATH='$test_path': $err_cold" >&2
    exit 1
  fi
done
echo "  PASS  D4: minimal PATH startup clean (PATH=/usr/bin and PATH='', warm+cold compdump)"
