#!/usr/bin/env bash
# Runs on tmux client-attached hook:
# 1. Repaints client (fixes stale regions)
# 2. Detects attached terminal emulator and updates TERMINAL_STACK_PROFILE
tmux refresh-client
client_name=$(tmux display-message -p "#{client_termname}" 2>/dev/null || true)
client_type=$(tmux display-message -p "#{client_termtype}" 2>/dev/null || true)
client_pid=$(tmux display-message -p "#{client_pid}" 2>/dev/null || true)

detected=""
case "$client_name:$client_type" in
  *kitty*|*xterm-kitty*) detected="kitty" ;;
  *wezterm*|*WezTerm*)   detected="wezterm" ;;
esac

if [ -z "$detected" ] && [ -n "$client_pid" ] && [ -r "/proc/$client_pid/environ" ]; then
  if grep -zq "^KITTY_WINDOW_ID=" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="kitty"
  elif grep -zq "^WEZTERM_PANE=" "/proc/$client_pid/environ" 2>/dev/null || \
       grep -zq "^TERM_PROGRAM=WezTerm$" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="wezterm"
  elif grep -zq "^TERMINAL_STACK_PROFILE=kitty$" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="kitty"
  elif grep -zq "^TERMINAL_STACK_PROFILE=wezterm$" "/proc/$client_pid/environ" 2>/dev/null; then
    detected="wezterm"
  fi
fi

if [ -n "$detected" ]; then
  tmux set-environment -g TERMINAL_STACK_PROFILE "$detected"
  tmux set-environment TERMINAL_STACK_PROFILE "$detected"
  if [ "$detected" = "kitty" ]; then
    tmux source-file -q ~/.config/tmux/colors-nightfox.conf
    tmux set -gF popup-style "bg=default,fg=#{@thm_text}"
    tmux set -gF popup-border-style "fg=#{@thm_blue}"
    tmux set -g popup-border-lines rounded
    tmux set -gF pane-active-border-style "fg=#{@thm_blue}"
    tmux set-environment -g LG_CONFIG_FILE "$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme-nightfox.yml"
    tmux set-environment -g CONFIG_DIR "$HOME/.config/lazydocker/nightfox"
    tmux set-environment LG_CONFIG_FILE "$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme-nightfox.yml"
    tmux set-environment CONFIG_DIR "$HOME/.config/lazydocker/nightfox"
  elif [ "$detected" = "wezterm" ]; then
    tmux source-file -q ~/.config/tmux/colors-matugen.conf
    tmux set -gF popup-style "bg=default,fg=#{@thm_text}"
    tmux set -gF popup-border-style "fg=#{@thm_blue}"
    tmux set -g popup-border-lines rounded
    tmux set -gF pane-active-border-style "fg=#{@thm_blue}"
    tmux set-environment -u -g LG_CONFIG_FILE 2>/dev/null || true
    tmux set-environment -u -g CONFIG_DIR 2>/dev/null || true
    tmux set-environment -u LG_CONFIG_FILE 2>/dev/null || true
    tmux set-environment -u CONFIG_DIR 2>/dev/null || true
  fi
fi
