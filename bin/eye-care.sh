#!/usr/bin/env bash
set -euo pipefail

state="$HOME/.local/state/eye-care"
mkdir -p "$state"

restore_brightness() {
  [ -f "$state/dimmed" ] || return 0
  local saved
  saved=$(cat "$state/brightness" 2>/dev/null || true)
  [ -n "$saved" ] && brightnessctl set "$saved" >/dev/null 2>&1 || true
  rm -f "$state/dimmed" "$state/brightness"
}

choice="${1:-}"
if [ -z "$choice" ]; then
  choice=$(printf 'Night light\nBlue-light filter\nGrayscale\nDim\nReset all\n' | rofi -dmenu -p 'Eye care')
fi

case "$choice" in
  'Night light')
    restore_brightness
    noctalia msg nightlight-force-toggle
    ;;
  'Blue-light filter')
    restore_brightness
    if [ "$(hyprshade current 2>/dev/null)" = "blue-light-filter" ]; then
      hyprshade off
    else
      hyprshade on blue-light-filter
    fi
    ;;
  'Grayscale')
    restore_brightness
    if [ "$(hyprshade current 2>/dev/null)" = "grayscale" ]; then
      hyprshade off
    else
      hyprshade on grayscale
    fi
    ;;
  'Dim')
    if [ ! -f "$state/dimmed" ]; then
      brightnessctl get > "$state/brightness"
      touch "$state/dimmed"
    fi
    brightnessctl set 40% >/dev/null
    ;;
  'Reset all')
    restore_brightness
    hyprshade off >/dev/null 2>&1 || true
    noctalia msg nightlight-disable >/dev/null 2>&1 || true
    ;;
esac
