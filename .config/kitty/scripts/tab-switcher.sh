#!/usr/bin/env bash
# =============================================================================
# Kitty Dev: Interactive Fuzzy Tab Switcher
# Lists all open tabs across windows with their title and process
# Selecting one immediately focuses that tab via `kitty @ focus-tab`
# =============================================================================
set -euo pipefail

# Query all tabs from current kitty instance
TABS_JSON=$(kitty @ ls 2>/dev/null || true)
if [[ -z "$TABS_JSON" ]]; then
  echo "No active Kitty remote socket found."
  exit 1
fi

selected=$(echo "$TABS_JSON" | python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
    for w in data:
        for tab in w.get("tabs", []):
            tid = tab["id"]
            title = tab.get("title", "tab")
            is_active = "★" if tab.get("is_active") else " "
            windows = len(tab.get("windows", []))
            print(f"{tid}\t{is_active} Tab {tid}: {title} ({windows} win)")
except Exception:
    pass
' | fzf --ansi --delimiter=$'\t' --with-nth=2 --prompt="󰓩 Switch Tab ❯ " --height=100% --reverse) || true

if [[ -n "$selected" ]]; then
  tab_id=$(echo "$selected" | cut -f1)
  kitty @ focus-tab -m "id:$tab_id"
fi
