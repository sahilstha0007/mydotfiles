#!/usr/bin/env bash
# Assert external ML4W matugen config.toml includes our kitty sanitizer post_hook under [templates.kitty].
set -euo pipefail

CFG="${MATUGEN_CONFIG:-$HOME/.config/matugen/config.toml}"
EXPECTED_HOOK="kitty-colors-sanitize --sync-in && pkill -SIGUSR1 kitty"

if [ ! -f "$CFG" ]; then
  echo "FAIL: missing matugen config: $CFG" >&2
  exit 1
fi

python3 - "$CFG" "$EXPECTED_HOOK" <<'PY'
import sys, tomllib

cfg_path, want = sys.argv[1], sys.argv[2]
with open(cfg_path, "rb") as fh:
    data = tomllib.load(fh)

kitty_tpl = data.get("templates", {}).get("kitty")
if not isinstance(kitty_tpl, dict):
    print(f"FAIL: [templates.kitty] section missing in {cfg_path}", file=sys.stderr)
    sys.exit(1)

got = kitty_tpl.get("post_hook", "")
if got != want:
    print(
        f"FAIL: [templates.kitty].post_hook mismatch in {cfg_path}\n"
        f"  want: {want!r}\n"
        f"  got : {got!r}",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"PASS: [templates.kitty].post_hook verified in {cfg_path}")
PY