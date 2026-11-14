#!/usr/bin/env bash
# Resurrect post-restore-all hook:
# 1. Switches all currently attached clients to the restored target session (e.g. fastapi)
# 2. Removes dummy startup session "0" if created during cold boot
# 3. Records restore completion

set -euo pipefail

DATA_DIR="$HOME/.local/share/tmux"
LAST_SESSION_FILE="$DATA_DIR/last-session"

TARGET_SESSION=""
if [ -f "$LAST_SESSION_FILE" ]; then
  TARGET_SESSION=$(cat "$LAST_SESSION_FILE" 2>/dev/null | tr -d '[:space:]')
fi

# Fallback: check state line in the last resurrect file
if [ -z "$TARGET_SESSION" ] && [ -f "$DATA_DIR/resurrect/last" ]; then
  TARGET_SESSION=$(grep "^state" "$DATA_DIR/resurrect/last" 2>/dev/null | awk -F'\t' '{print $2}' || true)
fi

# Validate target session exists in tmux
if [ -n "$TARGET_SESSION" ] && tmux has-session -t "$TARGET_SESSION" 2>/dev/null; then
  # Switch every attached client to the target session
  for client in $(tmux list-clients -F "#{client_name}" 2>/dev/null || true); do
    tmux switch-client -c "$client" -t "$TARGET_SESSION" 2>/dev/null || true
  done
fi

# Clean up session "0" if another real session exists and target is not 0
if [ "${TARGET_SESSION:-}" != "0" ] && tmux has-session -t "0" 2>/dev/null; then
  TOTAL_SESSIONS=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | wc -l)
  if [ "$TOTAL_SESSIONS" -gt 1 ]; then
    tmux kill-session -t "0" 2>/dev/null || true
  fi
fi

echo "$(date +%s) restored to ${TARGET_SESSION:-unknown}" >> "$HOME/.cache/tmux-session-saves" 2>/dev/null || true
