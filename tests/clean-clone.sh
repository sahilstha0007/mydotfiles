#!/usr/bin/env bash
# End-to-end clean-clone verification gate:
#   1. Clones the repo's HEAD into a throwaway sandbox directory
#   2. Runs install.sh twice in a fresh empty HOME (verifying idempotency)
#   3. Executes `devcheck --all` via ~/.local/bin/devcheck symlink (A1)
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/.." && pwd -P)

# Sourced via dynamically resolved $REPO_ROOT (tests/lib/sandbox.sh is in-repo).
# shellcheck disable=SC1091
source "$REPO_ROOT/tests/lib/sandbox.sh"

sandbox_init "$REPO_ROOT"

install1_out=$(sandbox_install 2>&1) || {
  printf '%s\n' "$install1_out" >&2
  exit 1
}

install2_out=$(sandbox_install 2>&1) || {
  printf '%s\n' "$install2_out" >&2
  exit 1
}

if printf '%s\n' "$install2_out" | grep -qE '^\[(LINK|INIT|BACKUP|WARN|ERR)\]'; then
  printf 'clean-clone: second install.sh run was not idempotent:\n%s\n' "$install2_out" >&2
  exit 1
fi

DEVCHECK_IN_CLEAN_CLONE=1 sandbox_run "$SB_HOME/.local/bin/devcheck" --all
