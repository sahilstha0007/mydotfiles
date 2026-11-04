#!/usr/bin/env bash
# Derive tmux theme colors from Kitty's ML4W palette (~/.config/kitty/colors-matugen.conf)
# so tmux adopts Kitty's exact soft colors when running inside Kitty.
#
# Generates ~/.config/tmux/colors-kitty.conf with @thm_* tokens that match
# Kitty's native background, foreground, primary accent (blue), and neutral ramp.
set -euo pipefail

src="${1:-$HOME/.config/kitty/colors-matugen.conf}"
out="${2:-$HOME/.config/tmux/colors-kitty.conf}"

python3 - "$src" "$out" << 'EOF'
import sys, re, os

src_path = sys.argv[1]
out_path = sys.argv[2]

# Defaults (matching current Kitty ML4W theme)
colors = {
    'background': '#101418',
    'foreground': '#e0e2e8',
    'color4': '#99ccfa',   # primary blue
    'color1': '#ffb4ab',   # red / error
    'color10': '#9ec49f',  # green
    'color3': '#aca98a',   # yellow
    'color13': '#c49ec4',  # mauve / orchid
    'color9': '#c49ea0',   # pink / maroon
    'color14': '#9ec3c4',  # teal / aqua
    'color12': '#a39ec4',  # sapphire / lavender
}

if os.path.exists(src_path):
    with open(src_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('/*'):
                continue
            m = re.match(r'^([a-zA-Z0-9_]+)\s+(#[0-9a-fA-F]{6})', line)
            if m:
                k, v = m.group(1), m.group(2).lower()
                colors[k] = v

def hex_to_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i+2], 16) for i in (0, 2, 4)]

def rgb_to_hex(rgb):
    return '#{:02x}{:02x}{:02x}'.format(
        max(0, min(255, int(round(rgb[0])))),
        max(0, min(255, int(round(rgb[1])))),
        max(0, min(255, int(round(rgb[2]))))
    )

def mix(c1, c2, t):
    r1, g1, b1 = hex_to_rgb(c1)
    r2, g2, b2 = hex_to_rgb(c2)
    return rgb_to_hex([r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t])

def chan(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rel_lum(h):
    r, g, b = hex_to_rgb(h)
    return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)

def contrast(c1, c2):
    l1, l2 = rel_lum(c1), rel_lum(c2)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)

base = colors.get('background', '#101418')
text = colors.get('foreground', '#e0e2e8')

# Derive surface ramp matching nvim terminal-colors.lua
surface0 = mix(base, text, 0.08)
surface1 = mix(surface0, text, 0.12)
surface2 = mix(surface0, text, 0.25)

# Derive overlay / neutral ramp ensuring MIN_CONTRAST >= 4.5
def readable(t):
    c = mix(text, base, t)
    if contrast(c, base) >= 4.5:
        return c
    lift = t - 0.05
    while lift >= 0:
        c = mix(text, base, lift)
        if contrast(c, base) >= 4.5:
            return c
        lift -= 0.05
    return text

overlay0 = readable(0.68)
overlay1 = readable(0.55)
overlay2 = readable(0.40)
subtext0 = readable(0.30)
subtext1 = readable(0.15)
mantle = mix(base, '#000000', 0.15)
crust = mix(base, '#000000', 0.30)

blue = colors.get('color4', '#99ccfa')
red = colors.get('color1', '#ffb4ab')
green = colors.get('color10', '#9ec49f')
yellow = colors.get('color3', '#aca98a')
mauve = colors.get('color13', '#c49ec4')
pink = colors.get('color9', '#c49ea0')
teal = colors.get('color14', '#9ec3c4')
sapphire = colors.get('color12', '#a39ec4')
lavender = colors.get('color12', '#a39ec4')
maroon = colors.get('color9', '#c49ea0')
peach = colors.get('color3', '#aca98a')
sky = colors.get('color4', '#99ccfa')
rosewater = '#f5e0dc'
flamingo = '#f2cdcd'

out_dir = os.path.dirname(out_path)
if out_dir:
    os.makedirs(out_dir, exist_ok=True)

lines = [
    "# Auto-generated from {} by colors-from-kitty.sh — do not edit by hand.".format(src_path),
    'set -g @catppuccin_flavor "mocha"',
    "",
    "# Kitty palette tokens (matching ML4W desktop palette in Kitty)",
    'set -g @thm_bg "{}"'.format(base),
    'set -g @thm_fg "{}"'.format(text),
    'set -g @thm_base "{}"'.format(base),
    'set -g @thm_text "{}"'.format(text),
    'set -g @thm_rosewater "{}"'.format(rosewater),
    'set -g @thm_flamingo "{}"'.format(flamingo),
    'set -g @thm_pink "{}"'.format(pink),
    'set -g @thm_mauve "{}"'.format(mauve),
    'set -g @thm_red "{}"'.format(red),
    'set -g @thm_maroon "{}"'.format(maroon),
    'set -g @thm_peach "{}"'.format(peach),
    'set -g @thm_yellow "{}"'.format(yellow),
    'set -g @thm_green "{}"'.format(green),
    'set -g @thm_teal "{}"'.format(teal),
    'set -g @thm_sky "{}"'.format(sky),
    'set -g @thm_sapphire "{}"'.format(sapphire),
    'set -g @thm_blue "{}"'.format(blue),
    'set -g @thm_lavender "{}"'.format(lavender),
    'set -g @thm_subtext_1 "{}"'.format(subtext1),
    'set -g @thm_subtext1 "{}"'.format(subtext1),
    'set -g @thm_subtext_0 "{}"'.format(subtext0),
    'set -g @thm_subtext0 "{}"'.format(subtext0),
    'set -g @thm_overlay_2 "{}"'.format(overlay2),
    'set -g @thm_overlay2 "{}"'.format(overlay2),
    'set -g @thm_overlay_1 "{}"'.format(overlay1),
    'set -g @thm_overlay1 "{}"'.format(overlay1),
    'set -g @thm_overlay_0 "{}"'.format(overlay0),
    'set -g @thm_overlay0 "{}"'.format(overlay0),
    'set -g @thm_surface_2 "{}"'.format(surface2),
    'set -g @thm_surface2 "{}"'.format(surface2),
    'set -g @thm_surface_1 "{}"'.format(surface1),
    'set -g @thm_surface1 "{}"'.format(surface1),
    'set -g @thm_surface_0 "{}"'.format(surface0),
    'set -g @thm_surface0 "{}"'.format(surface0),
    'set -g @thm_mantle "{}"'.format(mantle),
    'set -g @thm_crust "{}"'.format(crust),
    ""
]

with open(out_path + ".tmp", "w") as f:
    f.write("\n".join(lines))
os.replace(out_path + ".tmp", out_path)
EOF
