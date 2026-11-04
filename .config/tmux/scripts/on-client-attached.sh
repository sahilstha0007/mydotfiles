#!/usr/bin/env bash
# Runs on tmux client-attached hook:
# 1. Repaints client (fixes stale regions)
# 2. Detects attached terminal emulator and updates TERMINAL_STACK_PROFILE
tmux refresh-client
client_type=$(tmux display-message -p "#{client_termtype}" 2>/dev/null || true)
client_pid=$(tmux display-message -p "#{client_pid}" 2>/dev/null || true)

detected=""
case "$client_type" in
  *kitty*|*xterm-kitty*) detected="kitty" ;;
  *wezterm*|*WezTerm*)   detected="wezterm" ;;
esac

if [ -z "$detected" ] && [ -n "$client_pid" ] && [ -r "/proc/$client_pid/environ" ]; then
  if grep -zq "WEZTERM_PANE" "/proc/$client_pid/environ" 2>/dev/null || \
     grep -zq "TERMINAL_STACK_PROFILE=wezterm" "/proc/$client_pid/environ" 2>/dev/null || \
     grep -zq "TERM_PROGRAM=WezTerm" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="wezterm"
  elif grep -zq "KITTY_WINDOW_ID" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="kitty"
  fi
fi

if [ -n "$detected" ]; then
  tmux set-environment -g TERMINAL_STACK_PROFILE "$detected"
  tmux set-environment TERMINAL_STACK_PROFILE "$detected"
fi
