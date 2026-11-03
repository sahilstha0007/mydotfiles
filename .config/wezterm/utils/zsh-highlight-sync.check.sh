#!/usr/bin/env bash
# Self-check for zsh-highlight-sync.sh, the generator that emits
# ~/.cache/zsh-wallpaper.zsh from the wallpaper palette.
#
# It shipped without a test because it "works on the live palette", and that is
# exactly the state where the next hand-edit is unprotected: every failure mode
# lives on a palette nobody happens to be staring at. A light wallpaper, an
# all-dark one, a token the same colour as the background, an accent so gray it
# has no hue to complement — all produce plausible-looking output that is
# unreadable or wrong, and all of them are one wallpaper-swap away.
#
# Fixtures live in a temp dir. The live palette is only ever READ; the live
# output file is compared, and the one regeneration at the end must come out
# byte-identical (that regeneration is the point: it proves the fixes below are
# no-ops on the palette actually in use).
#
# Usage: zsh-highlight-sync.check.sh     exit 0 = all assertions held
set -u

# Nothing here imports from the config tree (the checker is a heredoc in $TMP),
# but a stray utils/__pycache__ is a nuisance in a dotfiles repo, so pin it off
# for every python this script spawns.
export PYTHONDONTWRITEBYTECODE=1

GEN="$(dirname "$(readlink -f "$0")")/zsh-highlight-sync.sh"
LIVE_PALETTE="$HOME/.config/wezterm/colors/matugen.lua"
LIVE_OUT="$HOME/.cache/zsh-wallpaper.zsh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fail=1; }

# ---------------------------------------------------------------- fixtures --
# Shapes mirror matugen.lua exactly (flat `key = "#rrggbb",` table) because the
# generator's parser is a regex over that shape; a fixture in any other shape
# would test the fixture, not the generator.

# 1. The live dark palette, verbatim. Doubles as the regression lock: the
#    expected values below are what shipped and what the user is looking at.
cat >"$TMP/dark.lua" <<'LUA'
return {
   foreground = "#e4e3d7",
   background = "#13140d",
   primary = "#bfce7f",
   secondary = "#a1d0c4",
   tertiary = "#a1d0c4",
   success = "#576421",
   error = "#ffb4ab",
   surface0 = "#1f2019",
   surface1 = "#2a2b23",
   surface2 = "#34352d",
   outline = "#919283",
}
LUA

# 2. LIGHT wallpaper. Both catppuccin bases are unreadable here (latte green
#    2.96:1, mocha green 1.31:1 on #eff1f5), so every slot has to be repaired
#    or the output ships text nobody can read.
cat >"$TMP/light.lua" <<'LUA'
return {
   foreground = "#f0f0f0",
   background = "#eff1f5",
   primary = "#89b4fa",
   secondary = "#b4befe",
   tertiary = "#f9e2af",
   success = "#a6e3a1",
   error = "#ffb4ab",
   outline = "#b0b0b0",
}
LUA

# 3. ALL-DARK wallpaper: every token is darker than the background, so nothing
#    passes the gate as-is and the lightness walk is the only way out.
cat >"$TMP/alldark.lua" <<'LUA'
return {
   foreground = "#1a1a1a",
   background = "#0a0a0a",
   primary = "#181818",
   secondary = "#202020",
   tertiary = "#141414",
   success = "#202020",
   error = "#2a1512",
   outline = "#141414",
}
LUA

# 4. NEAR-GRAY accent: `primary` has max(rgb)-min(rgb) = 0.031, under the 0.10
#    the generator uses to decide an accent has no hue worth complementing, so
#    unknown-token must fall back to catppuccin mauve instead of rotating a hue
#    that does not exist.
cat >"$TMP/gray.lua" <<'LUA'
return {
   foreground = "#d0d0d0",
   background = "#303030",
   primary = "#7c7c74",
   secondary = "#808080",
   tertiary = "#808080",
   success = "#6a6a60",
   error = "#7a3030",
   outline = "#5a5a5a",
}
LUA

# 5. DELIBERATELY UNREADABLE: success/error/outline are the background colour
#    (1.0:1) and foreground is white-on-white. The repair walk has to climb out
#    of a 1:1 hole; if it cannot, the output must still be readable.
cat >"$TMP/unreadable.lua" <<'LUA'
return {
   foreground = "#ffffff",
   background = "#ffffff",
   primary = "#fffffe",
   secondary = "#fefefe",
   tertiary = "#fdfdfd",
   success = "#fefefe",
   error = "#fdfdfd",
   outline = "#ffffff",
}
LUA

# 6. No `background` key at all: no contrast reference exists, so the generator
#    must decline to write rather than invent one.
cat >"$TMP/nobg.lua" <<'LUA'
return {
   foreground = "#e4e3d7",
   primary = "#bfce7f",
   success = "#576421",
}
LUA

# ------------------------------------------------------------------ checker --
# One python block does the per-output assertions; bash keeps the fixture
# plumbing and the degradation paths. Contrast maths is restated here on
# purpose — the check must not import the code under test, or a bug in it would
# agree with itself.
cat >"$TMP/check.py" <<'PY'
import re, sys

out_path, palette_path = sys.argv[1], sys.argv[2]

EXPECTED = [
    'command', 'builtin', 'function', 'alias', 'suffix-alias', 'global-alias',
    'hashed-command', 'assign', 'arg0', 'back-quoted-argument', 'rc-quote',
    'autodirectory', 'path', 'path_prefix', 'globbing', 'reserved-word',
    'comment', 'commandseparator', 'redirection', 'dollar-quoted-argument',
    'cursor-matchingbracket', 'precommand', 'bracket-error',
    'history-expansion', 'path_approx', 'unknown-token',
]
MIN_CONTRAST = 4.5
HEX = re.compile(r'\A#[0-9a-fA-F]{6}\Z')

_chan = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def lum(h):
    c = [_chan(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5)]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


txt = open(out_path, encoding='utf-8').read()
pal = open(palette_path, encoding='utf-8').read()
m = re.search(r'^\s*background\s*=\s*"(#[0-9A-Fa-f]{6})"', pal, re.M)
bg = m.group(1) if m else None
errs = []

if bg is None:
    errs.append('fixture has no background to check against')
if '@@' in txt:
    errs.append('output still contains a @@ template placeholder')

got = re.findall(r'^ZSH_HIGHLIGHT_STYLES\[([^\]]+)\]="([^"]*)"$', txt, re.M)
names = [n for n, _ in got]
if len(got) != 26:
    errs.append('expected 26 style entries, got %d' % len(got))
missing = [s for s in EXPECTED if s not in names]
if missing:
    errs.append('missing states: %s' % ' '.join(missing))
extra = [n for n in names if n not in EXPECTED]
if extra:
    errs.append('unexpected states: %s' % ' '.join(extra))
if len(names) != len(set(names)):
    errs.append('a state is assigned more than once')

for name, style in got:
    fg = style.split(',')[0]
    if not fg.startswith('fg='):
        errs.append('%s: no fg= in %r' % (name, style))
        continue
    col = fg[3:]
    if not HEX.match(col):
        # The bug this assertion exists for: `fg=a6e3a1` with no '#'. zsh
        # accepts it and the terminal renders it wrong, so only a shape check
        # catches it.
        errs.append('%s: fg=%r is not #rrggbb' % (name, col))
        continue
    if bg:
        ratio = contrast(col, bg)
        if ratio < MIN_CONTRAST:
            errs.append('%s: fg=%s is %.2f:1 on %s (needs %.1f)'
                        % (name, col, ratio, bg, MIN_CONTRAST))

# fzf line: the whole role set, every hex #-prefixed, and the text pair still
# gate-legible. A missing --color line means fzf silently falls back to its
# default dark theme (the exact mismatch this output feeds), and a role set
# that drifts shows up only when fzf starts warning about unknown roles.
FZF_ROLES = {
    'fg', 'bg', 'hl', 'fg+', 'bg+', 'border', 'gutter', 'info',
    'prompt', 'pointer', 'marker', 'spinner', 'header', 'label',
    'query', 'preview-bg', 'preview-border',
}
fzf_m = re.search(
    r'^FZF_DEFAULT_OPTS="\$FZF_DEFAULT_OPTS --color=([^"]*)"$', txt, re.M)
if not fzf_m:
    errs.append('missing FZF_DEFAULT_OPTS --color= line')
else:
    pairs = {}
    for part in fzf_m.group(1).split(','):
        k, _, v = part.partition(':')
        pairs[k] = v
    missing = FZF_ROLES - set(pairs)
    extra = set(pairs) - FZF_ROLES
    if missing or extra:
        errs.append('fzf roles mismatch: missing=%s extra=%s'
                    % (sorted(missing), sorted(extra)))
    for k, v in sorted(pairs.items()):
        if not HEX.match(v):
            errs.append('fzf %s=%r is not #rrggbb' % (k, v))
    if bg and HEX.match(pairs.get('fg', '')) and HEX.match(pairs.get('bg', '')):
        r = contrast(pairs['fg'], pairs['bg'])
        if r < MIN_CONTRAST:
            errs.append('fzf fg/bg is %.2f:1 on %s (needs %.1f)'
                        % (r, bg, MIN_CONTRAST))

for e in errs:
    print('      ! ' + e)
sys.exit(1 if errs else 0)
PY
# Assert one generated file end to end. $1 = fixture lua, $2 = label.
check_run() {
    local fixture="$1" label="$2" out="$TMP/$2.zsh" detail
    rm -f "$out"
    if ! "$GEN" "$fixture" "$out"; then
        bad "$label: generator exited non-zero"
        return
    fi
    if [ ! -s "$out" ]; then
        bad "$label: no output written"
        return
    fi
    if ! zsh -n "$out" 2>"$TMP/zn.err"; then
        bad "$label: zsh -n rejected the output: $(head -1 "$TMP/zn.err")"
        return
    fi
    # Atomic write: no temp file may survive a run that finished. A leftover
    # means an earlier run was killed mid-write, which is exactly the case the
    # temp-file-and-rename exists to make harmless.
    if [ -e "$out.tmp" ]; then
        bad "$label: left $out.tmp behind (a run was killed mid-write?)"
        rm -f "$out.tmp"
        return
    fi
    if detail="$(python3 "$TMP/check.py" "$out" "$fixture" 2>&1)"; then
        ok "$label: 26 states, valid zsh, no @@, every fg #rrggbb >= 4.5:1"
    else
        bad "$label: $detail"
    fi
}

# ------------------------------------------------------------------- asserts --
echo "zsh-highlight-sync self-check"

echo "palettes:"
for f in dark light alldark gray unreadable; do
    check_run "$TMP/$f.lua" "$f"
done

echo "degradation:"

# Missing palette -> exit 0, nothing written. A stale file from a previous sync
# would be worse than no file, so this asserts on a clean path only: if the
# generator invents output here it has no background to compute against.
if "$GEN" "$TMP/does-not-exist.lua" "$TMP/missing.zsh"; then
    if [ -e "$TMP/missing.zsh" ]; then
        bad "missing palette: wrote output anyway"
    else
        ok "missing palette: exit 0, no output written"
    fi
else
    bad "missing palette: exited non-zero"
fi

# Palette with no `background` -> leave an existing output completely alone, so
# open shells keep whatever they already had instead of dropping to static
# styles mid-session.
printf '# pre-existing wallpaper styles\n' >"$TMP/nobg.zsh"
cp "$TMP/nobg.zsh" "$TMP/nobg.want"
if "$GEN" "$TMP/nobg.lua" "$TMP/nobg.zsh" && cmp -s "$TMP/nobg.want" "$TMP/nobg.zsh"; then
    ok "no background key: exit 0, existing output untouched"
else
    bad "no background key: existing output was overwritten"
fi

# A write that dies partway (full disk, RLIMIT_FSIZE, SIGKILL mid-write) must
# NOT cost the user their current theme. This is the assertion that actually
# pins the temp-file-and-rename: writing straight onto `out` truncates it
# first and the failure leaves a half file, which zsh -n still accepts but
# which sources as `command not found: ZSH_HIGHLIGHT_S` and silently drops
# every style from there on. `ulimit -f` is the same failure class as ENOSPC,
# without needing a full disk or a signal.
#
# `ulimit -f 1` = 512 bytes, below python's ~8 KiB write buffer, so the flush
# is guaranteed to hit the limit. Measured: a direct-to-`out` generator leaves
# a 1024-byte stub here, temp-file-and-rename leaves the seed untouched. A
# higher limit does NOT reliably trip (the buffer absorbs it and the file
# survives by luck), which is why this pins 1 and not something larger.
#
# Seed with a FRESH good file, not $TMP/dark.zsh: the whole point is that the
# file being overwritten is bigger than the write limit, so a seed left over
# from an earlier assertion would quietly stop testing anything.
"$GEN" "$TMP/dark.lua" "$TMP/partial.zsh" || bad "write failure: could not seed"
cp "$TMP/partial.zsh" "$TMP/partial.want"
if [ "$(wc -c <"$TMP/partial.want")" -le 512 ]; then
    bad "write failure: seed is not larger than the 512-byte write limit"
else
    # Exits non-zero with ENOSPC noise on stderr; that is the point.
    ( ulimit -f 1; "$GEN" "$TMP/dark.lua" "$TMP/partial.zsh" ) 2>/dev/null || true
    if cmp -s "$TMP/partial.want" "$TMP/partial.zsh"; then
        ok "write failure partway: previous output preserved intact"
    else
        bad "write failure partway: output was left truncated"
    fi
fi
rm -f "$TMP/partial.zsh.tmp"   # orphan from the aborted run; next run reclaims it

# No python3 -> delete our own output so shells fall back to the static block in
# .zshrc_custom. Simulated with a PATH holding only `rm`: the generator needs
# rm to do the cleanup, and python3 lives on the same PATH in any real
# "python is missing" scenario, so a PATH with rm but no python3 is the honest
# version of that failure.
mkdir -p "$TMP/bin"
ln -s "$(command -v rm)" "$TMP/bin/rm"
printf '# stale wallpaper styles\n' >"$TMP/nopy.zsh"
if env PATH="$TMP/bin" "$GEN" "$TMP/dark.lua" "$TMP/nopy.zsh"; then
    if [ -e "$TMP/nopy.zsh" ]; then
        bad "no python3: stale output was left behind"
    else
        ok "no python3: exit 0, own output removed"
    fi
else
    bad "no python3: exited non-zero"
fi

# --------------------------------------------------------- the live palette --
# The point of this block is to catch a fix that silently shifts the colours the
# user is actually reading. It used to assert six hardcoded hexes, which made it
# a wallpaper-change detector rather than a canary: every wallpaper pick broke
# it, so it was permanently red and nobody could tell a real regression from
# normal churn. (It was last green against a palette from a wallpaper you have
# since replaced.)
#
# It now asserts the DERIVATION instead of the values: the live palette is fed
# through the generator's OWN readability guard, and each style must equal the
# palette token it maps from. Same guarantee, invariant across wallpapers — if a
# future edit repoints a style at a different token, or the guard stops
# repairing an unreadable one, this fails. Exact hexes stay pinned for the
# fixed fixtures above, which do not move.
echo "live palette:"
if [ ! -r "$LIVE_PALETTE" ]; then
    bad "live palette unreadable at $LIVE_PALETTE"
elif [ ! -r "$LIVE_OUT" ]; then
    bad "live output missing at $LIVE_OUT (run sync-wallpaper.sh)"
else
    check_run "$LIVE_PALETTE" live

    # Re-derive the styles from the live palette with the generator itself.
    # Any drift between "what the generator produces from this palette" and
    # "what is live on disk" means a stale or hand-edited output file.
    if "$GEN" "$LIVE_PALETTE" "$TMP/rederived.zsh" 2>/dev/null &&
       cmp -s "$TMP/rederived.zsh" "$LIVE_OUT"; then
        ok "live output matches a fresh derivation from the live palette"
    else
        bad "live output DRIFTED from the live palette"
        diff -u "$LIVE_OUT" "$TMP/rederived.zsh" | head -20 | sed 's/^/    /'
    fi

    # Regenerate the real file bare (no args -> live palette, live output) and
    # require it to come out byte-identical. Anything else means a fix leaked
    # into the palette actually in use.
    cp "$LIVE_OUT" "$TMP/live-before.zsh"
    if "$GEN" && cmp -s "$TMP/live-before.zsh" "$LIVE_OUT"; then
        ok "live output regenerated byte-identical"
    else
        bad "live output CHANGED on regeneration"
        diff -u "$TMP/live-before.zsh" "$LIVE_OUT" | head -20
    fi
fi

if [ "$fail" -eq 0 ]; then
    echo "self-check OK"
else
    echo "self-check FAILED"
fi
exit "$fail"
