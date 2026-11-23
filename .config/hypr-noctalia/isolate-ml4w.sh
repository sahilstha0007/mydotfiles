#!/bin/sh
# Run from the Hyprland + Noctalia start hook.
# graphical-session.target may (re)start these enabled user units a moment
# after the compositor hook fires, so wait before stopping them.
[ "$NOCTALIA_SESSION" = 1 ] || exit 0
sleep 3
systemctl --user stop elephant.service walker.service >/dev/null 2>&1
pkill -x swaync >/dev/null 2>&1 || true
pkill -x waybar >/dev/null 2>&1 || true
pkill -x awww-daemon >/dev/null 2>&1 || true
