#!/usr/bin/env bash
# continuum's auto-restore can fire before tmux exports $TMUX. The plugin's
# tmux_socket() then parses an empty string and `tmux -S ""` builds a second
# server, orphaning the "Restoring..." spinner when that server is killed.
# Resolve the socket from the server itself instead of trusting $TMUX.
if [ -z "${TMUX:-}" ]; then
  socket="$(tmux display-message -p '#{socket_path}' 2>/dev/null || true)"
  [ -n "$socket" ] && export TMUX="${socket},0,0"
fi
exec "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh" "$@"
