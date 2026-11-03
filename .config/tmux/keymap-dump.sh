#!/usr/bin/env bash
# Cross-layer keymap dump: tmux + nvim + wezterm in one fzf list.
#
# Bound to Prefix+k. Exists because the three layers each have their own
# lookup (tmux `?`, nvim `Space+sk`, wezterm key tables) but nothing answers
# "what does EVERY layer bind for X" in one place.
#
# ponytail: the nvim half spawns a headless nvim, ~200ms. It re-reads the
# same static config every invocation. Cache to a file keyed on the config
# mtime if it ever shows up in a startup profile.
#
# Two non-obvious things this script has to get right:
#   1. `verbose nmap` prints NOTHING to stdout under --headless (no UI to
#      write to). It must be captured with `redir` to a file, then read.
#      Piping it straight to grep silently yields an empty nvim section.
#   2. tmux list-keys emits `bind-key -T <table> <key> <cmd...>` where the
#      command can contain spaces, so the tail must be rejoined with awk —
#      a `read ... _` swallows it.

set -uo pipefail

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

{
  # --- nvim -------------------------------------------------------------
  # leader: Space. Keys are static config, so a second headless instance is
  # a valid source — the popup may be open while some other pane runs nvim.
  echo "### nvim  (leader: Space)   — in-editor menu: Space+sk"
  nvim --headless \
    -c 'redir! > '"$tmp"' | silent verbose nmap | redir END | qa!' 2>/dev/null
  # Drop the "Last set from ..." trailer: 3x the size of the map, no lookup value.
  grep -E '^[^ ].*<[^>]+>' "$tmp" | sed 's/[[:space:]]\+/ /g' | cut -c1-160
  echo

  # --- tmux -------------------------------------------------------------
  echo "### tmux  (prefix: C-a)     — in-tmux menu: C-a ?"
  tmux list-keys -T prefix 2>/dev/null |
    sed -E 's/^bind-key +-T +[^ ]+ +//' |
    awk '{k=$1; $1=""; sub(/^ +/,""); printf "  %-10s %s\n", k, $0}'
  tmux list-keys -T root 2>/dev/null |
    sed -E 's/^bind-key +-T +[^ ]+ +//' |
    awk '{printf "  [no-prefix] %s\n", $0}'
  echo

  # --- wezterm ----------------------------------------------------------
  # Parsed from the Lua source, not wezterm's own CLI: there is no
  # `wezterm list-keys`, and the config is modular so the table lives in
  # config/bindings.lua. mod.SUPER is 'ALT' in this config, not Windows
  # Super — that is a deliberate choice documented in bindings.lua.
  echo "### wezterm  (leader: Alt+Ctrl+Space)  — F1-F6 work with no prefix"
  f=$HOME/.config/wezterm/config/bindings.lua
  if [[ -f $f ]]; then
    grep -E "\{ *key *= *'" "$f" |
      sed -E "s/.*key *= *'([^']*)'.*mods *= *([^,]*),.*/\1|\2/" |
      while IFS='|' read -r key mods; do
        [[ -z $key || -z $mods ]] && continue
        printf '  %-14s %s\n' "$key" "$mods"
      done
    echo "  key tables: Alt+Ctrl+Space f=resize_font  p=resize_pane"
    echo "              (backdrops_panel / wallpaper_picker open via their own binds)"
  else
    echo "  (bindings.lua not found)"
  fi
} > "$tmp.out" 2>/dev/null

fzf --ansi --no-sort \
  --header='tmux C-a · nvim Space · wezterm Alt+Ctrl+Space — every layer, one list' \
  --prompt='keys> ' \
  --preview 'printf "%s\n" {} | fold -sw 100' \
  < "$tmp.out"
