#!/usr/bin/env bash
# Reusable throwaway sandbox helper for non-destructive clone, install, and
# fault-injection testing. Never touches the live $HOME or live repo tree.
#
# Usage (source from a test script):
#   source "$REPO_ROOT/tests/lib/sandbox.sh"
#   sandbox_init [source_repo]
#   sandbox_install
#   sandbox_env ...

sandbox_cleanup() {
  if [ -n "${SB_ROOT:-}" ] && [ -d "${SB_ROOT:-}" ]; then
    chmod -R u+w "$SB_ROOT" 2>/dev/null || true
    # Headless nvim specs can leave short-lived child processes (e.g. tree-sitter cache builds)
    # finishing in SB_HOME; retry briefly if a directory is still draining.
    for _ in 1 2 3 4 5; do
      if rm -rf "$SB_ROOT" 2>/dev/null; then
        return 0
      fi
      sleep 0.2
      chmod -R u+w "$SB_ROOT" 2>/dev/null || true
    done
    rm -rf "$SB_ROOT"
  fi
}

sandbox_init() {
  local src_repo="${1:-${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)}}"
  SB_REAL_HOME="${HOME:?HOME must be set}"
  SB_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb.XXXXXX")"
  SB_HOME="$SB_ROOT/home"
  SB_REPO="$SB_ROOT/repo"
  mkdir -p "$SB_HOME"
  trap sandbox_cleanup EXIT INT TERM

  git clone --quiet "$src_repo" "$SB_REPO"

  # Preserve tool binary discovery (mise, mason, luarocks) without exposing
  # live dotfiles or ~/.zshrc.local inside SB_HOME.
  local extra_path=""
  for d in \
    "$SB_REAL_HOME/.local/share/mise/shims" \
    "$SB_REAL_HOME/.local/share/nvim/mason/bin" \
    "$SB_REAL_HOME/.luarocks/bin"; do
    if [ -d "$d" ]; then
      extra_path="${extra_path:+$extra_path:}$d"
    fi
  done
  SB_PATH="${extra_path:+$extra_path:}$PATH"
  SB_MISE_DATA_DIR="${MISE_DATA_DIR:-$SB_REAL_HOME/.local/share/mise}"
  SB_MISE_CONFIG_DIR="${MISE_CONFIG_DIR:-$SB_REAL_HOME/.config/mise}"
  SB_NVIM_LAZY_DIR="${NVIM_LAZY_DIR:-$SB_REAL_HOME/.local/share/nvim/lazy}"
}

sandbox_install() {
  env HOME="$SB_HOME" \
    PATH="$SB_PATH" \
    MISE_DATA_DIR="$SB_MISE_DATA_DIR" \
    MISE_CONFIG_DIR="$SB_MISE_CONFIG_DIR" \
    "$SB_REPO/install.sh"
}

sandbox_run() {
  env HOME="$SB_HOME" \
    PATH="$SB_PATH" \
    MISE_DATA_DIR="$SB_MISE_DATA_DIR" \
    MISE_CONFIG_DIR="$SB_MISE_CONFIG_DIR" \
    NVIM_LAZY_DIR="$SB_NVIM_LAZY_DIR" \
    "$@"
}
