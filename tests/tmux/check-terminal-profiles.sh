#!/usr/bin/env bash
set -euo pipefail

conf_dir=${TMUX_TEST_CONF_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.config/tmux" && pwd)}
scratch_root=${TMUX_TEST_TMPDIR:-$HOME/.cache/tmux-tests}
mkdir -p "$scratch_root"
work=$(mktemp -d "$scratch_root/profiles.XXXXXX")
conf="$work/tmux.conf"

cleanup() {
  TMUX_TMPDIR="$work/wezterm" tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/wezterm"
cp "$conf_dir/tmux.conf" "$conf"
sed -i "s|^run '~/.config/tmux/plugins/tpm/tpm'|run 'true'|" "$conf"

# Start WezTerm profile
env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$work/wezterm" \
  TERMINAL_STACK_PROFILE="wezterm" WEZTERM_PANE="1" \
  tmux -f "$conf" new-session -d -s "wezterm-probe"

option() {
  local name=$1
  TMUX_TMPDIR="$work/wezterm" tmux show-option -gv "$name"
}

for _ in {1..30}; do
  wezterm_blue=$(option @thm_blue 2>/dev/null || true)
  [[ -n "$wezterm_blue" ]] && break
  sleep 0.1
done

expected_wezterm_blue=$(grep '^set -g @thm_blue ' "$conf_dir/colors-matugen.conf" | tail -1 | sed -E 's/.*"(#[0-9a-fA-F]{6})".*/\1/')
[[ -n "$expected_wezterm_blue" ]] || {
  echo "FAIL: could not read @thm_blue from colors-matugen.conf" >&2
  exit 1
}

[[ "$wezterm_blue" == "$expected_wezterm_blue" ]] || {
  echo "FAIL: WezTerm tmux should use the wallpaper palette ($expected_wezterm_blue), got '$wezterm_blue'" >&2
  exit 1
}

wezterm_env=$(TMUX_TMPDIR="$work/wezterm" tmux show-environment -g TERMINAL_STACK_PROFILE)
[[ "$wezterm_env" == 'TERMINAL_STACK_PROFILE=wezterm' ]] || {
  echo "FAIL: profile environment mismatch (got '$wezterm_env')" >&2
  exit 1
}

echo "PASS: WezTerm Matugen profile verified cleanly on private tmux socket"
