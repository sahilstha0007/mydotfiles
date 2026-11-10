#!/bin/sh
# Emit zsh-syntax-highlighting styles AND fzf --color= flags whose colors come
# from the LIVE wallpaper palette, computed at wallpaper-sync time (shell
# startup stays instant — shells just source the output file).
#
# Every highlight state maps to a palette role, so the typing surface re-themes
# with the prompt/tmux/editor instead of staying frozen on a hardcoded hex set.
#
# Two rules the naive mapping gets wrong:
#
#   1. Readability gate (WCAG AA 4.5:1). matugen tokens are wallpaper-derived
#      and are NOT guaranteed legible on the wallpaper's own background — this
#      wallpaper's `success` is a dark olive that paints command names nearly
#      invisible. Same rule as tmux colors-from-matugen.sh, wezterm
#      colors/custom.lua and nvim terminal-colors.lua: real WCAG relative
#      luminance + contrast ratio against `background`. A token that fails is
#      first REPAIRED — same hue, lightness walked until it reads — because
#      that keeps it in the wallpaper's family. Only if repair can't reach
#      4.5:1 does it drop to the catppuccin base (mocha or latte, picked by the
#      same 299/587/114 background gate custom.lua uses). Repair matters: on a
#      light wallpaper neither base's accents clear 4.5:1 for every slot, so a
#      fixed substitution table would ship unreadable text too.
#
#   2. unknown-token keeps the COMPLEMENTARY hue of the wallpaper accent
#      (hue + 180°) instead of `error` red. While typing, every partial word is
#      an unknown token — painting those red makes the whole line flash red and
#      trains the eye to ignore the color. The complement stays distinct from
#      the warm accent/status hues without shouting. The states that really are
#      errors (precommand, bracket-error, path_approx) still use `error`.
#
# Usage: zsh-highlight-sync.sh [SRC] [OUT]   (defaults below)
# SRC/OUT are overridable only so this can be tested against a throwaway
# palette without touching the live one; sync-wallpaper.sh calls it bare.
src="${1:-$HOME/.config/wezterm/colors/matugen.lua}"
out="${2:-$HOME/.cache/zsh-wallpaper.zsh}"

# Remove stale output when we can't compute (python absent / palette missing),
# so shells fall back to the static styles in ~/.zshrc_custom. The .tmp goes
# with it: a run killed mid-write (SIGKILL, full disk) can't clean up after
# itself, and that orphan would otherwise sit next to the output forever.
if ! command -v python3 >/dev/null 2>&1; then
   rm -f "$out" "$out.tmp"
   exit 0
fi

python3 - "$out" "$src" <<'PY'
import colorsys, os, re, sys

out, palette = sys.argv[1], sys.argv[2]
try:
    txt = open(palette, encoding='utf-8').read()
except OSError:
    sys.exit(0)

tok = dict(re.findall(r'^\s*(\w+)\s*=\s*"(#[0-9A-Fa-f]{6})"', txt, re.M))
bg = tok.get('background')
if not bg:  # no background -> no contrast reference, leave the static styles
    sys.exit(0)

MIN_CONTRAST = 4.5  # WCAG AA for normal text; same constant as the rest of the stack


def rl(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    la, lb = rl(a), rl(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


rgb = lambda h: [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
hx = lambda t: '#%02x%02x%02x' % tuple(round(max(0.0, min(1.0, v)) * 255)
                                        for v in t)


def lift(h, amount=0.55):
    """Mirror wezterm's colors/custom.lua text lift, byte-exact.

    custom.lua renders plain text one step from the theme extreme
    (#e4e3d7 -> #f3f2ed); nvim does the same, but every generator that used
    the raw matugen foreground left its surface on the darker token. The shell
    'text' states below are exactly that surface, so they are lifted to match
    the terminal/editor: blend toward white on dark, black on light, with
    floor(a + (t-a)*amount + 0.5) the same rounding custom.lua uses.
    """
    t = 0.0 if LIGHT else 255.0
    out = []
    for i in (1, 3, 5):
        a = int(h[i:i + 2], 16)
        out.append(int(a + (t - a) * amount + 0.5))
    return '#%02x%02x%02x' % tuple(out)


# Background luminance picks the catppuccin base, same gate as wezterm's
# custom.lua and the tmux script. Both bases are always loaded: a role whose
# latte counterpart is unreadable on a light wallpaper still needs the mocha
# value as its next fallback (see guard()).
r, g, b = (int(bg[i:i + 2], 16) for i in (1, 3, 5))
LATTE = dict(text='#4c4f69', muted='#6c6f85', red='#d20f39', yellow='#df8e1d',
             green='#40a02b', blue='#1e66f5', mauve='#8839ef',
             pink='#ea76cb', teal='#179299')
MOCHA = dict(text='#cdd6f4', muted='#a6adc8', red='#f38ba8', yellow='#f9e2af',
             green='#a6e3a1', blue='#89b4fa', mauve='#cba6f7',
             pink='#f5c2e7', teal='#94e2d5')
LIGHT = 299 * r + 587 * g + 114 * b >= 127500
D = LATTE if LIGHT else MOCHA

# Toward-light or toward-dark for this background: anything that fails the gate
# gets its lightness walked this way until it reads (see legible()).
POLAR = 1.0 if rl(bg) < 0.18 else 0.0


def legible(c, *fbs):
    """`c` if it clears MIN_CONTRAST on this background; else its hue darkened or
    brightened toward POLAR until it does; else the best of the catppuccin
    candidates `fbs`.

    A hue-preserving fallback can't be trusted either: on a light wallpaper
    catppuccin latte's own accents are too light (green #40a02b is 2.96:1 on
    #eff1f5) and mocha's are too dark (#a6e3a1 is 1.55:1), so NEITHER base
    clears 4.5:1 and a fixed table would ship an unreadable command colour.
    Repairing lightness keeps the token on-palette AND readable, which is the
    point of the gate.
    """
    if contrast(c, bg) >= MIN_CONTRAST:
        return c
    h, l, s = colorsys.rgb_to_hls(*rgb(c))
    for step in range(1, 17):
        cand = hx(colorsys.hls_to_rgb(h, l + (POLAR - l) * step / 16, s))
        if contrast(cand, bg) >= MIN_CONTRAST:
            return cand
    return max(fbs, key=lambda x: contrast(x, bg))


def guard(role, dkey, *fbs):
    """Wallpaper token for `role` if readable, else the matching catppuccin slot
    (repaired if that is unreadable too)."""
    h = tok.get(role)
    return legible(h, *fbs) if h else legible(D[dkey], *fbs)


# Semantic hue checks: GREEN must be in green/lime range (65..170)
succ = tok.get('success')
succ_h = colorsys.rgb_to_hls(*rgb(succ))[0] * 360 if succ else -1
if 65 <= succ_h <= 170:
    GREEN = guard('success', 'green', D['green'], MOCHA['green'])
else:
    GREEN = legible(D['green'], MOCHA['green'])

# YELLOW must be in yellow/amber range (35..80)
tert = tok.get('tertiary')
tert_h = colorsys.rgb_to_hls(*rgb(tert))[0] * 360 if tert else -1
if 35 <= tert_h <= 80:
    YELLOW = guard('tertiary', 'yellow', D['yellow'], MOCHA['yellow'])
else:
    YELLOW = legible(D['yellow'], MOCHA['yellow'])

BLUE = guard('primary', 'blue', D['blue'], MOCHA['blue'])
MUTED = guard('outline', 'muted', D['muted'], MOCHA['muted'],
              D['text'], MOCHA['text'])
RED = guard('error', 'red', D['red'], MOCHA['red'])
# Lifted to match wezterm/nvim, so the shell's plain-text states (separators,
# redirection) and the FZF fg are the same brightness as the terminal text.
TEXT = lift(guard('foreground', 'text', D['text'], MOCHA['text']))

# unknown-token keeps the COMPLEMENTARY hue of the wallpaper accent (hue
# +180°) so a wrong command opposes the warm accent/status colours instead of
# blending into the error red. Hue-rotating alone inherits the accent's
# lightness, which can land the complement at 1.25:1, so legible() repairs it.
# A near-gray accent has no hue to complement -> straight to catppuccin.
pr = tok.get('primary') or D['blue']
prl = list(rgb(pr))
h, l, s = colorsys.rgb_to_hls(*prl)
COMP = (legible(hx(colorsys.hls_to_rgb((h + 0.5) % 1.0, l, s)),
                D['mauve'], MOCHA['mauve'])
        if max(prl) - min(prl) >= 0.10 else legible(D['mauve'], MOCHA['mauve']))

# unknown-token fires on every partial word while typing, so it must stay
# visually distinct from the other 26 states rather than silently merging with
# one of them.
if COMP in (GREEN, BLUE, YELLOW, MUTED, RED, TEXT):
    COMP = legible(next((c for c in (D['pink'], D['teal'], D['mauve'],
                                     MOCHA['pink'], MOCHA['teal'])
                         if c not in (GREEN, BLUE, YELLOW, MUTED, RED, TEXT)),
                        D['mauve']), MOCHA['pink'], MOCHA['teal'])

# (state, color, extra attrs). `default` is deliberately absent: leaving it
# "none" keeps unstyled tokens from painting the wallpaper background.
STYLES = [
    ('command', GREEN, 'bold'), ('builtin', GREEN, ''),
    ('function', GREEN, ''), ('alias', GREEN, ''),
    ('suffix-alias', GREEN, ''), ('global-alias', GREEN, ''),
    ('hashed-command', GREEN, ''), ('assign', GREEN, ''),
    ('arg0', GREEN, ''), ('back-quoted-argument', GREEN, ''),
    ('rc-quote', GREEN, ''),
    ('autodirectory', BLUE, ''), ('path', BLUE, ''),
    ('path_prefix', BLUE, ''), ('globbing', BLUE, 'bold'),
    ('reserved-word', YELLOW, 'bold'),
    ('comment', MUTED, 'italic'),
    ('commandseparator', TEXT, ''), ('redirection', TEXT, ''),
    ('dollar-quoted-argument', TEXT, ''),
    ('cursor-matchingbracket', TEXT, 'bold'),
    ('precommand', RED, 'bold'), ('bracket-error', RED, 'bold'),
    ('history-expansion', RED, ''), ('path_approx', RED, ''),
    ('unknown-token', COMP, 'bold'),
]

# Write to a temp file and rename, never straight onto `out`. Every shell
# sources `out` at startup, so a half-written file is a live bug: `zsh -n`
# passes a truncated one (it is still syntactically valid), but sourcing it
# runs `command not found: ZSH_HIGHLIGHT_S` and silently drops every style
# from that point on. rename(2) is atomic within a filesystem, so a reader
# sees either the whole old file or the whole new one, and an interrupted run
# leaves the previous good output in place.
tmp = out + '.tmp'
# fzf rides the same WCAG-gated tokens. ~/.zshrc_custom exports the static
# FZF_DEFAULT_OPTS (layout/preview/binds) at its top and sources this file at
# its bottom, so appending --color here themes every fzf surface — Ctrl+T,
# Ctrl+R, history search, tmux's Prefix+S switcher, zi — from the wallpaper
# like the rest of the stack. No second palette writer: this is the same file
# the zsh styles come from, written by the same cascade step.
#
# Roles reuse gate-passed tokens on purpose: fg/bg are the palette's own text
# pair; muted carries the quiet surfaces (border, info, header) and the
# current-line bg; gutter/preview stay the background; the gate-repaired
# success token is the accent (hl, prompt, pointer, marker, spinner) — the
# same "commands are green" the zsh styles use, so both surfaces agree.
def legible_bg(c, fg, *fbs):
    """Return `c` if contrast(fg, c) >= MIN_CONTRAST; else shift lightness away from fg."""
    if c and contrast(fg, c) >= MIN_CONTRAST:
        return c
    target = 0.0 if rl(fg) > 0.18 else 1.0
    if c:
        h, l, s = colorsys.rgb_to_hls(*rgb(c))
        for step in range(1, 17):
            cand = hx(colorsys.hls_to_rgb(h, l + (target - l) * step / 16, s))
            if contrast(fg, cand) >= MIN_CONTRAST:
                return cand
    return max(fbs, key=lambda x: contrast(fg, x))


SEL_BG = legible_bg(tok.get('surface1') or tok.get('surface0'), TEXT, bg, '#313244', '#ccd0da')


FZF_ROLES = [
    ('fg', TEXT), ('bg', bg), ('hl', GREEN), ('fg+', TEXT), ('bg+', SEL_BG),
    ('border', MUTED), ('gutter', bg), ('info', MUTED),
    ('prompt', GREEN), ('pointer', GREEN), ('marker', GREEN),
    ('spinner', GREEN), ('header', MUTED), ('label', YELLOW),
    ('query', TEXT), ('preview-bg', bg), ('preview-border', MUTED),
]
FZF_COLOR = ','.join('%s:%s' % (k, v) for k, v in FZF_ROLES)
with open(tmp, 'w', encoding='utf-8') as f:
    f.write('# generated by zsh-highlight-sync.sh on wallpaper sync\n')
    f.write('# wallpaper bg %s; every token >= %.1f:1 (repaired in place, or catppuccin)\n'
            % (bg, MIN_CONTRAST))
    for state, col, attrs in STYLES:
        f.write('ZSH_HIGHLIGHT_STYLES[%s]="fg=%s%s"\n'
                % (state, col, (',' + attrs) if attrs else ''))
    f.write('FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --color=%s"\n' % FZF_COLOR)
os.replace(tmp, out)  # replaces the old file's inode; never leaves a gap
PY
exit 0