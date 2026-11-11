#!/usr/bin/env bash
# Defect 1 gate: validate kitty colors-matugen includes against Kitty's real parser
# (committed default + live generated + validated include) and prove fault injection
# goes RED on CSS comments / unrecognized directives and GREEN after sanitization.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)
SANITIZER="$REPO_ROOT/bin/kitty-colors-sanitize"
KITTY_DIR="${DOTFILES_KITTY_DIR:-$REPO_ROOT/.config/kitty}"

[ -x "$SANITIZER" ] || {
  echo "FAIL: missing executable $SANITIZER" >&2
  exit 1
}

# 1. Committed default theme + live generated + validated include must all pass cleanly
"$SANITIZER" --check --in "$KITTY_DIR/themes/nightfox.conf"
if [ -f "$KITTY_DIR/colors-matugen.conf" ]; then
  "$SANITIZER" --check --in "$KITTY_DIR/colors-matugen.conf"
fi
if [ -f "$KITTY_DIR/colors-matugen.validated.conf" ]; then
  "$SANITIZER" --check --in "$KITTY_DIR/colors-matugen.validated.conf"
else
  echo "FAIL: missing validated include $KITTY_DIR/colors-matugen.validated.conf (run kitty-colors-sanitize or install.sh)" >&2
  exit 1
fi

# 2. Fault injection in throwaway sandbox dir (never touches live files)
work=$(mktemp -d "${TMPDIR:-/tmp}/kitty-sanitize-test.XXXXXX")
trap 'rm -rf "$work"' EXIT

expect_red() {
  local label="$1" path="$2"
  if "$SANITIZER" --check --in "$path" >/dev/null 2>&1; then
    echo "FAIL [$label]: gate stayed GREEN on invalid input ($path)" >&2
    exit 1
  fi
}

# Fault A: ML4W CSS comment
printf '/* color4 #fff */\ncolor5 #112233\n' >"$work/fault_css.conf"
expect_red "css /* */ comment" "$work/fault_css.conf"

# Fault B: C++ // comment
printf '// color4 #fff\ncolor5 #112233\n' >"$work/fault_slash.conf"
expect_red "c++ // comment" "$work/fault_slash.conf"

# Fault C: Unrecognized non-comment directive
printf 'nonexistent_kitty_key 42\ncolor5 #112233\n' >"$work/fault_key.conf"
expect_red "unknown directive" "$work/fault_key.conf"

# Fault D: Bad color value
printf 'color4 notacolor\ncolor5 #112233\n' >"$work/fault_val.conf"
expect_red "bad color value" "$work/fault_val.conf"

# Fault E -> GREEN: Combined bad file sanitized & promoted cleanly
cat >"$work/combined_bad.conf" <<'EOF'
/* color4 #fff */
// inline slash comment
/* multi
   line block */
nonexistent_kitty_key 42
color4 notacolor
color5 #112233
color4 #89b4fa
EOF
expect_red "combined pre-sanitize" "$work/combined_bad.conf"

"$SANITIZER" --sync-in --in "$work/combined_bad.conf" --out "$work/combined_valid.conf" >/dev/null 2>&1
"$SANITIZER" --check --in "$work/combined_bad.conf" >/dev/null
"$SANITIZER" --check --in "$work/combined_valid.conf" >/dev/null

grep -q '^# color4 #fff$' "$work/combined_valid.conf" || {
  echo "FAIL: /* ... */ was not converted to # ..." >&2
  exit 1
}
grep -q '^# inline slash comment$' "$work/combined_valid.conf" || {
  echo "FAIL: // ... was not converted to # ..." >&2
  exit 1
}
if grep -qE 'nonexistent_kitty_key|notacolor' "$work/combined_valid.conf"; then
  echo "FAIL: invalid directives were not dropped" >&2
  exit 1
fi

# 3. Failed regeneration must NEVER overwrite a known-good validated file
sentinel="# KNOWN_GOOD_SENTINEL
color1 #abcdef
"
printf '%s' "$sentinel" >"$work/protected.conf"
printf 'only_unknown_garbage 999\n' >"$work/all_garbage.conf"

if "$SANITIZER" --in "$work/all_garbage.conf" --out "$work/protected.conf" >/dev/null 2>&1; then
  echo "FAIL: all-garbage input promoted over protected file" >&2
  exit 1
fi
if "$SANITIZER" --simulate-bad-stage --in "$work/combined_valid.conf" --out "$work/protected.conf" >/dev/null 2>&1; then
  echo "FAIL: --simulate-bad-stage promoted over protected file" >&2
  exit 1
fi
if [ "$(cat "$work/protected.conf")" != "$(printf '%s' "$sentinel")" ]; then
  echo "FAIL: protected validated file was mutated after failed promotion" >&2
  exit 1
fi

echo "PASS: kitty colors sanitize checks, fault injections, and staging guard OK"
