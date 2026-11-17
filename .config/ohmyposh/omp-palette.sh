#!/usr/bin/env bash
# Regenerate the oh-my-posh prompt (zen.toml) from zen.template.toml using the
# committed static Apple Dark Glass palette. No wallpaper, no matugen, no file
# reads other than the template.
set -euo pipefail

tpl="$HOME/.config/ohmyposh/zen.template.toml"
out="$HOME/.config/ohmyposh/zen.toml"

# Roles mirror the ANSI slots in ~/.config/kitty/themes/apple-glass.conf.
accent='#2dd4bf' # primary / cursor / active tab
ok='#7dce8b'     # color2 (success)
soft='#f2d97a'   # color3 (tertiary)
err='#ff6b6b'    # color1 (error)

sed -e "s|@@ACCENT@@|$accent|g" \
   -e "s|@@OK@@|$ok|g" \
   -e "s|@@SOFT@@|$soft|g" \
   -e "s|@@ERR@@|$err|g" \
   "$tpl" > "$out"
exit 0
