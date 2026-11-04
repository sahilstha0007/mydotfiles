#!/usr/bin/env bash
set -euo pipefail

conf_dir=${TMUX_TEST_CONF_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
scratch_root=${TMUX_TEST_TMPDIR:-$HOME/.cache/tmux-tests}
mkdir -p "$scratch_root"
work=$(mktemp -d "$scratch_root/profiles.XXXXXX")
conf="$work/tmux.conf"

cleanup() {
  for profile in kitty wezterm; do
    TMUX_TMPDIR="$work/$profile" tmux kill-server >/dev/null 2>&1 || true
  done
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/kitty" "$work/wezterm"
cp "$conf_dir/tmux.conf" "$conf"
sed -i "s|^run '~/.config/tmux/plugins/tpm/tpm'|run 'true'|" "$conf"

start_profile() {
  local profile=$1 marker=$2
  env -u TMUX -u TMUX_PANE TMUX_TMPDIR="$work/$profile" \
    TERMINAL_STACK_PROFILE="$profile" KITTY_WINDOW_ID="$([[ $profile == kitty ]] && echo 1)" \
    WEZTERM_PANE="$([[ $profile == wezterm ]] && echo 1)" \
    tmux -f "$conf" new-session -d -s "${profile}-probe"
}

option() {
  local profile=$1 name=$2
  TMUX_TMPDIR="$work/$profile" tmux show-option -gv "$name"
}

start_profile kitty kitty
start_profile wezterm wezterm

for _ in {1..30}; do
  kitty_blue=$(option kitty @thm_blue 2>/dev/null || true)
  wezterm_blue=$(option wezterm @thm_blue 2>/dev/null || true)
  [[ -n "$kitty_blue" && -n "$wezterm_blue" ]] && break
  sleep 0.1
done

expected_blue=$(grep '^set -g @thm_blue ' "$conf_dir/colors-matugen.conf" | tail -1 | sed -E 's/.*"(#[0-9a-fA-F]{6})".*/\1/')
[[ -n "$expected_blue" ]] || {
  echo "FAIL: could not read @thm_blue from $conf_dir/colors-matugen.conf" >&2
  exit 1
}
[[ "$kitty_blue" == "$expected_blue" ]] || {
  echo "FAIL: Kitty tmux should use the shared wallpaper palette ($expected_blue), got '$kitty_blue'" >&2
  exit 1
}
[[ "$wezterm_blue" == "$expected_blue" ]] || {
  echo "FAIL: WezTerm tmux should use the shared wallpaper palette ($expected_blue), got '$wezterm_blue'" >&2
  exit 1
}

kitty_restore=$(option kitty @resurrect-dir)
wezterm_restore=$(option wezterm @resurrect-dir)
[[ "$kitty_restore" == "$HOME/.local/share/tmux/resurrect" ]] || {
  echo "FAIL: Kitty must retain its existing resurrect directory, got '$kitty_restore'" >&2
  exit 1
}
[[ "$wezterm_restore" == "$HOME/.local/share/tmux/resurrect/wezterm" ]] || {
  echo "FAIL: WezTerm must use its profile-specific restore directory, got '$wezterm_restore'" >&2
  exit 1
}

kitty_socket=$(TMUX_TMPDIR="$work/kitty" tmux display-message -p '#{socket_path}')
wezterm_socket=$(TMUX_TMPDIR="$work/wezterm" tmux display-message -p '#{socket_path}')
[[ "$kitty_socket" != "$wezterm_socket" ]] || {
  echo "FAIL: Kitty and WezTerm must use distinct tmux sockets" >&2
  exit 1
}

kitty_env=$(TMUX_TMPDIR="$work/kitty" tmux show-environment -g TERMINAL_STACK_PROFILE)
wezterm_env=$(TMUX_TMPDIR="$work/wezterm" tmux show-environment -g TERMINAL_STACK_PROFILE)
[[ "$kitty_env" == 'TERMINAL_STACK_PROFILE=kitty' && "$wezterm_env" == 'TERMINAL_STACK_PROFILE=wezterm' ]] || {
  echo "FAIL: profile environment mismatch (Kitty='$kitty_env', WezTerm='$wezterm_env')" >&2
  exit 1
}

echo "PASS: Kitty and WezTerm share one wallpaper palette; sockets, profiles, and restore paths stay distinct"
