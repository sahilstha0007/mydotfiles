#!/usr/bin/env bash
# =============================================================================
# Tmux: Interactive Neovim Scrollback Pager (Prefix + h)
# Opens active pane scrollback in a floating Neovim buffer (mirrors Kitty ctrl+shift+h)
# =============================================================================
set -euo pipefail

target_pane="${1:-}"
if [ -z "$target_pane" ]; then
  # Fallback to current pane if not provided
  target_pane="$(tmux display-message -p '#{pane_id}')"
fi

tmp_file="$(mktemp -t tmux-scrollback-XXXXXX.log)"
trap 'rm -f "$tmp_file"' EXIT

# Capture up to 5,000 lines of scrollback from the target pane
tmux capture-pane -p -S -5000 -t "$target_pane" > "$tmp_file"

# Open in Neovim with read-only pager settings and instant 'q' quit
nvim \
  -c "set buftype=nofile noswapfile nomodified readonly cursorline number wrap linebreak breakindent" \
  -c "nnoremap <silent> q :qa!<CR>" \
  -c "normal! G" \
  "$tmp_file"
