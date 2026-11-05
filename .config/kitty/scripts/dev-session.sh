#!/usr/bin/env bash
# =============================================================================
# Kitty Dev Profile — Clean Interactive Shell Launcher
# Sets TERMINAL_STACK_PROFILE=kitty for palette alignment
# Launches user's interactive shell directly (no forced popups or chunky UI)
# =============================================================================
export TERMINAL_STACK_PROFILE=kitty

# If custom commands were passed, execute them directly
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Clean interactive shell — user opens project-hub, tmux, or nvim on their own
exec "${SHELL:-/bin/zsh}"
