#!/bin/sh
# Regenerate the oh-my-posh prompt (~/.config/ohmyposh/zen.toml) from
# zen.template.toml using the live wallpaper palette (matugen.lua — the same
# source wezterm/tmux/nvim already derive from), so the prompt is never stale
# and matches everywhere, including inside tmux.
#
# Token -> palette role (mirrors the ANSI slots the old named colors used):
#   @@ACCENT@@ = wallpaper primary   (was 'blue'   -> path)
#   @@OK@@     = wallpaper secondary  (was 'magenta' -> prompt chevron)
#   @@SOFT@@   = wallpaper tertiary   (was 'yellow'  -> exec time)
#   @@ERR@@    = wallpaper error      (was 'red'     -> failed exit code)
#   @@MUTED@@  = wallpaper outline    (was 'p:grey'  -> git branch)
tpl="$HOME/.config/ohmyposh/zen.template.toml"
out="$HOME/.config/ohmyposh/zen.toml"
palette="$HOME/.config/wezterm/colors/matugen.lua"

# The shared readability rule (WCAG 4.5:1 + lightness repair), so omp matches
# wezterm/tmux/nvim/herdr/zsh instead of carrying a fourth copy of the maths.
LEGIBLE_PY="$HOME/.config/wezterm/utils/legible.py"

# Fallbacks (stock catppuccin mocha tones) keep the prompt valid before the
# first wallpaper sync ever runs.
accent='#89b4fa'
ok='#a6e3a1'
soft='#f9e2af'
err='#f38ba8'
muted='#a6adc8'

if [ -f "$palette" ]; then
   val() { grep -m1 "^\s*$1 =" "$palette" | sed -E 's/.*"(#[0-9A-Fa-f]{6})".*/\1/'; }
   p=$(val primary);      [ -n "$p" ] && accent="$p"
   e=$(val error);        [ -n "$e" ] && err="$e"
   o=$(val outline);      [ -n "$o" ] && muted="$o"
   succ=$(val success)
   if [ -n "$succ" ]; then
      succ_nohash=${succ#\#}
      r=$((16#${succ_nohash:0:2})) g=$((16#${succ_nohash:2:2})) b=$((16#${succ_nohash:4:2}))
      mx=$r mn=$r
      [ $g -gt $mx ] && mx=$g; [ $b -gt $mx ] && mx=$b
      [ $g -lt $mn ] && mn=$g; [ $b -lt $mn ] && mn=$b
      d=$((mx - mn))
      if [ $d -gt 0 ]; then
         if [ $mx -eq $r ]; then h=$(( (60 * (g - b) / d + 360) % 360 ))
         elif [ $mx -eq $g ]; then h=$(( 60 * (b - r) / d + 120 ))
         else h=$(( 60 * (r - g) / d + 240 ))
         fi
         [ "$h" -ge 65 ] && [ "$h" -le 170 ] && ok="$succ"
      fi
   fi
fi

# --- Readability guard ------------------------------------------------------
# The prompt renders straight onto the terminal background, so a dark
# wallpaper token is simply unreadable there — this wallpaper's `success`
# came out at 2.9:1. omp had no gate: whatever matugen produced went in raw.
# Same WCAG 4.5:1 rule wezterm/tmux/nvim/herdr apply; the prompt was the one
# surface where a bad token sat directly under the user's typing.
MIN_CONTRAST=4.5 # WCAG AA for normal text

bghex=$(grep -m1 "^\s*background =" "$palette" 2>/dev/null | sed -E 's/.*"(#[0-9A-Fa-f]{6})".*/\1/')

# No background token means we do not know what the prompt will sit on. The
# old `${bghex:-#1e1e2e}` guessed mocha base, and the gate then passed every
# stock-mocha fallback — so a palette-less run silently rewrote zen.toml from
# wallpaper-derived colors back to stock catppuccin, a flash of the wrong
# theme on every failed sync. Same rule as herdr-palette.sh: leave the last
# good zen.toml alone rather than overwrite it with a guess.
[ -n "$bghex" ] || exit 0
bghex_nohash=${bghex#\#} # strtonum wants bare RRGGBB

contrast() { awk -v a="$1" -v b="$2" -v min="$MIN_CONTRAST" '
  function chan(c) { return (c <= 0.04045) ? c/12.92 : exp(2.4 * log((c + 0.055)/1.055)) }
  function rl(h,   r, g, bl) {
    r = strtonum("0x" substr(h,1,2)); g = strtonum("0x" substr(h,3,2)); bl = strtonum("0x" substr(h,5,2))
    return 0.2126*chan(r/255) + 0.7152*chan(g/255) + 0.0722*chan(bl/255)
  }
  BEGIN {
    la = rl(a); lb = rl(b)
    hi = (la >= lb) ? la : lb; lo = (la >= lb) ? lb : la
    print (((hi + 0.05) / (lo + 0.05)) >= min) ? "ok" : "low"
  }'
}

guard() { # guard <hex-with-#> <fallback-hex-with-#>
  h="${1#\#}"
  # Both args go into strtonum as "0xRRGGBB", so the '#' must be stripped from
  # the background too — leaving it there made strtonum("0x#1a1111") return 0,
  # which read as "every token is low" and forced all five to their fallbacks.
  if [ -z "$h" ] || [ "$(contrast "$h" "$bghex_nohash")" = "low" ]; then
    # Plain substitution is not enough on a light wallpaper: BOTH catppuccin
    # bases fail there (latte green #40a02b is 2.96:1 on #eff1f5, mocha's
    # #a6e3a1 is 1.31:1), so the fallback can be as unreadable as the token it
    # replaced. Repair the FALLBACK's lightness toward the background's
    # opposite end — same role hue, clears the gate. Shared rule in
    # utils/legible.py so omp cannot drift from wezterm/tmux/nvim/herdr.
    python3 "$LEGIBLE_PY" "$2" "#$bghex_nohash" 2>/dev/null || echo "$2"
  else
    echo "$1"
  fi
}

accent=$(guard "$accent" '#89b4fa')
ok=$(guard "$ok" '#a6e3a1')
soft=$(guard "$soft" '#f9e2af')
err=$(guard "$err" '#f38ba8')
muted=$(guard "$muted" '#a6adc8')

sed -e "s|@@ACCENT@@|$accent|g" \
    -e "s|@@OK@@|$ok|g" \
    -e "s|@@SOFT@@|$soft|g" \
    -e "s|@@ERR@@|$err|g" \
    -e "s|@@MUTED@@|$muted|g" \
    "$tpl" > "$out"
exit 0
