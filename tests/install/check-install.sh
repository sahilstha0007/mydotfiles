#!/usr/bin/env bash
# F2 & F4: Installer idempotency, non-destructive backup, and --doctor broken-symlink/permission gate.
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)

# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/sandbox.sh"
sandbox_init

# 1. Run 1 in fresh HOME + Run 2 idempotency check
sandbox_install >/dev/null
run2=$(HOME="$SB_HOME" XDG_CONFIG_HOME="$SB_HOME/.config" XDG_CACHE_HOME="$SB_HOME/.cache" \
  XDG_STATE_HOME="$SB_HOME/.local/state" XDG_DATA_HOME="$SB_HOME/.local/share" \
  bash "$SB_REPO/install.sh" 2>&1)

if printf '%s\n' "$run2" | grep -qE '\[(LINK|INIT|BACKUP|WARM|UNLINK|REPLACE)\]'; then
  echo "FAIL F4: second run of install.sh was not idempotent:" >&2
  printf '%s\n' "$run2" >&2
  exit 1
fi
echo "  PASS  install.sh run 2 is completely idempotent"

# Verify F1 ignored-but-needed defaults were provisioned on fresh clone
if [ ! -f "$SB_REPO/.config/kitty/colors-matugen.conf" ] || [ ! -f "$SB_REPO/.config/btop/themes/matugen.theme" ]; then
  echo "FAIL F1: install.sh did not initialize colors-matugen.conf / matugen.theme" >&2
  exit 1
fi

# 2. Clean doctor pass including ignored browser Singleton*/lock runtime symlinks
mkdir -p "$SB_HOME/.config/BraveSoftware/Brave-Browser" "$SB_HOME/.config/mozilla/firefox/test.default"
ln -s "host-1234" "$SB_HOME/.config/BraveSoftware/Brave-Browser/SingletonLock"
ln -s "999999" "$SB_HOME/.config/BraveSoftware/Brave-Browser/SingletonCookie"
ln -s "/tmp/nonexistent/SingletonSocket" "$SB_HOME/.config/BraveSoftware/Brave-Browser/SingletonSocket"
ln -s "127.0.1.1:+999" "$SB_HOME/.config/mozilla/firefox/test.default/lock"

if ! HOME="$SB_HOME" bash "$SB_REPO/install.sh" --doctor --strict >/dev/null; then
  echo "FAIL F2: install.sh --doctor --strict rejected browser Singleton*/lock runtime artifacts" >&2
  exit 1
fi
echo "  PASS  install.sh --doctor ignores browser runtime lock symlinks"

# 3. Fault test: unmanaged broken symlink must warn & fail under --strict; broken repo symlink fails always
ln -s "/nonexistent/target" "$SB_HOME/.local/bin/orphan-tool"
doc_warn=$(HOME="$SB_HOME" bash "$SB_REPO/install.sh" --doctor 2>&1 || true)
if ! printf '%s\n' "$doc_warn" | grep -qi 'unmanaged.*orphan-tool'; then
  echo "FAIL F2: --doctor did not report unmanaged broken symlink" >&2
  exit 1
fi
set +e
HOME="$SB_HOME" bash "$SB_REPO/install.sh" --doctor --strict >/dev/null 2>&1
strict_rc=$?
set -e
if [ "$strict_rc" -eq 0 ]; then
  echo "FAIL F2: --doctor --strict failed to reject unmanaged broken symlink" >&2
  exit 1
fi
rm -f "$SB_HOME/.local/bin/orphan-tool"
echo "  PASS  install.sh --doctor reports unmanaged dangling links cleanly"

# Non-executable unmanaged script in ~/.local/bin must warn & fail under --strict
printf '#!/bin/sh\necho hi\n' > "$SB_HOME/.local/bin/noexec-unmanaged.sh"
set +e
HOME="$SB_HOME" bash "$SB_REPO/install.sh" --doctor --strict >/dev/null 2>&1
noexec_rc=$?
set -e
if [ "$noexec_rc" -eq 0 ]; then
  echo "FAIL F2: --doctor --strict failed to catch non-executable unmanaged script" >&2
  exit 1
fi
rm -f "$SB_HOME/.local/bin/noexec-unmanaged.sh"

# 4. No-clobber backup test on separate pre-populated sandbox HOME
H_BAK="$(dirname "$SB_HOME")/home_backup_test"
mkdir -p "$H_BAK/.config/bat" "$H_BAK/.local/bin"
printf 'REAL-ZSHRC-SENTINEL\n' > "$H_BAK/.zshrc"
printf 'REAL-BAT-SENTINEL\n' > "$H_BAK/.config/bat/sentinel.txt"
printf 'REAL-BIN-SENTINEL\n' > "$H_BAK/.local/bin/devcheck"

HOME="$H_BAK" XDG_CONFIG_HOME="$H_BAK/.config" XDG_CACHE_HOME="$H_BAK/.cache" \
  XDG_STATE_HOME="$H_BAK/.local/state" XDG_DATA_HOME="$H_BAK/.local/share" \
  bash "$SB_REPO/install.sh" >/dev/null

bak_dir=$(find "$H_BAK" -maxdepth 1 -type d -name '.config-backup-*' | head -n 1)
if [ -z "$bak_dir" ] \
  || [ "$(cat "$bak_dir/shell/zshrc" 2>/dev/null || true)" != "REAL-ZSHRC-SENTINEL" ] \
  || [ "$(cat "$bak_dir/bat/sentinel.txt" 2>/dev/null || true)" != "REAL-BAT-SENTINEL" ] \
  || [ "$(cat "$bak_dir/bin/devcheck" 2>/dev/null || true)" != "REAL-BIN-SENTINEL" ]; then
  echo "FAIL F4: install.sh clobbered pre-existing files without preserving backup in $bak_dir" >&2
  exit 1
fi
echo "  PASS  install.sh preserves pre-existing files via timestamped backup before linking"
