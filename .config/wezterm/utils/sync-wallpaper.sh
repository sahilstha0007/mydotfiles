#!/bin/sh
# Kept as a deterministic no-op so existing callers (wezterm's backdrop commit
# hook and any external caller) stay valid. Wallpaper-driven palette generation
# was removed: the terminal stack uses committed static palettes instead.
exit 0
