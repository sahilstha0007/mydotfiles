#!/usr/bin/env bash
# G1: Assert tmux.conf reload idempotency (specifically update-environment duplication).
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)
CONF="$REPO_ROOT/.config/tmux/tmux.conf"

if ! command -v tmux >/dev/null 2>&1; then
  echo "FAIL: tmux is required for reload idempotency gate" >&2
  exit 1
fi

tmpdir=$(mktemp -d)
sock="devcheck-reload-$$"
cleanup() {
  TMUX_TMPDIR="$tmpdir" tmux -L "$sock" kill-server >/dev/null 2>&1 || true
  rm -rf "$tmpdir"
}
trap cleanup EXIT

TMUX_TMPDIR="$tmpdir" tmux -L "$sock" -f "$CONF" start-server
TMUX_TMPDIR="$tmpdir" tmux -L "$sock" source-file "$CONF"
TMUX_TMPDIR="$tmpdir" tmux -L "$sock" source-file "$CONF"

raw_opts=$(TMUX_TMPDIR="$tmpdir" tmux -L "$sock" show-options -g update-environment)
python3 - "$raw_opts" <<'PY'
import collections, re, sys

raw = sys.argv[1].strip().splitlines()
vals = []
for line in raw:
    m = re.match(r"^update-environment(?:\[\d+\])?\s+(.*)$", line)
    if m:
        vals.extend(m.group(1).strip().strip('"').split())

if not vals:
    print("FAIL G1: update-environment empty after double source-file", file=sys.stderr)
    sys.exit(1)

counts = collections.Counter(vals)
dups = {k: v for k, v in counts.items() if v > 1}
if dups:
    print(f"FAIL G1: duplicate update-environment entries after reload: {dups}", file=sys.stderr)
    sys.exit(1)

required = {"DISPLAY", "WAYLAND_DISPLAY", "TERMINAL_STACK_PROFILE", "KITTY_WINDOW_ID", "WEZTERM_PANE", "TERM_PROGRAM"}
missing = sorted(required - set(vals))
if missing:
    print(f"FAIL G1: update-environment missing required vars: {missing}", file=sys.stderr)
    sys.exit(1)

print(f"  PASS  tmux update-environment idempotent across 2 reloads ({len(vals)} unique entries, 0 duplicates)")
PY
