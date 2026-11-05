#!/usr/bin/env python3
"""One readability rule for the whole terminal stack.

Every layer that paints text from a wallpaper palette — wezterm, tmux, nvim,
zsh, herdr, oh-my-posh, opencode — needs the same question answered: is this
color readable on this wallpaper background, and if not, what should it become?

Answering it six times produced six subtly different answers, and they
disagreed in a way that shipped unreadable text. The concrete case: on a LIGHT
wallpaper, NEITHER catppuccin base clears WCAG AA.

    latte green  #40a02b  -> 2.96:1 on #eff1f5
    mocha green  #a6e3a1  -> 1.31:1 on #eff1f5

So a fixed substitution table — "unreadable wallpaper token, use catppuccin" —
picks a fallback that is itself unreadable. That is how a light wallpaper ends
up with a command colour you cannot read. The fix is to REPAIR: walk the
token's lightness toward the opposite end of the background until it clears the
gate, keeping its hue, and only fall back to catppuccin when repair cannot get
there. Repair keeps the color in the wallpaper's family *and* readable.

The alternative — rejecting the wallpaper token outright — is what the shell
generator does for most roles and is correct there, because those roles are
already fixed to a readable catppuccin slot. Repair is for the case where the
fallback itself fails.

WCAG 2.1 relative luminance and contrast ratio, MIN_CONTRAST 4.5 for normal
text. The same constant and the same formula appear in colors/custom.lua,
tmux/colors-from-matugen.sh, and nvim's terminal-colors.lua; this module is
the python3 face of that one shared rule.
"""

import colorsys
import re

MIN_CONTRAST = 4.5  # WCAG AA for normal text


def _chan(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rel_lum(h):
    """WCAG relative luminance of a #rrggbb string."""
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [_chan(x) for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    """WCAG contrast ratio between two #rrggbb strings."""
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def rgb(h):
    return [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]


def hx(t):
    return '#%02x%02x%02x' % tuple(round(max(0.0, min(1.0, v)) * 255) for v in t)


def polar(bg):
    """1.0 when the background is dark (walk colors lighter), else 0.0."""
    return 1.0 if rel_lum(bg) < 0.18 else 0.0


def legible(c, bg, *fallbacks, steps=16):
    """`c` if it clears MIN_CONTRAST on `bg`; else the same hue with lightness
    walked toward the background's opposite end until it does; else whichever
    of `fallbacks` reads best.

    Use this when the wallpaper token must stay on-palette. For roles that are
    already a fixed readable slot, plain substitution is enough and cheaper.
    """
    if contrast(c, bg) >= MIN_CONTRAST:
        return c
    h, l, s = colorsys.rgb_to_hls(*rgb(c))
    p = polar(bg)
    for step in range(1, steps + 1):
        cand = hx(colorsys.hls_to_rgb(h, l + (p - l) * step / steps, s))
        if contrast(cand, bg) >= MIN_CONTRAST:
            return cand
    return max(fallbacks, key=lambda x: contrast(x, bg)) if fallbacks else c


def read_palette(path):
    """Parse a flat Lua palette table of "key = \\"#rrggbb\\"" lines."""
    try:
        txt = open(path, encoding='utf-8').read()
    except OSError:
        return {}
    return dict(re.findall(r'^\s*(\w+)\s*=\s*"(#[0-9A-Fa-f]{6})"', txt, re.M))


LATTE = dict(text='#4c4f69', muted='#6c6f85', red='#d20f39', yellow='#df8e1d',
             green='#40a02b', blue='#1e66f5', mauve='#8839ef',
             pink='#ea76cb', teal='#179299')
MOCHA = dict(text='#cdd6f4', muted='#a6adc8', red='#f38ba8', yellow='#f9e2af',
             green='#a6e3a1', blue='#89b4fa', mauve='#cba6f7',
             pink='#f5c2e7', teal='#94e2d5')


def base_for(bg):
    """The catppuccin base matching this background's luminance. Same
    299/587/114 gate as the shell and lua layers."""
    r, g, b = (int(bg[i:i + 2], 16) for i in (1, 3, 5))
    return LATTE if 299 * r + 587 * g + 114 * b >= 127500 else MOCHA


if __name__ == '__main__':
    import sys

    # CLI: legible.py <hex> <bg> [fallback...] -> repaired hex on stdout.
    # The shell layers (herdr, omp, opencode) call this so their gate is this
    # module's gate and not a fourth awk copy of it.
    if len(sys.argv) > 2 and sys.argv[1].startswith('#'):
        c, bg = sys.argv[1], sys.argv[2]
        fbs = sys.argv[3:] or (list(LATTE.values()) + list(MOCHA.values()))
        print(legible(c, bg, *fbs))
        sys.exit(0)

    # ponytail: self-check, because this module is the readability gate for six
    # tools and a broken contrast() would silently ship unreadable text.
    assert MIN_CONTRAST == 4.5
    assert abs(contrast('#000000', '#ffffff') - 21.0) < 0.01, 'black/white is 21:1'
    assert abs(rel_lum('#ffffff') - 1.0) < 1e-9, 'white is luminance 1.0'
    # The case that motivated repair: neither catppuccin base is readable here.
    assert contrast('#40a02b', '#eff1f5') < MIN_CONTRAST, 'latte green must fail'
    assert contrast('#a6e3a1', '#eff1f5') < MIN_CONTRAST, 'mocha green must fail'
    repaired = legible('#40a02b', '#eff1f5', LATTE['green'])
    assert contrast(repaired, '#eff1f5') >= MIN_CONTRAST, 'repair must reach the gate'
    # A readable token must pass through untouched.
    assert legible('#ffb4ab', '#13140d', MOCHA['red']) == '#ffb4ab'
    print('legible.py self-check OK')