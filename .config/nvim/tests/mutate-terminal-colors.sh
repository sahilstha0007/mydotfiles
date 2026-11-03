#!/usr/bin/env bash
# Mutation harness for the WCAG contrast gate in terminal-colors.lua.
#
# Standing project rule: a check that passes on a mutant is worthless. This
# stages a deliberate defect in a COPY of the config and asserts that
# tests/terminal_colors_spec.lua goes red. The real ~/.config/nvim is never
# touched.
#
# Why the copy has to be relocatable
# -----------------------------------
# This suite existed and was worthless for one whole round: 33 checks, all
# green, on a config with the gamma exponent changed from 2.4 to 2.2 and
# MIN_CONTRAST lowered from 4.5 to 3.0. Two hardcoded absolute paths had to
# be the culprit, not one:
#
#   * terminal_colors_spec.lua named the source file absolutely, so it read
#     the LIVE file no matter which tree it ran in;
#   * tests/minimal_init.lua prepended the LIVE tree to the runtimepath, so
#     the config_root() lookup in the spec resolved back to live.
#
# Both now derive from the tree's own location. tests/minimal_init.lua also
# honours NVIM_CONFIG_ROOT, so a spec can be pointed at any tree.
#
# Every mutant asserts it LANDED before running the suite. A sed that quietly
# matches nothing reports a clean 33/0, which is indistinguishable from
# success — that is how three of the first mutants "passed".
set -u

# Why this tracks FAILURES and exits non-zero
# -------------------------------------------
# This harness printed results and then exited 0 unconditionally, so it could
# report a completely broken control run ("CONTROL: 34 pass, 6 fail" plus two
# "MUTATION DID NOT LAND" lines) and still tell make it succeeded. That is the
# precise failure this file exists to catch, reproduced inside the catcher.
#
# So every line asserts. A gate that cannot fail is not a gate.
FAILED=0
note_fail () { FAILED=$((FAILED + 1)); }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
W=/tmp/nvim-mut
FILE=lua/plugins/ui/terminal-colors.lua

run () {  # runs the spec inside the staged copy, via the copy's own init
  ( cd "$W" && nvim --headless -u tests/minimal_init.lua \
      -c "lua dofile('tests/terminal_colors_spec.lua')" -c "qa!" 2>&1 | tail -1 )
}

mutate () {  # name, expected_fail_count, sed-expr (applied to $W/$FILE)
  local name="$1"; local expect="$2"; shift 2
  rm -rf "$W"; cp -r "$SRC" "$W"
  local target="$W/$FILE"
  "$@" "$target"
  if cmp -s "$target" "$SRC/$FILE"; then
    printf '%-56s !! MUTATION DID NOT LAND\n' "$name"; note_fail; return
  fi
  local out; out="$(run)"
  printf '%-56s %s\n' "$name" "$out"
  local got; got="$(printf '%s' "$out" | sed -n 's/.* \([0-9]\+\) fail$/\1/p')"
  if [ "$got" != "$expect" ]; then
    printf '%-56s !! EXPECTED %s fail, GOT %s\n' "" "$expect" "${got:-?}"
    note_fail
  fi
}

echo "=== nvim contrast gate: mutation verification ==="

rm -rf "$W"; cp -r "$SRC" "$W"
ctl="$(run)"
printf '%-56s %s\n' "CONTROL: unmutated copy" "$ctl"
case "$ctl" in
  *" 0 fail") ;;
  *) printf '%s\n' "!! CONTROL IS RED -- the suite fails on an UNMUTATED tree," \
            "   so every mutant result below is meaningless."; note_fail ;;
esac

# --- the two that were originally staged, kept as the regression guard ------
mutate "M1 gamma 2.4 -> 2.2" 6 \
  sed -i 's/\^ 2\.4$/\^ 2.2/'
mutate "M2 MIN_CONTRAST 4.5 -> 3.0" 4 \
  sed -i 's/^local MIN_CONTRAST = 4\.5 -- WCAG AA for normal text$/local MIN_CONTRAST = 3.0 -- WCAG AA for normal text/'

# --- the arithmetic ---------------------------------------------------------
mutate "M3 MIN_CONTRAST 4.5 -> 4.0 (still under AA, must not slip through)" 3 \
  sed -i 's/^local MIN_CONTRAST = 4\.5 -- WCAG AA for normal text$/local MIN_CONTRAST = 4.0 -- WCAG AA for normal text/'
mutate "M4 rel_lum green coefficient 0.7152 -> 0.5" 8 \
  sed -i 's/0\.7152/0.5/'
mutate "M5 rel_lum drops the blue term" 8 \
  sed -i 's/0\.2126 \* channel(r) + 0\.7152 \* channel(g) + 0\.0722 \* channel(b)/0.2126 * channel(r) + 0.7152 * channel(g)/'
mutate "M6 contrast() made asymmetric (drops the hi/lo swap)" 7 \
  sed -i 's/local hi, lo = la > lb and la or lb, la < lb and la or lb/local hi, lo = la, lb/'
mutate "M7 drop the +0.05 fudge from the ratio" 11 \
  sed -i 's/return (hi + 0\.05) \/ (lo + 0\.05)/return hi \/ lo/'
mutate "M8 swap the red and green coefficients" 5 \
  sed -i 's/0\.2126 \* channel(r) + 0\.7152 \* channel(g)/0.7152 * channel(r) + 0.2126 * channel(g)/'

# --- an equivalent mutant, deliberately NOT caught --------------------------
# 0.04045 is the WCAG-specified low-luminance breakpoint. 0.04 is the sRGB
# spec's value; the two differ only for channels 10.2/255, which no 8-bit
# hex can express, so no #rrggbb input can tell them apart. 33/0 here is
# correct behaviour, not a hole — recorded so nobody re-adds it as a bug.
mutate "M9 breakpoint 0.04045 -> 0.04 (EQUIVALENT, expect 0 fail)" 0 \
  sed -i 's/<= 0\.04045/<= 0.04/'

rm -rf "$W"

if [ "$FAILED" -ne 0 ]; then
  printf '\n!! %s mutation expectation(s) NOT met -- the spec is no longer catching\n' "$FAILED"
  printf '   what it claims to catch. Treat the gate above as BROKEN, not green.\n'
  exit 1
fi
printf '\nall mutants behaved as expected\n'
