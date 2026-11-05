#!/bin/sh
# Downscale wallpapers for DISPLAY only. wezterm decodes and composites the
# backdrop image at every wallpaper swap and window start — a 4K PNG costs
# ~150ms+ of decode and lots of GPU memory per change. These ~1080p JPEG
# copies decode in ~10ms and are visually identical behind the glass wash.
# The ORIGINAL files are never touched: matugen still themes from them.
#
# Cache: $HOME/.cache/wezterm-wallpapers/<name>.jpg (regenerated when the
# source is newer). "1920x>" only shrinks larger images — smaller sources
# stay untouched. Raise 1920 to your monitor width for extra sharpness.
out="$HOME/.cache/wezterm-wallpapers"
mkdir -p "$out"

for src in "$@"; do
   [ -f "$src" ] || continue
   name=$(basename "$src")
   stem=${name%.*}
   dst="$out/${stem}.jpg"

   if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ]; then
      magick "$src" -auto-orient -resize '1920x>' -quality 88 -strip "$dst" 2>/dev/null
   fi
done
exit 0
