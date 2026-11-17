#!/usr/bin/env bash
# Static-palette gate: prove the Kitty coding profile resolves its colors from
# the committed Apple Dark Glass theme, with no wallpaper-derived include.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)
KITTY_DIR="${DOTFILES_KITTY_DIR:-$REPO_ROOT/.config/kitty}"

KITTY_CONF="$KITTY_DIR/kitty.conf"
CUSTOM_CONF="$KITTY_DIR/custom.conf"
THEME="$KITTY_DIR/themes/apple-glass.conf"

for f in "$KITTY_CONF" "$CUSTOM_CONF" "$THEME"; do
  [ -f "$f" ] || { echo "FAIL: missing $f" >&2; exit 1; }
done

# kitty.conf -> custom.conf -> themes/apple-glass.conf is the only palette path.
grep -qE '^include[[:space:]].*custom\.conf' "$KITTY_CONF" || {
  echo "FAIL: kitty.conf does not include custom.conf" >&2
  exit 1
}
grep -qE '^include[[:space:]].*themes/apple-glass\.conf' "$CUSTOM_CONF" || {
  echo "FAIL: custom.conf does not include themes/apple-glass.conf" >&2
  exit 1
}

# The static design must not pull in a wallpaper-derived palette at startup.
if grep -qE '^[[:space:]]*include[[:space:]].*colors-matugen' "$KITTY_CONF" "$CUSTOM_CONF"; then
  echo "FAIL: wallpaper-derived palette include reintroduced" >&2
  exit 1
fi

# Valid color0-15 (plus base fg/bg) in the committed theme.
for key in background foreground; do
  grep -qE "^${key}[[:space:]]+#[0-9a-fA-F]{6}" "$THEME" || {
    echo "FAIL: apple-glass.conf missing/invalid $key" >&2
    exit 1
  }
done
for i in $(seq 0 15); do
  grep -qE "^color${i}[[:space:]]+#[0-9a-fA-F]{6}" "$THEME" || {
    echo "FAIL: apple-glass.conf missing/invalid color$i" >&2
    exit 1
  }
done

echo "PASS: static Apple Glass palette (color0-15 + fg/bg) resolves via kitty.conf -> custom.conf"
