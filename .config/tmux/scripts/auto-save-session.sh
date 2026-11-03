#!/usr/bin/env bash
# Auto-save the current tmux session on client detach.
# Called from tmux.conf's client-detached hook so sessions are never lost
# even if you forget prefix+C-s (manual resurrect save).
set -euo pipefail

SESSION=$(tmux display-message -p '#S' 2>/dev/null) || exit 0
[ -n "$SESSION" ] || exit 0

# Save via resurrect if available, otherwise just record the session name
if [ -x ~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh ]; then
  ~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh 2>/dev/null || true
fi

# Also persist a lightweight marker for quick restore detection
echo "$(date +%s) $SESSION" >> ~/.cache/tmux-session-saves 2>/dev/null || true
