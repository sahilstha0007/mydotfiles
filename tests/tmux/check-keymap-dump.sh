#!/usr/bin/env bash
# E3: Verify keymap-dump.sh matches live `wezterm show-keys` 1:1 (including multiline and [[...]] keys)
# and handles Lua configs cleanly in an isolated sandbox without /tmp leaks.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)

# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/sandbox.sh"
sandbox_init
sandbox_install >/dev/null

# 1. Verify dump output matches `wezterm show-keys` 1:1 (default + custom key tables + lua multiline/[[...]] binds)
timeout 10 env HOME="$SB_HOME" bash "$SB_HOME/.config/tmux/keymap-dump.sh" --dump > "$SB_ROOT/keymap-dump.txt"
python3 - "$SB_HOME/.config/wezterm/wezterm.lua" "$SB_ROOT/keymap-dump.txt" <<'PY'
import re, subprocess, sys

wz_cfg, dump_path = sys.argv[1], sys.argv[2]
with open(dump_path, encoding="utf-8") as fh:
    dump_text = fh.read()

def extract_show_keys(cfg: str) -> set[tuple[str, str]]:
    out = subprocess.run(["wezterm", "--config-file", cfg, "show-keys"], capture_output=True, text=True, check=True).stdout
    pairs = set()
    section = ""
    for line in out.splitlines():
        s = line.strip()
        if s == "Default key table":
            section = "default"
        elif s.startswith("Key Table:"):
            section = s.split(":", 1)[1].strip()
        elif s == "Mouse":
            section = "mouse"
        elif section and section != "mouse" and "->" in line:
            left, right = line.split("->", 1)
            entry = f"{re.sub(r'\s{2,}', ' ', left.strip())} -> {' '.join(right.strip().split())}"
            pairs.add((section, entry))
    return pairs

def extract_dump(txt: str) -> set[tuple[str, str]]:
    pairs = set()
    in_wez = False
    for line in txt.splitlines():
        if line.startswith("### wezterm"):
            in_wez = True
            continue
        if in_wez and line.startswith("### "):
            break
        if in_wez:
            m = re.match(r"^\s+\[([^\]]+)\]\s+(.*)$", line)
            if m:
                pairs.add((m.group(1), m.group(2).strip()))
    return pairs

live = extract_show_keys(wz_cfg)
dumped = extract_dump(dump_text)
missing = sorted(live - dumped)
extra = sorted(dumped - live)
if missing or extra:
    print(f"FAIL E3: missing={missing[:5]} extra={extra[:5]}", file=sys.stderr)
    sys.exit(1)

# Specifically prove multiline and [[...]] bindings from config/bindings.lua survived
must_have = ["ALT / ->", "ALT , ->", "ALT . ->", "ALT | CTRL r ->", "F5 ->"]
joined = "\n".join(entry for _, entry in dumped)
for needle in must_have:
    if needle not in joined:
        print(f"FAIL E3: expected binding '{needle}' absent from keymap-dump.sh output", file=sys.stderr)
        sys.exit(1)

print(f"  PASS  keymap-dump wezterm matches show-keys 1:1 ({len(live)} bindings, including multiline & [[...]])")
PY
