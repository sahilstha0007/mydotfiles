#!/usr/bin/env bash
# Resurrect post-save-layout hook:
# Ensures the resurrect state file always records the correct active session.
# If dump_state wrote an empty session (common when saved from background/continuum),
# inject the last active session from ~/.local/share/tmux/last-session.

set -euo pipefail

STATE_FILE="${1:-}"
[ -f "$STATE_FILE" ] || exit 0

DATA_DIR="$HOME/.local/share/tmux"
LAST_SESSION_FILE="$DATA_DIR/last-session"

ACTIVE_SESSION=""
if [ -f "$LAST_SESSION_FILE" ]; then
  ACTIVE_SESSION=$(cat "$LAST_SESSION_FILE" 2>/dev/null | tr -d '[:space:]')
fi

# Fallback 1: check currently attached client
if [ -z "$ACTIVE_SESSION" ]; then
  ACTIVE_SESSION=$(tmux list-clients -F "#{client_session}" 2>/dev/null | head -n 1 || true)
fi

# Fallback 2: check most recently active session
if [ -z "$ACTIVE_SESSION" ]; then
  ACTIVE_SESSION=$(tmux list-sessions -F '#{session_name}:#{session_activity}' 2>/dev/null | sort -t: -k2 -nr | head -n 1 | cut -d: -f1 || true)
fi

[ -n "$ACTIVE_SESSION" ] || exit 0

# Check the state line in the resurrect file
# Format in file: state\t<client_session>\t<client_last_session>
STATE_LINE=$(grep "^state" "$STATE_FILE" 2>/dev/null || true)
CURRENT_SAVED_SESS=$(echo "$STATE_LINE" | awk -F'\t' '{print $2}')

if [ -z "$CURRENT_SAVED_SESS" ] || [ "$CURRENT_SAVED_SESS" = "0" ]; then
  sed -i "s/^state\t.*/state\t${ACTIVE_SESSION}\t/" "$STATE_FILE"
fi
