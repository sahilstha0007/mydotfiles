#!/bin/sh
# Validates the STATIC terminal-stack palette design.
#
# utils/sync-wallpaper.sh used to regenerate a matugen palette from the
# wallpaper and fan out to tmux, oh-my-posh and a wezterm reload. That cascade
# is removed: the stack now uses committed static Apple Dark Glass palettes,
# and the script is kept only as a deterministic no-op so existing callers stay
# valid. This test proves:
#   1. sync-wallpaper.sh exits 0 with no args or with a wallpaper path, every
#      run, and does not fork a generator, write a file or print anything;
#   2. its source is a bare `exit 0` with no derivation logic left;
#   3. the committed static palettes are present and agree across wezterm,
#      kitty, tmux and oh-my-posh (including a real omp generator dry run).
#
# Everything runs against a throwaway HOME with generator CLI stubs on PATH,
# so a regression that reintroduces the cascade is caught without touching the
# live session.
#
# Usage: bash tests/wezterm/check_wallpaper_cascade.sh [path/to/sync-wallpaper.sh]
# The script under test is overridable so a forking copy can be run through the
# same assertions to prove the test actually catches the regression.
set -u

TESTS_WEZTERM_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$TESTS_WEZTERM_DIR/../.." && pwd)
SRC_DIR=$(CDPATH='' cd -- "$TESTS_WEZTERM_DIR/../../.config/wezterm" && pwd)
SYNC=${1:-$SRC_DIR/utils/sync-wallpaper.sh}

pass=0
fail=0
ok()  { printf '  ok    %s\n' "$1"; pass=$((pass + 1)); }
no()  { printf '  FAIL  %s\n' "$1"; fail=$((fail + 1)); }
# Invoked indirectly by expect "$@":
# shellcheck disable=SC2329
has() { case "$2" in *"$1"*) return 0;; *) return 1;; esac; }
expect() {
  _ok_msg="$1" _fail_msg="$2"; shift 2
  if "$@"; then ok "$_ok_msg"; else no "$_fail_msg"; fi
}
# Invoked indirectly by expect "$@":
# shellcheck disable=SC2329
in_both() { grep -qF "$1" "$2" 2>/dev/null && grep -qF "$1" "$3" 2>/dev/null; }

TMP=$(mktemp -d)
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT

# --- fixture HOME + fork tripwires -------------------------------------------
HOME="$TMP/home"; export HOME
XDG_RUNTIME_DIR="$TMP/runtime"; export XDG_RUNTIME_DIR
mkdir -p "$HOME" "$XDG_RUNTIME_DIR" "$TMP/bin"

# Any generator that a regressed sync-wallpaper.sh might call logs itself here.
for cmd in matugen tmux herdr wezterm kitty omp-palette.sh \
           colors-from-matugen.sh obsidian-palette.sh; do
   printf '#!/bin/sh\nprintf "%%s\\n" "%s" >> "%s/fork.log"\nexit 0\n' \
      "$cmd" "$TMP" > "$TMP/bin/$cmd"
   chmod +x "$TMP/bin/$cmd"
done
PATH="$TMP/bin:$PATH"; export PATH

# A snapshot of the whole fixture HOME: any created or modified file shows up.
snapshot() {
   (cd "$HOME" && {
      find . -type d | sort
      find . -type f -exec cksum {} + | sort
   })
}

run_sync() {
   : > "$TMP/fork.log"
   : > "$TMP/stdout"
   : > "$TMP/stderr"
   sh "$SYNC" "$@" > "$TMP/stdout" 2> "$TMP/stderr"
   RC=$?
   FORKED=$(tr '\n' ' ' < "$TMP/fork.log" | sed 's/ *$//')
}

IMG_A=$TESTS_WEZTERM_DIR/fixtures/wall-a.png
IMG_B=$TESTS_WEZTERM_DIR/fixtures/wall-b.png

# --- 1. deterministic no-op behaviour ---------------------------------------
printf '\n1. sync-wallpaper.sh exits 0 and does nothing, every run\n'
before=$(snapshot)

run_sync
expect "exit 0 with no args"                 "non-zero exit with no args: $RC" [ "$RC" -eq 0 ]
expect "silent on stdout"                    "wrote to stdout: $(cat "$TMP/stdout")" [ ! -s "$TMP/stdout" ]
expect "silent on stderr"                    "wrote to stderr: $(cat "$TMP/stderr")" [ ! -s "$TMP/stderr" ]
expect "no generator invoked"                "forked something: $FORKED" [ -z "$FORKED" ]
expect "wrote nothing to HOME"               "fixture HOME changed" [ "$(snapshot)" = "$before" ]

run_sync "$IMG_A"
expect "exit 0 with a wallpaper path"        "non-zero exit with a wallpaper: $RC" [ "$RC" -eq 0 ]
expect "still no generator invoked"          "forked something: $FORKED" [ -z "$FORKED" ]
expect "no palette file written"             "palette reappeared" [ ! -e "$HOME/.config/wezterm/colors/matugen.lua" ]
expect "no .synced marker written"           "synced marker reappeared" [ ! -e "$HOME/.cache/wezterm-wallpaper.synced" ]

run_sync "$IMG_B"
expect "exit 0 with a second wallpaper"      "non-zero exit on 2nd wallpaper: $RC" [ "$RC" -eq 0 ]
expect "2nd wallpaper forks nothing"         "2nd wallpaper forked: $FORKED" [ -z "$FORKED" ]
expect "HOME unchanged across different wallpapers" "HOME changed on 2nd wallpaper" \
   [ "$(snapshot)" = "$before" ]

run_sync "$IMG_A"
expect "exit 0 on repeat (deterministic)"    "repeat run failed: $RC" [ "$RC" -eq 0 ]
expect "repeat forks nothing"                "repeat forked: $FORKED" [ -z "$FORKED" ]

# --- 2. source is a bare no-op ------------------------------------------------
printf '\n2. no derivation logic left in sync-wallpaper.sh\n'
body=$(grep -v '^#' "$SYNC" | tr -d '[:space:]')
expect "body is just 'exit 0'"               "unexpected code: $body" [ "$body" = 'exit0' ]
expect "no cascade tokens in code"           "derivation logic is back in code" \
   [ -z "$(grep -v '^#' "$SYNC" | grep -E 'matugen|tmux|herdr')" ]

# --- 3. committed static palettes are present and consistent -----------------
printf '\n3. static palettes agree across wezterm / kitty / tmux / omp\n'
CUSTOM=$SRC_DIR/colors/custom.lua
MATUGEN=$SRC_DIR/colors/matugen.lua
KITTY=$REPO_ROOT/.config/kitty/themes/apple-glass.conf
TMUX=$REPO_ROOT/.config/tmux/colors-matugen.conf
OMP=$REPO_ROOT/.config/ohmyposh/omp-palette.sh
OMP_TPL=$REPO_ROOT/.config/ohmyposh/zen.template.toml
BG='#1c1c1e'; FG='#f5f5f7'; ACC='#2dd4bf'

for f in "$CUSTOM" "$MATUGEN" "$KITTY" "$TMUX" "$OMP" "$OMP_TPL"; do
   expect "present: ${f#"$REPO_ROOT"/}" "missing: $f" [ -f "$f" ]
done

# wezterm chrome scheme
expect "wezterm bg is $BG"   "wezterm bg drifted"   grep -qF "background = '$BG'" "$CUSTOM"
expect "wezterm fg is $FG"   "wezterm fg drifted"   grep -qF "foreground = '$FG'" "$CUSTOM"
expect "wezterm accent is $ACC (cursor)"  "wezterm cursor accent drifted" \
   grep -qF "cursor_bg = '$ACC'" "$CUSTOM"
expect "wezterm accent is $ACC (ANSI blue)"  "wezterm ANSI accent drifted" \
   grep -qF "$ACC', -- blue (accent)" "$CUSTOM"

# wezterm static token table
expect "matugen bg is $BG"   "matugen bg drifted"   grep -qF "background = \"$BG\"" "$MATUGEN"
expect "matugen fg is $FG"   "matugen fg drifted"   grep -qF "foreground = \"$FG\"" "$MATUGEN"
expect "matugen accent is $ACC"  "matugen accent drifted" \
   grep -qF "primary = \"$ACC\"" "$MATUGEN"

# kitty coding profile
expect "kitty bg is $BG"     "kitty bg drifted"     grep -qE "^background[[:space:]]+$BG" "$KITTY"
expect "kitty fg is $FG"     "kitty fg drifted"     grep -qE "^foreground[[:space:]]+$FG" "$KITTY"
expect "kitty accent is $ACC (color4)"  "kitty ANSI accent drifted" \
   grep -qE "^color4[[:space:]]+$ACC" "$KITTY"
expect "kitty accent is $ACC (cursor)"  "kitty cursor accent drifted" \
   grep -qE "^cursor[[:space:]]+$ACC" "$KITTY"

# tmux tokens
expect "tmux bg is $BG"      "tmux bg drifted"      grep -qF "@thm_bg \"$BG\"" "$TMUX"
expect "tmux fg is $FG"      "tmux fg drifted"      grep -qF "@thm_fg \"$FG\"" "$TMUX"
expect "tmux accent is $ACC"  "tmux accent drifted"  grep -qF "@thm_blue \"$ACC\"" "$TMUX"

# Every ANSI hex is shared by wezterm and kitty (both static, same 16 slots).
for h in '#3a3a3c' '#ff6b6b' '#7dce8b' '#f2d97a' '#2dd4bf' '#cba6f0' '#64d2ff' '#ebebf5' \
         '#6e6e73' '#ff8a80' '#a3e5ae' '#f7e6a3' '#5eead4' '#dcb8f5' '#9fdcf5' '#f5f5f7'; do
   expect "wezterm+kitty share ANSI $h" "ANSI $h drifted" in_both "$h" "$CUSTOM" "$KITTY"
done

# oh-my-posh: static roles + a real generator dry run into the fixture HOME.
expect "omp accent role is $ACC"  "omp accent drifted"  grep -qF "accent='$ACC'" "$OMP"
expect "omp ok role is #7dce8b"   "omp ok drifted"      grep -qF "ok='#7dce8b'" "$OMP"
expect "omp soft role is #f2d97a" "omp soft drifted"    grep -qF "soft='#f2d97a'" "$OMP"
expect "omp err role is #ff6b6b"  "omp err drifted"     grep -qF "err='#ff6b6b'" "$OMP"
expect "omp template uses static tokens" "omp template lost its tokens" \
   grep -qF '@@ACCENT@@' "$OMP_TPL"

mkdir -p "$HOME/.config/ohmyposh"
cp "$OMP_TPL" "$HOME/.config/ohmyposh/zen.template.toml"
bash "$OMP" >"$TMP/omp.out" 2>"$TMP/omp.err"
OMP_RC=$?
GEN="$HOME/.config/ohmyposh/zen.toml"
expect "omp generator exits 0"        "omp generator failed: $OMP_RC" [ "$OMP_RC" -eq 0 ]
expect "omp output uses static accent" "omp output missed $ACC" grep -qF "$ACC" "$GEN"
expect "omp output has no leftover tokens" "omp left substitution tokens behind" \
   [ -z "$(grep -E '@@(ACCENT|OK|SOFT|ERR)@@' "$GEN" 2>/dev/null)" ]

# --- result -------------------------------------------------------------------
printf '\n%s\n' "result: $pass passed, $fail failed"
[ "$fail" -eq 0 ] || exit 1
printf 'PASS  static palettes consistent; sync-wallpaper is a no-op\n\n'
exit 0
