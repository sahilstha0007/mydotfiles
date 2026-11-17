#!/usr/bin/env bash
# Static palette reassert for tmux. The old script generated colors from the
# wallpaper-derived wezterm palette; that pipeline is gone. The committed
# Apple Glass palette is the only source now.
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
src="${1:-$here/colors-apple-glass.conf}"
out="${2:-$HOME/.config/tmux/colors-matugen.conf}"

[ -f "$src" ] || exit 0
cp "$src" "$out"
