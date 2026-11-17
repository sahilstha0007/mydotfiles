#!/usr/bin/env bash
# Runs on tmux client-attached hook:
# 1. Repaints client (fixes stale regions)
# 2. Tracks attached session as last-active
# 3. Detects attached terminal emulator and updates TERMINAL_STACK_PROFILE
# 4. Clears stale profile variables from the opposing emulator so new panes inherit cleanly
tmux refresh-client
~/.config/tmux/scripts/track-active-session.sh "${1:-}" 2>/dev/null || true
client_name=$(tmux display-message -p "#{client_termname}" 2>/dev/null || true)
client_pid=$(tmux display-message -p "#{client_pid}" 2>/dev/null || true)
client_termtype=$(tmux display-message -p "#{client_termtype}" 2>/dev/null || true)

detected=""
case "$client_name:$client_termtype" in
  *kitty*) detected="kitty" ;;
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
    tmux set-environment -u -g WEZTERM_PANE 2>/dev/null || true
    tmux set-environment -u WEZTERM_PANE 2>/dev/null || true
    tmux set-environment -u -g OPENCODE_TUI_CONFIG 2>/dev/null || true
    tmux set-environment -u OPENCODE_TUI_CONFIG 2>/dev/null || true
    tmux source-file -q ~/.config/tmux/colors-catppuccin.conf
    tmux set -gF popup-style "bg=default,fg=#{@thm_text}"
    tmux set -gF popup-border-style "fg=#{@thm_blue}"
    tmux set -g popup-border-lines rounded
    tmux set -gF pane-border-style "fg=#{@thm_surface_2}"
    tmux set -gF pane-active-border-style "fg=#{@thm_blue},bold"
    tmux set -gF clock-mode-colour "#{@thm_blue}"
    tmux set-environment -g BAT_THEME "Catppuccin-mocha"
    tmux set-environment BAT_THEME "Catppuccin-mocha"
    tmux set-environment -g LG_CONFIG_FILE "$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme-catppuccin.yml"
    tmux set-environment -g CONFIG_DIR "$HOME/.config/lazydocker/catppuccin"
    tmux set-environment LG_CONFIG_FILE "$HOME/.config/lazygit/config.yml,$HOME/.config/lazygit/theme-catppuccin.yml"
    tmux set-environment CONFIG_DIR "$HOME/.config/lazydocker/catppuccin"
  elif [ "$detected" = "wezterm" ]; then
    tmux set-environment -u -g KITTY_WINDOW_ID 2>/dev/null || true
    tmux set-environment -u KITTY_WINDOW_ID 2>/dev/null || true
    tmux source-file -q ~/.config/tmux/colors-matugen.conf
    tmux set -gF popup-style "bg=default,fg=#{@thm_text}"
    tmux set -gF popup-border-style "fg=#{@thm_blue}"
    tmux set -g popup-border-lines rounded
    tmux set -gF pane-border-style "fg=#{@thm_surface_2}"
    tmux set -gF pane-active-border-style "fg=#{@thm_blue},bold"
    tmux set -gF clock-mode-colour "#{@thm_blue}"
    tmux set-environment -g BAT_THEME "ansi"
    tmux set-environment BAT_THEME "ansi"
    tmux set-environment -g OPENCODE_TUI_CONFIG "$HOME/.config/opencode/tui-wezterm.json"
    tmux set-environment OPENCODE_TUI_CONFIG "$HOME/.config/opencode/tui-wezterm.json"
    tmux set-environment -u -g LG_CONFIG_FILE 2>/dev/null || true
    tmux set-environment -u -g CONFIG_DIR 2>/dev/null || true
    tmux set-environment -u LG_CONFIG_FILE 2>/dev/null || true
    tmux set-environment -u CONFIG_DIR 2>/dev/null || true
  fi
fi

# Auto-restore saved sessions if this is the primary default server and fresh with 1 pane
socket_path=$(tmux display-message -p '#{socket_path}' 2>/dev/null || true)
if [[ "$socket_path" == */default ]] && [ -z "${TMUX_TEST_SOCK:-}" ] && [ ! -f "$HOME/tmux_no_auto_restore" ] && [ -f "$HOME/.local/share/tmux/resurrect/last" ]; then
  pane_count=$(tmux list-panes -a 2>/dev/null | wc -l || echo 0)
  if [ "$pane_count" -eq 1 ]; then
    if [ -x "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh" ]; then
      "$HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh" 2>/dev/null || true
    fi
  fi
fi
