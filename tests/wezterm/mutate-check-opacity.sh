#!/usr/bin/env bash
# Mutation harness for wezterm's opacity control.
#
# Standing project rule: a check that passes on a mutant is worthless. This
# stages a deliberate defect in a COPY of the config and asserts that
# tests/check_opacity.lua goes red. The real ~/.config/wezterm is never
# touched, and FAKE_HOME keeps the opacity cache out of the real ~/.cache.
#
# Every mutant asserts it LANDED before running the suite. A sed that quietly
# matches nothing reports a clean 46/0, which looks exactly like success —
# that is how three mutants "passed" the first time round.
set -u

# SRC defaults to this script's own repo, not to one developer's home. The
# hardcoded /home/sahil/.config/wezterm meant the harness could only ever run on
# the machine it was written on: in CI, and for anyone else, `cp -r "$SRC"` had
# nothing to copy and every mutant reported against an empty tree.
SRC=${WEZTERM_CONFIG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.config/wezterm" && pwd -P)}
SRC=$(readlink -f "$SRC")
TEST_SCRIPT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/check_opacity.lua
W=${WEZTERM_MUTANT_DIR:-/tmp/wzmut}
FAKE=${WEZTERM_FAKE_HOME:-/tmp/opcheck_home}

# The live config is a symlink into the dotfiles repo. `cp -r "$SRC" "$W"`
# copies the LINK when SRC is a symlink, so every sed below rewrote the live
# tree and the harness ran against the file it was mutating. SRC is resolved
# with pwd -P; this guard refuses to continue if W is still a link.
stage () {
  rm -rf "$W"
  cp -r "$SRC" "$W"
  [[ ! -L "$W" && -d "$W" ]] || { echo "FATAL: $W is not a real copy of $SRC" >&2; exit 2; }
  [[ "$(readlink -f "$W")" == "$W" ]] || { echo "FATAL: $W resolves outside itself" >&2; exit 2; }
}

# Why this tracks FAILURES and exits non-zero
# -------------------------------------------
# This harness printed results and then exited 0 unconditionally: the script
# ended at the last `mutate` call with no verdict block and no `exit` anywhere
# in the file (verified: `grep -c exit` -> 0). So it reported success no matter
# what it saw — including a broken CONTROL run. A gate that cannot fail is not
# a gate.
#
# The nvim sibling (tests/mutate-terminal-colors.sh) had exactly this bug and
# was fixed the same way; this is that fix, ported.
#
# Every mutant now asserts an expected fail count, and any unmet expectation --
# control red, a mutation that didn't land, a wrong fail count -- exits 1.
FAILED=0
note_fail () { FAILED=$((FAILED + 1)); }

run () {  # runs the suite against the staged copy
  # `tail -1` alone is a lie: a mutant that makes the module fail to LOAD
  # crashes before the summary prints, and the last line is then just the last
  # FAIL (or a Lua traceback) — indistinguishable from a real result at a
  # glance, and it hid M4 for a whole run. Grep the summary; fall back to
  # naming the crash so a load error can never be misread as "caught".
  local out
  # A FRESH sandbox home per run. Reusing one leaks cache files between
  # staged copies: the cold-start check reads whatever the previous mutant
  # persisted, and a stale file makes the control fail intermittently. That is
  # not theoretical — it produced a phantom 58/2 on a correct tree.
  out=$(FAKE_HOME="$FAKE/run-$$-$(date +%s%N)" luajit "$TEST_SCRIPT" "$W" 2>&1)
  local line
  line=$(printf '%s\n' "$out" | grep -E '^RESULT: ' | tail -1)
  if [ -z "$line" ]; then
    line="!! SUITE DID NOT REPORT (crashed?) :: $(printf '%s\n' "$out" | tail -1)"
  fi
  printf '%s\n' "$line"
}

mutate () {  # name, expected_fail_count, file-relative-to-root, sed-expr...
  local name="$1" expect="$2" rel="$3"; shift 3
  stage
  local target="$W/$rel"
  "$@" "$target"
  if cmp -s "$target" "$SRC/$rel"; then
    printf '%-52s !! MUTATION DID NOT LAND\n' "$name"; note_fail; return
  fi
  local out; out="$(run)"
  printf '%-52s %s\n' "$name" "$out"
  # CRASH = the mutant must prevent the suite from summarising at all. Some
  # defects (a removed write, a syntax error) kill the run mid-way, and there is
  # no count to assert -- "no summary" IS the detection, so assert that.
  if [ "$expect" = "CRASH" ]; then
    case "$out" in
      *"DID NOT REPORT"*) ;;
      *) printf '%-52s !! EXPECTED a crash, GOT %s\n' "" "$out"; note_fail ;;
    esac
    return
  fi
  local got; got="$(printf '%s' "$out" | sed -n 's/.* \([0-9]\+\) fail.*/\1/p')"
  if [ "$got" != "$expect" ]; then
    printf '%-52s !! EXPECTED %s fail, GOT %s\n' "" "$expect" "${got:-?}"
    note_fail
  fi
}

echo "=== wezterm opacity: mutation verification ==="
rm -rf "$FAKE"; mkdir -p "$FAKE"

stage
ctl="$(run)"
printf '%-52s %s\n' "CONTROL: unmutated copy" "$ctl"
case "$ctl" in
  *" 0 fail") ;;
  *) printf '%s\n' "!! CONTROL IS RED -- the suite fails on an UNMUTATED tree," \
            "   so every mutant result below is meaningless."; note_fail ;;
esac

mutate "M1 revert the appearance.lua seed fix" 1 config/appearance.lua \
  sed -i 's/window_background_opacity = backdrops\.opacity,/window_background_opacity = 1.0,/'

mutate "M2 remove the clamp" 9 utils/backdrops.lua \
  sed -i 's/next_op = math\.max(OPACITY_MIN, math\.min(OPACITY_MAX, next_op))/next_op = next_op/'

mutate "M3 drop the 2dp rounding (float drift off the 0.05 grid)" 1 utils/backdrops.lua \
  sed -i 's/math\.floor(((self\.opacity + delta \* OPACITY_STEP) + 0\.005) \* 100) \/ 100/self.opacity + delta * OPACITY_STEP/'

# M4 removes the persist on the opacity path. Matched by TEXT, not line number:
# the original was `157s/.*/.../`, and by now line 157 sits inside the getter, so
# the mutant rewrote unrelated code and the suite died before printing a summary.
#
# This one also reports 0 in RESULT because removing the write leaves the cold-start
# check without a cache file to read, and that check halts the run. The expected
# value is therefore "no summary at all" -- assert the crash rather than a count.
mutate "M4 remove the persist call on the opacity path" CRASH utils/backdrops.lua \
  sed -i 's/^   persist(OPACITY_CACHE, next_op)$/   -- persist removed/'

mutate "M5 OPACITY_MIN 0.30 -> 0.0 (no floor)" 5 utils/backdrops.lua \
  sed -i 's/OPACITY_MIN, OPACITY_MAX = 0\.30, 1\.0/OPACITY_MIN, OPACITY_MAX = 0.0, 1.0/'

# Match the binding's own text, not a line number. The original was
# `262s/adjust_opacity(window, 1)/.../`, and inserting the panel above that line
# silently moved it: the mutant stopped landing and only the "DID NOT LAND"
# guard caught it. Keep it SIMPLE — a multiline perl pattern that over-specifies
# whitespace never matches and is indistinguishable from a mutant that was
# caught. `local o = ` is the discriminator that makes this unambiguous: the
# panel's own `adjust_opacity(window, 1)` callback has no such binding.
mutate "M6 flip the SUPER+y delta (solidify becomes fade)" 1 config/bindings.lua \
  perl -0pi -e 's/local o = backdrops:adjust_opacity\(window, 1\)/local o = backdrops:adjust_opacity(window, -1)/'

mutate "M7 merge_overrides stops carrying the opacity" 11 utils/backdrops.lua \
  sed -i 's/window_background_opacity = self\.opacity,/-- opacity dropped,/'

# --- reset() / snap() --------------------------------------------------------
# M8 drops the CLAMP in snap(). The step is invertible, so reset() targets the
# session start -- which is in range by construction -- and this only shows up
# when the target sits at a bound. Red here proves the clamp is reached at all.
mutate "M8 snap() drops the clamp" 2 utils/backdrops.lua \
  sed -i 's/local v = math\.floor((math\.max(lo, math\.min(hi, value)) + 0\.005) \* 100) \/ 100/local v = math.floor((value + 0.005) * 100) \/ 100/'

# M9 drops the 2dp ROUNDING in snap(). A session start read from a cache file
# with more precision, or any future non-2dp default, would then be written
# back unrounded -- and every exact-equality check would still pass, because
# both sides would be the same unrounded number. Only the formatting check sees
# it, which is exactly why that check exists.
mutate "M9 snap() drops the 2dp rounding" 2 utils/backdrops.lua \
  sed -i 's/local v = math\.floor((math\.max(lo, math\.min(hi, value)) + 0\.005) \* 100) \/ 100/local v = value/'

# M10 makes snap() record the value WITHOUT persisting it. The in-memory value
# is right, the cache is stale, so reset silently does not survive a restart.
# The spec's persist checks pass a nil window on purpose: with one attached, a
# repaint is what writes the override and this stays invisible.
mutate "M10 snap() skips persist (reset does not survive a restart)" 2 utils/backdrops.lua \
  sed -i 's/^   persist(cache, v)$/   -- persist removed/'

# M10b: snap() records without REPAINTING. The window override keeps the old
# value, so the screen disagrees with the cache and with the toast the panel
# prints. Distinct from M10 because only the window-override check sees it.
mutate "M10b snap() skips the repaint (window keeps the old value)" 5 utils/backdrops.lua \
  sed -i 's/^   if window ~= nil then$/   if false then/'

# M11 captures the session defaults at the WRONG time -- one step off rather
# than at construction -- so reset chases a value the user never had and the
# real session start is lost. Caught ONLY by the spec's independent cold-start
# pin; every self-referential check moves with the corruption and passes.
mutate "M11 session defaults captured one step off" 2 utils/backdrops.lua \
  sed -i 's/^   backdrops\.start_wash = backdrops\.wash$/   backdrops.start_wash = backdrops.wash + WASH_STEP/'

# M11b: same capture, for the OPACITY knob. M11 alone only proves the wash
# capture is covered; without this the opacity capture is untested and a
# regression there would pass 61/0 -- which is exactly what M11 did before the
# spec's exact-equality checks existed.
mutate "M11b opacity session defaults captured one step off" 5 utils/backdrops.lua \
  sed -i 's/^   backdrops\.start_opacity = backdrops\.opacity$/   backdrops.start_opacity = backdrops.opacity + OPACITY_STEP/'

# M13 is the historical bug itself, restored verbatim: reset() as a bounded
# "step until equal" loop, the version that could never terminate on an
# off-grid target (0.82 has no neighbours on the 0.04 grid, so the loop
# ping-ponged 0.80 <-> 0.84 to the bound). Kept because no amount of staring
# at snap() suggests that failure mode, and because it is the one mutant whose
# bug is a WRONG LANDED VALUE rather than a missing side effect.
mutate "M13 reset() as the original bounded 'step until equal' loop" 4 utils/backdrops.lua \
  sed -i "s|^   snap(self, self.start_wash, 'wash'.*$|   for _ = 1, 64 do if self.wash == self.start_wash then break end self:adjust_wash(window, self.wash < self.start_wash and 1 or -1) end|;s|^   snap(self, self.start_opacity, 'opacity'.*$|   for _ = 1, 64 do if self.opacity == self.start_opacity then break end self:adjust_opacity(window, self.opacity < self.start_opacity and 1 or -1) end|"

# --- the verdict -----------------------------------------------------------
# Without this the script ended here and exited 0 no matter what it saw. A gate
# that cannot fail is not a gate. (Ported from nvim's mutate-terminal-colors.sh,
# which had the identical bug.)
if [ "$FAILED" -ne 0 ]; then
  printf '\n%d expectation(s) UNMET -- this harness does not currently verify what\n' "$FAILED"
  printf 'it claims to. The control or a mutant result above is meaningless.\n'
  exit 1
fi
printf '\nall expectations met\n'
