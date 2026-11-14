#!/usr/bin/env bash
# Auto-save the current tmux session on client detach.
# Called from tmux.conf's client-detached hook so sessions are never lost
# even if you forget prefix+C-s (manual resurrect save).
set -euo pipefail

SESSION="${1:-}"
if [ -z "$SESSION" ]; then
  SESSION=$(tmux display-message -p '#{client_session}' 2>/dev/null || tmux display-message -p '#S' 2>/dev/null || true)
fi

# Record active session if valid
if [ -n "$SESSION" ] && [ "$SESSION" != "0" ] && [ "$SESSION" != "probe" ]; then
  ~/.config/tmux/scripts/track-active-session.sh "$SESSION" 2>/dev/null || true
fi

# Save via resurrect if available
if [ -x ~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh ]; then
  ~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh "quiet" 2>/dev/null || true
fi

# Also persist lightweight marker for quick restore detection
if [ -n "$SESSION" ]; then
  echo "$(date +%s) $SESSION" >> ~/.cache/tmux-session-saves 2>/dev/null || true
fi
