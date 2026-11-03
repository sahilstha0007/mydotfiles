#!/usr/bin/env bash
# Derive tmux theme colors from the SAME matugen palette wezterm renders
# (~/.config/wezterm/colors/matugen.lua), so tmux adopts the wallpaper exactly
# like wezterm/nvim — one source of truth, all three in sync.
#
# Like wezterm's colors/custom.lua, the wallpaper's background luminance picks
# the catppuccin base — latte (light theme, dark text) or mocha (dark theme,
# bright text) — and the matugen tokens override the same subset custom.lua
# overrides. Everything else keeps that base's own defaults, so the WHOLE
# status bar flips correctly on light wallpapers. Keep both files in sync.
#
# The file is sourced AFTER the catppuccin theme, so it fully determines the
# visible colors. Both underscore (@thm_surface_0, catppuccin theme naming)
# and underscore-less (@thm_surface0, used by some helper scripts) spellings
# are emitted for the tokens people reference.
#
# Usage: colors-from-matugen.sh [SRC] [OUT]   (defaults below)
# Run manually after a wallpaper change (sync-wallpaper.sh calls it too).
# Takes effect on the next tmux start (or `tmux source-file ~/.config/tmux/tmux.conf`).

set -euo pipefail

src="${1:-$HOME/.config/wezterm/colors/matugen.lua}"
out="${2:-$HOME/.config/tmux/colors-matugen.conf}"

[ -f "$src" ] || exit 0

get() {
  sed -nE "s/^[[:space:]]*$1 = \"#([0-9a-fA-F]{6})\".*/\1/p" "$src" | head -1
}

bg=$(get background)
fg=$(get foreground)

# Luminance decides the base: same rule as colors/custom.lua (0.299/0.587/0.114
# weighting, threshold 0.5). Pure bash so no gawk dependency.
# Offsets are 0-based: ${bghex:0:2} is the RR byte. (Was :1:2/:3:2/:5:2 —
# skipped the first hex digit and misclassified light/dark near the 0.5 gate.)
bghex=${bg:-000000}
_r=$((16#${bghex:0:2})); _g=$((16#${bghex:2:2})); _b=$((16#${bghex:4:2}))
if [ $((299 * _r + 587 * _g + 114 * _b)) -ge 127500 ]; then
  is_light=1
else
  is_light=0
fi

# Catppuccin token values for the mode's base (same tables as custom.lua).
if [ "$is_light" = 1 ]; then
  # catppuccin latte
  D_rosewater=dc8a78 D_flamingo=dd7878 D_pink=ea76cb D_mauve=8839ef
  D_red=d20f39 D_maroon=e64553 D_peach=fe640b D_yellow=df8e1d
  D_green=40a02b D_teal=179299 D_sky=04a5e5 D_sapphire=209fb5
  D_blue=1e66f5 D_lavender=7287fd
  D_text=4c4f69 D_subtext_1=5c5f77 D_subtext_0=6c6f85
  D_overlay_2=7c7f93 D_overlay_1=8c8fa1 D_overlay_0=9ca0b0
  D_surface_2=acb0be D_surface_1=bcc0cc D_surface_0=ccd0da
  D_base=eff1f5 D_mantle=e6e9ef D_crust=dce0e8
else
  # catppuccin mocha
  D_rosewater=f5e0dc D_flamingo=f2cdcd D_pink=f5c2e7 D_mauve=cba6f7
  D_red=f38ba8 D_maroon=eba0ac D_peach=fab387 D_yellow=f9e2af
  D_green=a6e3a1 D_teal=94e2d5 D_sky=89dceb D_sapphire=74c7ec
  D_blue=89b4fa D_lavender=b4befe
  D_text=cdd6f4 D_subtext_1=bac2de D_subtext_0=a6adc8
  D_overlay_2=9399b2 D_overlay_1=7f849c D_overlay_0=6c7086
  D_surface_2=585b70 D_surface_1=45475a D_surface_0=313244
  D_base=1e1e2e D_mantle=181825 D_crust=11111b
fi

primary=$(get primary)       # -> blue/rosewater/teal (like custom.lua)
secondary=$(get secondary)   # -> pink
tertiary=$(get tertiary)     # -> yellow
error=$(get error)           # -> red
success=$(get success)       # -> green
surface0=$(get surface0)
surface1=$(get surface1)
surface2=$(get surface2)
outline=$(get outline)       # -> overlay0

# Fall back to the mode defaults for any token matugen did not provide.
primary=${primary:-$D_blue}; secondary=${secondary:-$D_pink}
tertiary=${tertiary:-$D_yellow}; error=${error:-$D_red}; success=${success:-$D_green}
surface0=${surface0:-$D_surface_0}; surface1=${surface1:-$D_surface_1}
surface2=${surface2:-$D_surface_2}; outline=${outline:-$D_overlay_0}
bg=${bg:-$D_base}; fg=${fg:-$D_text}

# The LABEL colour, as raw hex. Surfaces are guarded against this (see below),
# so it has to be a colour that is actually readable ON the background first —
# a wallpaper can hand back a foreground as washed out as its background, and
# measuring every fill against a label nobody could read makes the guard
# meaningless (on the near-white hostile palette #f7f6f2 would have "passed"
# every surface at 1.1:1). Same rule as wezterm's guard(): an unreadable
# foreground falls back to the catppuccin text colour for the mode. Applied in
# the guard block below, which owns contrast(); this just fixes the variable
# the guards read.
fghex=$fg

# --- Readability guard -----------------------------------------------------
# matugen tokens are wallpaper-derived, so a token can be unreadable as status
# text (e.g. "success" came out dark brown #7f560f on this wallpaper and
# painted the session name + date nearly invisible). If a token doesn't
# contrast with the theme background, fall back to the catppuccin base color
# for that slot — same rule as wezterm's guard() and nvim's terminal-colors.lua.
#
# WCAG relative luminance + contrast ratio, NOT a threshold on the
# 299/587/114 brightness number. The old 102000/160000 cut is a display-
# brightness approximation, not a readability measure: it passed #6e6e6a
# (3.64:1) and #787878 (4.20:1) as "readable" on a near-black bg because their
# brightness scores cleared 0.40 — grey text shipping under the 4.5:1 minimum.
#
# One awk pass per token: the gamma curve needs a float pow, which POSIX awk
# has no operator for but gawk/mawk both get from exp(2.4*log(x)). Pure-bash
# integer alternatives were tried and discarded — a tabulated sRGB curve was
# off by 2x on mid channels, so this must be real float math.
MIN_CONTRAST=4.5 # WCAG AA for normal text

# contrast <a> <b> -> WCAG contrast ratio (1..21), symmetric in its arguments.
contrast() { awk -v a="$1" -v b="$2" -v min="$MIN_CONTRAST" '
  function chan(c) { return (c <= 0.04045) ? c/12.92 : exp(2.4 * log((c + 0.055)/1.055)) }
  function rl(h,   r, g, bl) {
    r = strtonum("0x" substr(h,1,2)); g = strtonum("0x" substr(h,3,2)); bl = strtonum("0x" substr(h,5,2))
    return 0.2126*chan(r/255) + 0.7152*chan(g/255) + 0.0722*chan(bl/255)
  }
  BEGIN {
    la = rl(a); lb = rl(b)
    hi = (la >= lb) ? la : lb; lo = (la >= lb) ? lb : la
    ratio = (hi + 0.05) / (lo + 0.05)
    print (ratio >= min) ? "ok" : "low"
  }'
}

guard() { # guard <hex-no-#> <fallback-hex-no-#>
  # Default: measure against the status background — correct for anything drawn
  # as text or as a hairline on the bar.
  local h="$1" fb="$2" ref="${3:-$bghex}"
  if [ -z "$h" ] || [ "$(contrast "$h" "$ref")" = "low" ]; then
    echo "$fb"
  else
    echo "$h"
  fi
}

# Text lift — mirrors wezterm's colors/custom.lua `blend(c.text, extreme, 0.55)`.
#
# wezterm and nvim render plain text one step away from the background
# (#e4e3d7 -> #f3f2ed), but this generator used the RAW matugen foreground, so
# the tmux bar's text sat ~7 units darker than the terminal and the editor —
# two bars, two text tones. Blending the same 0.55 toward the theme extreme
# (white on dark, black on light) makes @thm_fg/@thm_text byte-identical to the
# value wezterm resolves, so every surface shows plain text at one brightness.
#
# Pure-bash integer maths (no awk strtonum — mawk lacks it, and this script
# deliberately avoids a gawk dependency). floor(v + (t-v)*0.55 + 0.5) is
# computed as (100v + 55(t-v) + 50) / 100, which is exact for 0..255 inputs.
# Direction only INCREASES text/background contrast, and the surfaces below are
# measured against the (now brighter) fg, so nothing falls back differently.
lift_text() { # lift_text <RRGGBB> <1=light,0=dark>
  local h="$1" light="$2" t=255
  [ "$light" = 1 ] && t=0
  local r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))
  r=$(((100 * r + 55 * (t - r) + 50) / 100))
  g=$(((100 * g + 55 * (t - g) + 50) / 100))
  b=$(((100 * b + 55 * (t - b) + 50) / 100))
  # Bare RRGGBB: the caller's fghex carries no '#', and the emit step adds it.
  printf '%02x%02x%02x' "$r" "$g" "$b"
}

primary=$(guard "$primary" "$D_blue")
secondary=$(guard "$secondary" "$D_pink")
tertiary=$(guard "$tertiary" "$D_yellow")
error=$(guard "$error" "$D_red")
success=$(guard "$success" "$D_green")
# outline is TEXT on the bar (the │ separators), so it keeps the bg reference.
outline=$(guard "$outline" "$D_overlay_0")
# The label colour itself, guarded before anything is measured against it (see
# the note where fghex is set). Guarding it LAST-but-one matters: the surfaces
# below measure against the guarded value, so a washed-out wallpaper foreground
# can no longer rubber-stamp unreadable fills.
fghex=$(guard "$fghex" "$D_text")
# Lift AFTER the guard, matching wezterm's custom.lua (which guards text, then
# blends it). See lift_text() above for why.
fghex=$(lift_text "$fghex" "$is_light")
fg=$fghex

# --- Surfaces: measured against the LABEL, not the background --------------
# surface0/1/2 are FILLS — they paint the window-list pills, the popup interior
# and the pane dividers. A fill never has to contrast with the background to be
# correct: by construction every catppuccin surface is a near-neighbour of its
# own base (mocha surface_0 vs base = 1.30:1, latte surface_0 vs base = 1.37:1).
# So the original "fill vs bg >= 4.5" reading is UNSATISFIABLE BY DESIGN: on this
# wallpaper it rejects surface_0 #1f2019 (1.13:1) and then accepts its own
# fallback #313244 (1.47:1) as equally bad — a no-op that only added an awk fork.
#
# What a fill actually has to do is stay far enough from the text drawn ON it,
# or the fill swallows the label. That is the same 4.5:1 rule with a different
# reference: measure the fill against @thm_fg. Non-degenerate on both bases —
#   wallpaper #1f2019 vs fg = 12.7:1   mocha #313244 vs text = 8.7:1
#   wallpaper #34352d vs fg =  9.6:1   mocha #585b70 vs text = 4.6:1
#   latte    #ccd0da vs text = 5.2:1   latte #acb0be vs text = 3.7:1 (guarded)
# and it catches the real failure mode: a matugen surface that lands close to
# the wallpaper's own foreground (light surface under light text, or dark
# surface under dark text) collapses to ~1.1:1 and falls back to a known-good
# catppuccin surface.
#
# Same guard(), same MIN_CONTRAST, same D_* fallbacks — only the reference
# colour differs. surface_2 is the exception: it is also the INACTIVE PANE
# BORDER, i.e. text-on-background rather than a fill, so it is measured both
# ways and has to clear the background gate as well.
surface0=$(guard "$surface0" "$D_surface_0" "$fghex")
surface1=$(guard "$surface1" "$D_surface_1" "$fghex")
surface2=$(guard "$surface2" "$D_surface_2" "$fghex")
surface2=$(guard "$surface2" "$D_surface_2")

emit() { # emit <name> <value>: single set -g line
  printf 'set -g @thm_%s "#%s"\n' "$1" "$2"
}

{
  echo "# Auto-generated from $src by colors-from-matugen.sh — do not edit by hand."
  echo "# $([ "$is_light" = 1 ] && echo 'light theme (wallpaper luminance)' || echo 'dark theme (wallpaper luminance)')"
  echo "set -g @catppuccin_flavor \"$([ "$is_light" = 1 ] && echo latte || echo mocha)\""
  echo
  echo "# Catppuccin base ($([ "$is_light" = 1 ] && echo latte || echo mocha)) — canonical underscore names"
  emit bg "$D_base"
  emit fg "$D_text"
  emit rosewater "$D_rosewater"
  emit flamingo "$D_flamingo"
  emit pink "$D_pink"
  emit mauve "$D_mauve"
  emit red "$D_red"
  emit maroon "$D_maroon"
  emit peach "$D_peach"
  emit yellow "$D_yellow"
  emit green "$D_green"
  emit teal "$D_teal"
  emit sky "$D_sky"
  emit sapphire "$D_sapphire"
  emit blue "$D_blue"
  emit lavender "$D_lavender"
  emit subtext_1 "$D_subtext_1"
  emit subtext_0 "$D_subtext_0"
  emit overlay_2 "$D_overlay_2"
  emit overlay_1 "$D_overlay_1"
  emit overlay_0 "$D_overlay_0"
  emit surface_2 "$D_surface_2"
  emit surface_1 "$D_surface_1"
  emit surface_0 "$D_surface_0"
  emit mantle "$D_mantle"
  emit crust "$D_crust"
  echo
  echo "# Underscore-less aliases (referenced by helper scripts)"
  emit text "$D_text"
  emit base "$D_base"
  emit subtext1 "$D_subtext_1"
  emit subtext0 "$D_subtext_0"
  emit overlay2 "$D_overlay_2"
  emit overlay1 "$D_overlay_1"
  emit overlay0 "$D_overlay_0"
  emit surface2 "$D_surface_2"
  emit surface1 "$D_surface_1"
  emit surface0 "$D_surface_0"
  echo
  echo "# Wallpaper overrides (mirrors wezterm colors/custom.lua)"
  emit bg "$bg"
  emit fg "$fg"
  emit base "$bg"
  emit text "$fg"
  emit rosewater "$primary"
  emit red "$error"
  emit green "$success"
  emit yellow "$tertiary"
  emit blue "$primary"
  emit pink "$secondary"
  emit teal "$primary"
  emit overlay_0 "$outline"
  emit overlay0 "$outline"
  emit surface_0 "$surface0"
  emit surface0 "$surface0"
  emit surface_1 "$surface1"
  emit surface1 "$surface1"
  emit surface_2 "$surface2"
  emit surface2 "$surface2"
  emit mantle "$bg"
  emit crust "$bg"
} > "$out"
