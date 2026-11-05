#!/usr/bin/env bash
# =============================================================================
# Kitty Dev: Interactive Neovim Scrollback Pager
# Triggered by: ctrl+shift+h / kitty_mod+h
# Piped from Kitty via: launch --stdin-source=@screen_scrollback --type=overlay
# =============================================================================

set -euo pipefail

# Read scrollback into a temporary file so nvim can attach to tty
TMP_PAGER_FILE="$(mktemp -t kitty-scrollback-XXXXXX.log)"
trap 'rm -f "$TMP_PAGER_FILE"' EXIT

cat > "$TMP_PAGER_FILE"

# Launch Neovim with optimal scrollback pager settings:
# - buffer is readonly, no swapfile
# - cursor placed at bottom of output
# - 'q' and 'Esc' immediately quit
# - line numbers and relative numbers enabled
exec nvim \
  -c "set buftype=nofile noswapfile nomodified readonly cursorline number relativenumber" \
  -c "nnoremap <silent> q :qa!<CR>" \
  -c "nnoremap <silent> <ESC> :qa!<CR>" \
  -c "normal! G" \
  "$TMP_PAGER_FILE"
