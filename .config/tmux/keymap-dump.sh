#!/usr/bin/env bash
# Cross-layer keymap dump: tmux + nvim + wezterm + kitty in one fzf list.
#
# Bound to Prefix+k. Exists because each layer has its own lookup (tmux `?`,
# nvim `Space+sk`, `wezterm show-keys`, kitty custom.conf) but nothing answers
# "what does EVERY layer bind for X" in one place.
set -uo pipefail

MODE="fzf"
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help)
      cat <<'EOF'
Usage: keymap-dump.sh [--dump] [--help]

  --dump   Print the complete cross-layer keymap table to stdout (no fzf)
  --help   Show this help message and exit
EOF
      exit 0
      ;;
    --dump)
      MODE="dump"
      shift
      ;;
    *)
      printf 'keymap-dump.sh: unknown option: %s\nUsage: keymap-dump.sh [--dump] [--help]\n' "$1" >&2
      exit 2
      ;;
  esac
done

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

dump_wezterm() {
  local wz_cfg="$HOME/.config/wezterm/wezterm.lua"
  local wz_bind="$HOME/.config/wezterm/config/bindings.lua"
  if command -v wezterm >/dev/null 2>&1 && [ -f "$wz_cfg" ]; then
    wezterm --config-file "$wz_cfg" show-keys 2>/dev/null | python3 -c '
import re, sys

section = ""
for raw in sys.stdin:
    s = raw.strip()
    if s.startswith("Leader:"):
        print("  " + s)
    elif s == "Default key table":
        section = "default"
    elif s.startswith("Key Table:"):
        section = s.split(":", 1)[1].strip()
    elif s == "Mouse":
        section = "mouse"
    elif section and section != "mouse" and "->" in raw:
        left, right = raw.split("->", 1)
        left_norm = re.sub(r"\s{2,}", " ", left.strip())
        right_norm = " ".join(right.strip().split())
        print(f"  [{section}] {left_norm} -> {right_norm}")
'
  elif command -v luajit >/dev/null 2>&1 && [ -f "$wz_bind" ]; then
    luajit -e '
      local root = os.getenv("HOME") .. "/.config/wezterm"
      package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
      _G.wezterm = setmetatable({
        action = setmetatable({}, { __index = function(_, k) return function(...) return k end end }),
        action_callback = function(f) return f end,
        nerdfonts = setmetatable({}, { __index = function() return "" end }),
        home_dir = os.getenv("HOME"), config_dir = root,
      }, { __index = function() return function() return {} end end })
      package.loaded["wezterm"] = _G.wezterm
      local b = require("config.bindings")
      if b.leader then
        print(string.format("  Leader: %s %s", tostring(b.leader.key), tostring(b.leader.mods)))
      end
      for _, k in ipairs(b.keys or {}) do
        print(string.format("  [default] %s %s -> %s", tostring(k.mods or "NONE"), tostring(k.key), tostring(k.action)))
      end
      for tname, rows in pairs(b.key_tables or {}) do
        for _, k in ipairs(rows) do
          print(string.format("  [%s] %s %s -> %s", tname, tostring(k.mods or "NONE"), tostring(k.key), tostring(k.action)))
        end
      end
    ' 2>/dev/null
  else
    echo "  (wezterm config not found)"
  fi
}

{
  # --- nvim -------------------------------------------------------------
  echo "### nvim  (leader: Space)   — in-editor menu: Space+sk"
  nvim --headless \
    -c 'redir! > '"$workdir/nvim.out"' | silent verbose nmap | redir END | qa!' 2>/dev/null || true
  if [ -s "$workdir/nvim.out" ]; then
    grep -E '^[^ ].*<[^>]+>' "$workdir/nvim.out" | sed 's/[[:space:]]\+/ /g' | cut -c1-160 || true
  fi
  echo

  # --- tmux -------------------------------------------------------------
  echo "### tmux  (prefix: C-a)     — in-tmux menu: C-a ?"
  tmux list-keys -T prefix 2>/dev/null |
    sed -E 's/^bind-key +-T +[^ ]+ +//' |
    awk '{k=$1; $1=""; sub(/^ +/,""); printf "  %-10s %s\n", k, $0}' || true
  tmux list-keys -T root 2>/dev/null |
    sed -E 's/^bind-key +-T +[^ ]+ +//' |
    awk '{printf "  [no-prefix] %s\n", $0}' || true
  echo

  # --- wezterm (via `wezterm show-keys` / Lua source of truth — E3) ---
  echo "### wezterm  (leader: Alt+Ctrl+Space)"
  dump_wezterm
  echo

  # --- kitty ------------------------------------------------------------
  echo "### kitty  (profile: custom.conf)  — Ctrl+Shift+<key>"
  kf=$HOME/.config/kitty/custom.conf
  if [[ -f $kf ]]; then
    grep -E '^map[[:space:]]+' "$kf" |
      sed -E 's/^map[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$/\1|\2/' |
      while IFS='|' read -r key cmd; do
        printf '  %-24s %s\n' "$key" "$cmd"
      done
  else
    echo "  (custom.conf not found)"
  fi
} > "$workdir/all.out" 2>/dev/null

if [ "$MODE" = "dump" ] || [ ! -t 1 ] || ! command -v fzf >/dev/null 2>&1; then
  cat "$workdir/all.out"
  exit 0
fi

fzf --ansi --no-sort \
  --header='tmux C-a · nvim Space · wezterm Alt+Ctrl+Space · kitty Ctrl+Shift — every layer, one list' \
  --prompt='keys> ' \
  --preview 'printf "%s\n" {} | fold -sw 100' \
  < "$workdir/all.out"
