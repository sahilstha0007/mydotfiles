#!/usr/bin/env bash
# Tracks the active tmux session dynamically across session switches and attachments.
# Persists to ~/.local/share/tmux/last-session so we always know which project
# the user was working on, even if the server is abruptly killed or rebooted.

set -euo pipefail

SESSION="${1:-}"

# If no argument, query tmux for client_session or session_name
if [ -z "$SESSION" ]; then
  SESSION=$(tmux display-message -p '#{client_session}' 2>/dev/null || tmux display-message -p '#S' 2>/dev/null || true)
fi

# Ignore empty, dummy startup, or test sessions
if [ -z "$SESSION" ] || [ "$SESSION" = "0" ] || [ "$SESSION" = "probe" ] || [ "$SESSION" = "rt-test" ]; then
  exit 0
fi

DATA_DIR="$HOME/.local/share/tmux"
mkdir -p "$DATA_DIR"
echo "$SESSION" > "$DATA_DIR/last-session"

# Set tmux global option for in-server reference
tmux set-option -gq @last_active_session "$SESSION" 2>/dev/null || true

# Append to history log in cache
mkdir -p "$HOME/.cache"
echo "$(date +%s) $SESSION" >> "$HOME/.cache/tmux-session-saves" 2>/dev/null || true
