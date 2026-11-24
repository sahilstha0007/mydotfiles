#!/usr/bin/env bash
set -euo pipefail

notify() {
  noctalia msg notification-show "ML4W bridge" "$1" >/dev/null 2>&1 || true
}

cfg_get() {
  noctalia msg config-get "$1" | tr -d "'\" "
}

get_opt() {
  hyprctl getoption "$1" -j | jq -r 'if .bool != null then (.bool|tostring) elif .int != null then (.int|tostring) elif .float != null then (.float|tostring) elif .css != null then (.css|split(" ")[0]) else "unknown" end'
}

case "${1:-}" in
  keybinds)
    hyprctl binds -j | jq -r '
      def mods:
        [ if (((.modmask / 64) | floor) % 2) == 1 then "SUPER" else empty end,
          if (((.modmask / 8) | floor) % 2) == 1 then "ALT" else empty end,
          if (((.modmask / 4) | floor) % 2) == 1 then "CTRL" else empty end,
          if (.modmask % 2) == 1 then "SHIFT" else empty end
        ] | join(" + ");
      .[] | select((.description // "") != "") | "\(mods) \(.key)  →  \(.description)"
    ' | noctalia dmenu -p "Keybindings" >/dev/null || true
    ;;
  wallpaper-auto)
    if [ "$(cfg_get wallpaper.automation.enabled)" = true ]; then
      noctalia msg config-set wallpaper.automation.enabled false >/dev/null
      notify "Wallpaper rotation off"
    else
      noctalia msg config-set wallpaper.automation.enabled true >/dev/null
      notify "Wallpaper rotation on"
    fi
    ;;
  calendar)
    noctalia msg config-set control_center.hidden_tabs "['weather', 'screen-time']" >/dev/null
    noctalia msg panel-open control-center calendar >/dev/null
    ;;
  special-workspace)
    state="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-noctalia/special-visibility.json"
    if [ "${2:-0}" = 1 ]; then
      [ -s "$state" ] && exit 0
      bar=$(noctalia msg status | jq -r .barVisible)
      dock=$(cfg_get dock.enabled)
      mkdir -p "$(dirname "$state")"
      printf '{"in_special":true,"bar_visible":%s,"dock_enabled":%s}\n' "$bar" "$dock" > "$state.tmp"
      mv "$state.tmp" "$state"
      noctalia msg bar-hide >/dev/null
      noctalia msg dock-hide >/dev/null
    else
      [ -s "$state" ] || exit 0
      bar=$(jq -r .bar_visible "$state")
      dock=$(jq -r .dock_enabled "$state")
      if [ "$bar" = true ]; then noctalia msg bar-show >/dev/null; else noctalia msg bar-hide >/dev/null; fi
      if [ "$dock" = true ]; then noctalia msg dock-show >/dev/null; else noctalia msg dock-hide >/dev/null; fi
      rm -f "$state"
    fi
    ;;
  bar-toggle)
    noctalia msg bar-toggle >/dev/null
    sleep 0.2
    visible=$(noctalia msg status | jq -r '.barVisible // false')
    smart=$(cfg_get bar.main.smart_auto_hide)
    auto=$(cfg_get bar.main.auto_hide)
    if [ "$visible" = false ] || [ "$smart" = true ] || [ "$auto" = true ]; then
      noctalia msg config-set bar.main.reserve_space false >/dev/null
    else
      noctalia msg config-set bar.main.reserve_space true >/dev/null
    fi
    ;;
  dock-toggle)
    noctalia msg dock-toggle >/dev/null
    sleep 0.2
    visible=$(cfg_get dock.enabled)
    smart=$(cfg_get dock.smart_auto_hide)
    auto=$(cfg_get dock.auto_hide)
    if [ "$visible" = false ] || [ "$smart" = true ] || [ "$auto" = true ]; then
      noctalia msg config-set dock.reserve_space false >/dev/null
    else
      noctalia msg config-set dock.reserve_space true >/dev/null
    fi
    ;;
  kill-app)
    class=$(hyprctl activewindow -j | jq -r '.class // empty')
    [ -n "$class" ] || exit 0
    pids=$(hyprctl clients -j | jq -r --arg c "$class" '.[] | select(.class == $c) | .pid' | sort -u)
    [ -n "$pids" ] || exit 0
    kill $pids 2>/dev/null || true
    notify "Closed all $class windows"
    ;;
  workspace-alert)
    id=$(hyprctl activeworkspace -j | jq -r '.id // empty')
    if [ -n "$id" ]; then
      noctalia msg workspace-alert-add "$id" >/dev/null
      notify "Workspace alert added: $id"
    fi
    ;;
  alert-clear)
    noctalia msg workspace-alert-clear-all >/dev/null 2>&1 || true
    notify "Workspace alerts cleared"
    ;;
  window-mode)
    statefile="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/window-mode"
    current=$(cat "$statefile" 2>/dev/null || printf 'tiling\n')
    if [ "$current" = floating ]; then mode=tiling; else mode=floating; fi
    mkdir -p "$(dirname "$statefile")"
    printf '%s\n' "$mode" > "$statefile"
    hyprctl eval "set_window_mode('$mode')" >/dev/null 2>&1 || true
    notify "Window mode: $mode (new windows)"
    ;;
  scratchpad)
    pid=$(hyprctl clients -j | jq -r '.[] | select(.class == "dev-scratchpad") | .pid' | head -n1)
    if [ -z "$pid" ]; then
      setsid kitty --class dev-scratchpad --title Scratchpad -e tmux new-session -A -s scratch >/dev/null 2>&1 &
      exit 0
    fi
    address=$(hyprctl clients -j | jq -r --argjson p "$pid" '.[] | select(.pid == $p) | .address' | head -n1)
    active_pid=$(hyprctl activewindow -j | jq -r '.pid // 0')
    if [ "$active_pid" = "$pid" ] && [ -n "$address" ]; then
      hyprctl dispatch "hl.dsp.window.move({ workspace = \"special:scratchpad\", silent = true, window = \"address:$address\" })" >/dev/null 2>&1 || true
    elif [ -n "$address" ]; then
      ws=$(hyprctl activeworkspace -j | jq -r '.id // 1')
      hyprctl dispatch "hl.dsp.window.move({ workspace = \"$ws\", silent = true, window = \"address:$address\" })" >/dev/null 2>&1 || true
      hyprctl dispatch "hl.dsp.focus({ workspace = \"$ws\" })" >/dev/null 2>&1 || true
    fi
    ;;
  desktop-widgets-edit)
    noctalia msg desktop-widgets-toggle-edit >/dev/null
    ;;
  bar-reload)
    visible=$(noctalia msg status | jq -r '.barVisible // false')
    noctalia msg config-reload >/dev/null
    if [ "$visible" = false ]; then
      noctalia msg bar-hide >/dev/null
    else
      noctalia msg bar-show >/dev/null
    fi
    notify "Bar reloaded"
    ;;
  bar-autohide)
    smart=$(cfg_get bar.main.smart_auto_hide)
    auto=$(cfg_get bar.main.auto_hide)
    if [ "$smart" = true ]; then
      smart=false; auto=true; state=on
    elif [ "$auto" = true ]; then
      smart=false; auto=false; state=off
    else
      smart=true; auto=false; state=smart
    fi
    noctalia msg config-set bar.main.smart_auto_hide "$smart" >/dev/null
    noctalia msg config-set bar.main.auto_hide "$auto" >/dev/null
    if [ "$smart" = false ] && [ "$auto" = false ]; then
      noctalia msg config-set bar.main.reserve_space true >/dev/null
    else
      noctalia msg config-set bar.main.reserve_space false >/dev/null
    fi
    noctalia msg bar-auto-hide-set "$state" >/dev/null 2>&1 || true
    notify "Bar autohide: $state"
    ;;
  dock-reload)
    noctalia msg dock-reload >/dev/null
    notify "Dock reloaded"
    ;;
  dock-autohide)
    smart=$(cfg_get dock.smart_auto_hide)
    auto=$(cfg_get dock.auto_hide)
    if [ "$smart" = true ]; then
      smart=false; auto=true; state=on
    elif [ "$auto" = true ]; then
      smart=false; auto=false; state=off
    else
      smart=true; auto=false; state=smart
    fi
    noctalia msg config-set dock.smart_auto_hide "$smart" >/dev/null
    noctalia msg config-set dock.auto_hide "$auto" >/dev/null
    if [ "$smart" = false ] && [ "$auto" = false ]; then
      noctalia msg config-set dock.reserve_space true >/dev/null
    else
      noctalia msg config-set dock.reserve_space false >/dev/null
    fi
    notify "Dock autohide: $state"
    ;;
  anim-toggle)
    if [ "$(cfg_get shell.animation.enabled)" = true ]; then
      noctalia msg config-set shell.animation.enabled false >/dev/null
      hyprctl eval "hl.config({ animations = { enabled = false } })" >/dev/null 2>&1 || true
      notify "Animations off"
    else
      noctalia msg config-set shell.animation.enabled true >/dev/null
      hyprctl eval "hl.config({ animations = { enabled = true } })" >/dev/null 2>&1 || true
      notify "Animations on"
    fi
    ;;
  gamemode)
    statefile="${XDG_STATE_HOME:-$HOME/.local/state}/ml4w-bridge-gamemode"
    if [ -f "$statefile" ]; then
      anim=true; blur=true; shadow=true; round=14; gin=8; gout=16; aop=1; iop=1; fop=1; border=2
      while read -r opt val; do
        case "$opt" in
          animations:enabled) anim=$val ;;
          decoration:blur:enabled) blur=$val ;;
          decoration:shadow:enabled) shadow=$val ;;
          decoration:rounding) round=$val ;;
          general:gaps_in) gin=$val ;;
          general:gaps_out) gout=$val ;;
          decoration:active_opacity) aop=$val ;;
          decoration:inactive_opacity) iop=$val ;;
          decoration:fullscreen_opacity) fop=$val ;;
          general:border_size) border=$val ;;
        esac
      done < "$statefile"
      hyprctl eval "hl.config({ animations = { enabled = $anim }, general = { gaps_in = $gin, gaps_out = $gout, border_size = $border }, decoration = { rounding = $round, blur = { enabled = $blur }, shadow = { enabled = $shadow }, active_opacity = $aop, inactive_opacity = $iop, fullscreen_opacity = $fop } })" >/dev/null
      rm -f "$statefile"
      notify "Game mode off"
    else
      : > "$statefile"
      for opt in animations:enabled decoration:blur:enabled decoration:shadow:enabled decoration:rounding general:gaps_in general:gaps_out decoration:active_opacity decoration:inactive_opacity decoration:fullscreen_opacity general:border_size; do
        printf '%s %s\n' "$opt" "$(get_opt "$opt")" >> "$statefile"
      done
      hyprctl eval "hl.config({ animations = { enabled = false }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 }, decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false }, active_opacity = 1.0, inactive_opacity = 1.0, fullscreen_opacity = 1.0 } })" >/dev/null
      notify "Game mode on"
    fi
    ;;
  palette)
    selection=$(printf '%s\n' Ayu Catppuccin Dracula Eldritch Gruvbox Kanagawa Noctalia Nord 'Rosé Pine' Tokyo-Night | noctalia dmenu -p "Palette" || true)
    if [ -n "$selection" ]; then
      noctalia msg color-scheme-set builtin "$selection" >/dev/null
      notify "Palette: $selection"
    fi
    ;;
  sidebar)
    noctalia msg panel-open control-center notifications >/dev/null
    ;;
  smart-close)
    status=$(noctalia msg status 2>/dev/null || printf '{}\n')
    panel_id=$(printf '%s\n' "$status" | jq -r '.activePanelId // empty' 2>/dev/null || true)
    if printf '%s\n' "$status" | jq -e '.panelOpen == true' >/dev/null 2>&1; then
      if [ -n "$panel_id" ]; then
        noctalia msg panel-toggle "$panel_id" >/dev/null 2>&1 || true
      else
        noctalia msg panel-close >/dev/null 2>&1 || true
      fi
    else
      hyprctl dispatch 'hl.dsp.window.close()' >/dev/null 2>&1 || true
    fi
    ;;
  fix-portals)
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE || true
    systemctl --user restart xdg-desktop-portal xdg-desktop-portal-hyprland >/dev/null 2>&1 || true
    systemctl --user restart xdg-desktop-portal-gtk >/dev/null 2>&1 || true
    notify "Portals restarted"
    ;;
  *)
    printf 'usage: %s {special-workspace <0|1>|keybinds|smart-close|kill-app|wallpaper-auto|calendar|bar-toggle|bar-reload|bar-autohide|dock-toggle|dock-reload|dock-autohide|workspace-alert|alert-clear|window-mode|scratchpad|desktop-widgets-edit|anim-toggle|gamemode|palette|sidebar|fix-portals}\n' "$0" >&2
    exit 2
    ;;
esac
