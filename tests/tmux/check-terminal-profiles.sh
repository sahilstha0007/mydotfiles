#!/usr/bin/env bash
set -euo pipefail

conf_dir=${TMUX_TEST_CONF_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.config/tmux" && pwd)}
scratch_root=${TMUX_TEST_TMPDIR:-$HOME/.cache/tmux-tests}
mkdir -p "$scratch_root"
work=$(mktemp -d "$scratch_root/profiles.XXXXXX")
conf="$work/tmux.conf"

cleanup() {
  TMUX_TMPDIR="$work/wezterm" tmux kill-server >/dev/null 2>&1 || true
  TMUX_TMPDIR="$work/kitty" tmux kill-server >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/wezterm" "$work/kitty"
cp "$conf_dir/tmux.conf" "$conf"
sed -i "s|^run '~/.config/tmux/plugins/tpm/tpm'|run 'true'|" "$conf"

# 1. Start WezTerm profile
env -u TMUX -u TMUX_PANE -u KITTY_WINDOW_ID TMUX_TMPDIR="$work/wezterm" \
  TERMINAL_STACK_PROFILE="wezterm" WEZTERM_PANE="1" \
  tmux -f "$conf" new-session -d -s "wezterm-probe"

wezterm_blue=""
for _ in {1..30}; do
  wezterm_blue=$(TMUX_TMPDIR="$work/wezterm" tmux show-option -gv @thm_blue 2>/dev/null || true)
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

# 2. Start Kitty Nightfox profile and verify pane-border-status auto-toggle
env -u TMUX -u TMUX_PANE -u WEZTERM_PANE TMUX_TMPDIR="$work/kitty" \
  TERMINAL_STACK_PROFILE="kitty" KITTY_WINDOW_ID="1" \
  tmux -f "$conf" new-session -d -s "kitty-probe"

kitty_blue=""
for _ in {1..30}; do
  kitty_blue=$(TMUX_TMPDIR="$work/kitty" tmux show-option -gv @thm_blue 2>/dev/null || true)
  [[ -n "$kitty_blue" ]] && break
  sleep 0.1
done
expected_kitty_blue=$(grep '^set -g @thm_blue ' "$conf_dir/colors-nightfox.conf" | tail -1 | sed -E 's/.*"(#[0-9a-fA-F]{6})".*/\1/')
[[ "$kitty_blue" == "$expected_kitty_blue" ]] || {
  echo "FAIL: Kitty tmux should use Nightfox ($expected_kitty_blue), got '$kitty_blue'" >&2
  exit 1
}

border_single=$(TMUX_TMPDIR="$work/kitty" tmux display-message -p -t kitty-probe:1 '#{pane-border-status}')
[[ "$border_single" == "off" ]] || {
  echo "FAIL: single-pane window should hide pane-border-status, got '$border_single'" >&2
  exit 1
}

TMUX_TMPDIR="$work/kitty" tmux split-window -t kitty-probe:1 -h
sleep 0.1
border_split=$(TMUX_TMPDIR="$work/kitty" tmux display-message -p -t kitty-probe:1 '#{pane-border-status}')
[[ "$border_split" == "top" ]] || {
  echo "FAIL: split window should enable pane-border-status top, got '$border_split'" >&2
  exit 1
}

TMUX_TMPDIR="$work/kitty" tmux kill-pane -t kitty-probe:1.2
sleep 0.1
border_after=$(TMUX_TMPDIR="$work/kitty" tmux display-message -p -t kitty-probe:1 '#{pane-border-status}')
[[ "$border_after" == "off" ]] || {
  echo "FAIL: returning to 1 pane should hide pane-border-status, got '$border_after'" >&2
  exit 1
}

# 3. Script syntax checks + status-right.sh cache-miss vs cache-hit consistency
bash -n "$conf_dir/scripts/on-client-attached.sh"
bash -n "$conf_dir/scripts/status-right.sh"

mkdir -p "$work/bin" "$work/runtime"
cat >"$work/bin/ps" <<'EOF'
#!/usr/bin/env bash
printf 'bash\nclaude\n'
EOF
cat >"$work/bin/podman" <<'EOF'
#!/usr/bin/env bash
printf 'web\ndb\n'
EOF
chmod +x "$work/bin/ps" "$work/bin/podman"

miss_out=$(PATH="$work/bin:$PATH" XDG_RUNTIME_DIR="$work/runtime" \
  bash "$conf_dir/scripts/status-right.sh" "$work" "nvim")

[[ "$miss_out" == *"  󰚩 1 "* ]] || {
  echo "FAIL: status-right.sh cache miss missing expected agents padding: '$miss_out'" >&2
  exit 1
}
[[ "$miss_out" == *"  󰡨 2  db,web "* ]] || {
  echo "FAIL: status-right.sh cache miss missing expected containers padding: '$miss_out'" >&2
  exit 1
}

uid=$(id -u)
[[ -f "$work/runtime/tmux-status-$uid/agents" && -f "$work/runtime/tmux-status-$uid/containers" ]] || {
  echo "FAIL: status-right.sh did not populate per-user cache under XDG_RUNTIME_DIR" >&2
  exit 1
}

# Replace stubs with failing versions so run 2 proves a genuine cache hit
cat >"$work/bin/ps" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
cat >"$work/bin/podman" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$work/bin/ps" "$work/bin/podman"

hit_out=$(PATH="$work/bin:$PATH" XDG_RUNTIME_DIR="$work/runtime" \
  bash "$conf_dir/scripts/status-right.sh" "$work" "nvim")

[[ "$miss_out" == "$hit_out" ]] || {
  printf 'FAIL: status-right.sh cache miss vs hit mismatch:\n  miss=[%s]\n  hit =[%s]\n' \
    "$miss_out" "$hit_out" >&2
  exit 1
}

echo "PASS: Kitty Nightfox + WezTerm Matugen profiles, split-only pane borders, and status-right cache consistency verified"
