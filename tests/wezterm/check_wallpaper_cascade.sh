#!/bin/sh
# Proves the wallpaper -> palette cascade re-themes, end to end.
#
# Runs the REAL utils/sync-wallpaper.sh against a throwaway HOME, so nothing
# live is touched: the test never writes ~/.config/wezterm/colors/matugen.lua
# and never invokes the real matugen output path. `tmux` and `herdr` are
# stubbed onto PATH ahead of the real binaries precisely so this cannot reach
# the live session.
#
# The assertions that matter:
#   1. a different wallpaper rewrites the palette, runs every generator, and
#      touches wezterm.lua (which is what makes wezterm reload and re-theme);
#   2. re-picking the SAME wallpaper is a cheap no-op (the guards are load
#      bearing for latency, so this pins that they did not become useless);
#   3. a palette that failed to generate is NOT recorded as synced, so the next
#      pick retries it instead of no-oping forever -- including matugen's
#      exit-0-but-writes-nothing case;
#   4. an ABSENT palette does not hash-equal a regenerated one, so the reload
#      is not skipped while the palette is rebuilt from nothing.
#
# Usage: sh ~/.config/wezterm/tests/check_wallpaper_cascade.sh [path/to/sync-wallpaper.sh]
# The script under test is overridable so a pre-fix copy can be run through the
# same assertions to prove the test actually catches the regression.
set -u

REAL_HOME=${HOME:?HOME must be set}
SRC_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../.config/wezterm" && pwd)
SYNC=${1:-$SRC_DIR/utils/sync-wallpaper.sh}
TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

pass=0
fail=0
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
no()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
has() { case "$2" in *"$1"*) return 0;; *) return 1;; esac; }

# --- fixture HOME -------------------------------------------------------------
HOME="$TMP"; export HOME
H="$TMP/.config"
CACHE="$TMP/.cache"
PAL="$H/wezterm/colors/matugen.lua"
mkdir -p "$H/wezterm/colors" "$H/matugen" "$H/tmux" "$H/ohmyposh" \
         "$H/herdr" "$H/opencode" "$H/wezterm/utils" "$TMP/bin" "$CACHE"

cp "$REAL_HOME/.config/matugen/templates/wezterm-colors.lua" "$H/wezterm-colors.lua"
cat > "$H/matugen/wezterm.toml" <<EOF
[config]

[templates.wezterm]
input_path = '$H/wezterm-colors.lua'
output_path = '$PAL'
EOF

echo sentinel > "$H/wezterm/wezterm.lua"
echo stale   > "$H/tmux/colors-matugen.conf"

# Generators: record that they ran AND rewrite their own artifact, so the
# fan-out is asserted by what it produced, not only by what it logged.
i=0
for gen in tmux/colors-from-matugen.sh ohmyposh/omp-palette.sh \
           wezterm/utils/zsh-highlight-sync.sh herdr/herdr-palette.sh \
           opencode/opencode-palette.sh wezterm/utils/obsidian-palette.sh; do
   i=$((i + 1))
   cat > "$H/$gen" <<EOF
#!/bin/sh
printf '%s\n' "$gen" >> "$TMP/cascade.log"
printf 'gen-%s\n' "$i" > "$H/\$(printf '%s' "$gen" | tr / _)"
EOF
   chmod +x "$H/$gen"
done

# tmux/herdr CLI stubs: prove the live-reload cascade ran, with no live session.
for c in tmux herdr; do
   printf '#!/bin/sh\nprintf "%s %%s\\n" "$*" >> "%s/cascade.log"\nexit 0\n' \
      "$c" "$TMP" > "$TMP/bin/$c"
   chmod +x "$TMP/bin/$c"
done
PATH="$TMP/bin:$PATH"; export PATH

# Read a file's hash without exploding when it is absent -- the whole point of
# case 4 is that "absent" and "present" must not compare equal.
h() { [ -f "$1" ] && cksum < "$1" || echo absent; }

# Run the script and report what it did.
run() {
   : > "$TMP/cascade.log"
   touch -d '2000-01-01' "$H/wezterm/wezterm.lua"   # sentinel epoch
   sh "$SYNC" "$1" >"$TMP/stdout" 2>"$TMP/stderr"
   rc=$?
   reloaded=no
   [ "$(date -r "$H/wezterm/wezterm.lua" '+%Y')" = 2000 ] || reloaded=yes
   ran=$(tr '\n' ' ' < "$TMP/cascade.log" | sed 's/ *$//')
}

IMG_A=${WEZCASCADE_IMAGE_A:-$REAL_HOME/Pictures/wallpaper/background1.png}
IMG_B=${WEZCASCADE_IMAGE_B:-$REAL_HOME/Pictures/wallpaper/wallhaven-6llxkw_1920x1080.jpg}

if [ ! -f "$IMG_A" ]; then
   printf 'fixture image missing: %s (set WEZCASCADE_IMAGE_A)\n\n' "$IMG_A" >&2
   exit 2
fi

# --- 1. a real wallpaper change re-themes -------------------------------------
printf '\n1. first wallpaper: palette written, cascade runs, wezterm reloads\n'
run "$IMG_A"
[ "$rc" -eq 0 ]                   && ok "exit 0"              || no "exit $rc"
[ -s "$PAL" ]                     && ok "palette written"     || no "no palette on disk"
grep -q 'background = "#' "$PAL" 2>/dev/null && ok "palette is real" || no "palette malformed"
[ "$reloaded" = yes ]             && ok "wezterm.lua touched -> reload" || no "wezterm.lua NOT touched"
has colors-from-matugen "$ran"    && ok "tmux generator ran"  || no "tmux generator skipped"
has omp-palette "$ran"            && ok "oh-my-posh ran"     || no "oh-my-posh skipped"
has zsh-highlight-sync "$ran"     && ok "zsh-highlight ran"  || no "zsh-highlight skipped"
has herdr-palette "$ran"          && ok "herdr ran"          || no "herdr skipped"
has opencode-palette "$ran"       && ok "opencode ran"       || no "opencode skipped"
has obsidian-palette "$ran"       && ok "obsidian ran"       || no "obsidian skipped"
has "source-file" "$ran"          && ok "tmux source-file"   || no "no tmux source-file"
[ "$(cat "$CACHE/wezterm-wallpaper.synced" 2>/dev/null)" = "$IMG_A" ] \
   && ok "recorded as synced"     || no "synced not written"

# --- 2. same wallpaper again: cheap no-op -------------------------------------
printf '\n2. same wallpaper again: no matugen, no reload, instant\n'
before=$(h "$PAL")
run "$IMG_A"
[ "$rc" -eq 0 ]        && ok "exit 0"            || no "exit $rc"
[ "$reloaded" = no ]   && ok "no needless reload" || no "reloaded anyway"
[ -z "$ran" ]          && ok "no work done"       || no "cascade ran again: $ran"
[ "$(h "$PAL")" = "$before" ] && ok "palette untouched" || no "palette churned"

# --- 3. failure must be loud AND retryable ------------------------------------
printf '\n3a. matugen exits non-zero: loud, and not recorded as synced\n'
cp "$H/matugen/wezterm.toml" "$TMP/good.toml"
sed "s#input_path = .*#input_path = '$TMP/nope.lua'#" "$TMP/good.toml" \
   > "$H/matugen/wezterm.toml"
rm -f "$CACHE/wezterm-wallpaper.synced"
run "$IMG_A"
[ "$rc" -ne 0 ]  && ok "non-zero exit (not silent success)" \
                 || no "failed silently (rc 0)"
grep -q . "$TMP/stderr" && ok "explained on stderr" || no "no diagnostic emitted"
[ "$(cat "$CACHE/wezterm-wallpaper.synced" 2>/dev/null)" != "$IMG_A" ] \
   && ok "NOT marked synced (retry possible)" \
   || no "marked synced despite failure -> permanently stuck"

printf '\n3b. matugen exits 0 but writes NOTHING (read-only palette file)\n'
cp "$TMP/good.toml" "$H/matugen/wezterm.toml"
# Poison the palette first, so the recovery in 3c is a REAL change and the
# reload it triggers is observable. Without this the retry would regenerate
# byte-identical colours and correctly skip the reload, which proves nothing.
printf -- '-- POISONED, not a real palette\nreturn { background = "#000000" }\n' > "$PAL"
before=$(h "$PAL")
chmod a-w "$PAL"      # the FILE, not the dir: matugen exits 0 and skips the write
rm -f "$CACHE/wezterm-wallpaper.synced"
run "$IMG_A"
chmod u+w "$PAL"
[ "$rc" -ne 0 ]  && ok "caught the rc-0 silent failure" \
                 || no "silent success: nothing written but rc 0"
grep -q . "$TMP/stderr" && ok "explained on stderr" || no "no diagnostic emitted"
[ "$(h "$PAL")" = "$before" ] && ok "stale palette left alone" \
                             || no "palette changed unexpectedly"
grep -q POISONED "$PAL" 2>/dev/null && ok "poison still in place (nothing written)" \
                                 || no "poison overwritten"
[ "$(cat "$CACHE/wezterm-wallpaper.synced" 2>/dev/null)" != "$IMG_A" ] \
   && ok "NOT marked synced (retry possible)" \
   || no "marked synced despite writing nothing -> permanently stuck"

printf '\n3c. same image retried after the fault is fixed: it re-themes\n'
run "$IMG_A"
[ -s "$PAL" ]         && ok "retry wrote the palette"    || no "retry never regenerated"
grep -q POISONED "$PAL" 2>/dev/null && no "poison survived" || ok "poison overwritten"
[ "$reloaded" = yes ] && ok "retry reloaded wezterm"      || no "retry did not reload"
[ "$(cat "$CACHE/wezterm-wallpaper.synced" 2>/dev/null)" = "$IMG_A" ] \
   && ok "retry recorded as synced" || no "retry did not record"

# --- 4. an ABSENT palette must not read as "already synced" -------------------
printf '\n4. palette deleted but .synced names this image: must still rebuild\n'
run "$IMG_A"                       # establish a good palette + .synced
rm -f "$PAL"                       # palette destroyed; .synced still names IMG_A
run "$IMG_A"
[ -s "$PAL" ]         && ok "palette rebuilt from absent" \
                       || no "BUG: .synced matched, matugen never re-ran, theme dead"
[ "$reloaded" = yes ] && ok "reload NOT skipped"           || no "reload skipped"

printf '\n4b. .synced present, palette absent, gui-startup must re-sync too\n'
# events/gui-startup.lua gates on image ~= synced only; a missing palette left
# it silent forever. Assert the seam: same condition, plus palette presence.
if grep -q 'has_palette' "$SRC_DIR/events/gui-startup.lua" 2>/dev/null; then
   ok "gui-startup checks palette presence, not just the image"
else
   no "gui-startup still trusts .synced alone -> dead theme survives restart"
fi

# --- 5. two different wallpapers -> two different palettes --------------------
printf '\n5. two different wallpapers -> two different palettes\n'
if [ -f "$IMG_B" ]; then
   run "$IMG_A"; a=$(h "$PAL")
   run "$IMG_B"; b=$(h "$PAL")
   [ -s "$PAL" ]   && ok "palette exists after 2nd run" || no "2nd run wrote no palette"
   [ "$a" != "$b" ] && ok "palette differs per wallpaper" || no "one palette for both"
   [ "$reloaded" = yes ] && ok "second wallpaper reloaded" || no "second wallpaper did not reload"
   [ "$(cat "$CACHE/wezterm-wallpaper.synced" 2>/dev/null)" = "$IMG_B" ] \
      && ok "synced tracks newest" || no "synced wrong"
else
   printf '  skip  needs a 2nd image (set WEZCASCADE_IMAGE_B)\n'
fi

# --- result -------------------------------------------------------------------
printf '\n%s\n' "result: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
printf 'PASS  cascade re-themes end to end\n\n'
exit 0
