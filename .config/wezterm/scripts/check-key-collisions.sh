#!/bin/sh
# Gate: does a wezterm keybind silently eat a tmux keybind?
#
# WHY THIS EXISTS
#
# wezterm resolves a keystroke BEFORE tmux ever sees the bytes. So an emulator
# bind that overlaps a multiplexer bind is not a conflict you can see — it is a
# silent steal: tmux's action simply never runs, no error, no warning, and the
# key still "does something" so nothing looks broken.
#
# It has happened three times in this config:
#   1. Alt+1..8   -> ActivateTab          killed tmux's Alt+1..9 window jumps
#   2. Ctrl+Alt+hljk -> ActivatePaneDirection killed tmux.nvim's pane swaps
#   3. Alt+Left / Alt+Right -> SendString killed tmux's M-Left / M-Right
#   4. Alt+9      -> toggle-tab-bar       killed tmux's M-9    (found 2026-10-17)
#
# Each was found by hand, one at a time. This gate finds the whole class.
#
# The rule it enforces is the one the notes already state: tmux owns windows and
# panes; wezterm keeps chrome keys only, and must never claim a key that is
# bound in tmux's ROOT table (the table that fires with no prefix).
#
# Usage:  scripts/check-key-collisions.sh
# Exit:   0 = no collisions, 1 = at least one steal, 2 = could not evaluate

set -eu

WEZTERM_BIN="${WEZTERM_BIN:-wezterm}"

command -v "$WEZTERM_BIN" >/dev/null 2>&1 || {
  echo 'check-key-collisions: wezterm not on PATH — did NOT run.' >&2
  exit 2
}
command -v tmux >/dev/null 2>&1 || {
  echo 'check-key-collisions: tmux not on PATH — did NOT run.' >&2
  exit 2
}

# wezterm's effective default-table bindings. Only bare ALT is a steal risk:
# ALT|CTRL and CTRL|SHIFT are prefixes tmux's root table does not use, and the
# LEADER rows are a key table, not a keystroke.
wez_keys=$(
  "$WEZTERM_BIN" show-keys 2>/dev/null \
    | awk '
        /^Default key table/ { in_default = 1; next }
        /^Key Table:/        { in_default = 0 }
        in_default && /^[ \t]+ALT[ \t]+[^|]/ {
          # field 1 is the mods column, field 2 the key
          gsub(/^[ \t]+/, ""); split($0, f, /[ \t]+/);
          print f[2]
        }
      ' \
    | sed 's/Arrow$//' \
    | sort -u
)

# tmux's ROOT table only. `-T root` is exactly "no prefix needed", which is the
# surface an emulator bind competes with. Prefix-table binds are unreachable
# without C-a, so they are not at risk.
# Field layout is `bind-key -T root M-9 select-window -t 9`, so awk sees
# $1=bind-key $2=-T $3=root $4=M-9. Reading $3/$4/$5 instead matched almost
# nothing and the gate reported "none" while looking at a single key — the
# exact shape of a vacuous gate, which is why the count floor below exists.
tmux_keys=$(
  tmux list-keys -T root 2>/dev/null \
    | awk '$1=="bind-key" && $2=="-T" && $3=="root" { print $4 }' \
    | grep '^M-' \
    | sed 's/^M-//' \
    | sort -u
)

if [ -z "$wez_keys" ]; then
  echo 'check-key-collisions: could not read wezterm bindings — did NOT run.' >&2
  exit 2
fi

# A gate that reads one key and finds no collision is not evidence. The real
# tmux root table carries Alt+1..9 plus the hjkl/arrow block; anything under a
# floor of 5 means the PARSER broke, not that the config is clean.
min_tmux=5
n_tmux_raw=$(printf '%s\n' "$tmux_keys" | grep -c . || true)
if [ "$n_tmux_raw" -lt "$min_tmux" ]; then
  echo "check-key-collisions: parsed only $n_tmux_raw tmux root M- keys (expected >= $min_tmux)." >&2
  echo 'check-key-collisions: the tmux side did not parse — did NOT run.' >&2
  exit 2
fi

collisions=''
for k in $wez_keys; do
  for t in $tmux_keys; do
    if [ "$k" = "$t" ]; then
      collisions="$collisions $k"
    fi
  done
done

collisions=$(printf '%s\n' $collisions | sort -u | tr '\n' ' ' | sed 's/  */ /g')

if [ -n "$(printf '%s' "$collisions" | tr -d ' ')" ]; then
  echo "FAIL: wezterm steals ${collisions%% } — bound in tmux's root table" >&2
  echo '      (the emulator wins silently; the tmux action never runs)' >&2
  echo "      wezterm bare-ALT keys: $(printf '%s' "$wez_keys" | tr '\n' ' ')" >&2
  echo "      tmux root M- keys:     $(printf '%s' "$tmux_keys" | tr '\n' ' ')" >&2
  exit 1
fi

n_wez=$(printf '%s\n' "$wez_keys" | grep -c . || true)
echo "key collisions: none (wezterm bare-ALT $n_wez vs tmux root M- $n_tmux_raw)"
exit 0
