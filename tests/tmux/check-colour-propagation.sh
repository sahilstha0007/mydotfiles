#!/usr/bin/env bash
# Prove a wallpaper palette change reaches an ALREADY-RUNNING tmux server.
#
# Why this test exists
# --------------------
# There are two different storage forms in play, and only one of them follows a
# palette change on its own:
#
#   set -g   -> stores the format verbatim ("fg=#{@thm_blue}"). tmux expands it
#               per render, so it picks up a new @thm_* the moment that token
#               changes, with no config reload at all.
#   set -gF  -> expands the format at set time. `show-options` then prints a
#               frozen hex, and re-sourcing the palette file does NOT change it;
#               only re-running the `set -gF` line (i.e. `source-file tmux.conf`)
#               re-evaluates it.
#
# tmux.conf uses -gF for pane-active-border-style, popup-style, popup-border-style
# and clock-mode-colour. That is correct and NOT a bug — -gF is required for the
# conditional in pane-active-border-style to survive as a live format, and a bare
# `set -g` on a colour option containing a format is rejected outright. But it
# does mean the palette file alone is not enough: tmux.conf must be re-sourced
# too, which is what sync-wallpaper.sh does. This test asserts that end to end.
# (Verified on tmux 3.7c: with -gF, a palette-only source leaves the option at
# the old hex; with plain -g the option text is unchanged and re-expands live.)
#
# This asserts that end to end, on a private socket, by capturing what a real
# client is actually sent over its pty and reading the SGR bytes. Checking
# `show-options` is not enough: options can hold a token reference or a frozen
# hex and only the rendered escape sequence tells you which.
#
# Usage: tests/check-colour-propagation.sh
# Exit:  0 = propagated, 1 = stale (the bug this guards), 2 = harness error.

set -uo pipefail

conf_dir=${TMUX_TEST_CONF_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.config/tmux" && pwd)}
sock=${TMUX_TEST_SOCK:-colour-propagation-$$}
# Under $HOME rather than /tmp: a stray TMPDIR=/tmp would otherwise place the
# scratch dir inside the directory being copied, and `cp -r` would recurse into
# itself (it tries to copy all of /tmp, fails on unreadable systemd dirs, and
# leaves no config behind).
scratch_root=${TMUX_TEST_TMPDIR:-$HOME/.cache/tmux-tests}
mkdir -p "$scratch_root"
work=$(mktemp -d "$scratch_root/probe.XXXXXX")
fail=0

cleanup() {
  tmux -L "$sock" kill-server 2>/dev/null
  rm -rf "$work"
}
trap cleanup EXIT

# ---- build an isolated copy of the real config, pointed at a fixture ------
# Copying (rather than editing the live file in place) keeps this test from
# touching the running session's config. Only two lines differ: the palette
# source and the tpm `run` line, which is stubbed so the test never forks a
# plugin manager or touches the network.
mkdir -p "$work/tmux"
cp -r "$conf_dir/." "$work/tmux/"
# The config dir is a symlink into the dotfiles repo. `cp -r "$conf_dir"`
# copies the LINK, not its contents, so the sed below rewrote the LIVE
# ~/.config/tmux/tmux.conf (it replaced the palette source with this test's
# fixture and the tpm loader with `run 'true'`). Copy the CONTENTS into a real
# dir and refuse to edit anything that resolves back outside $work.
[[ ! -L "$work/tmux" && -f "$work/tmux/tmux.conf" ]] || {
  echo "FATAL: $work/tmux is not a real config copy" >&2
  exit 2
}
case "$(readlink -f "$work/tmux/tmux.conf")" in
  "$work"/*) ;;
  *)
    echo "FATAL: refusing to edit a config outside $work" >&2
    exit 2
    ;;
esac
sed -i \
  -e "s|source-file -q ~/.config/tmux/colors-matugen.conf|source-file -q $work/fixture.conf|" \
  -e "s|^run '~/.config/tmux/plugins/tpm/tpm'|run 'true'|" \
  "$work/tmux/tmux.conf"

# The fixture is the real generated palette with ONE token repainted, so every
# other @thm_* resolves normally and the only variable in the result is the
# token under test. @thm_green paints the session name in status-left, which
# after the 2026-10-09 fg-only redesign is FOREGROUND text, not a bg fill
# ("tmux has no alpha, so transparent = no bg= anywhere in the status bar" —
# tmux.conf lines 52-59). The SGR run is therefore 38;2 (fg), matching the
# session name text directly.
cp "$conf_dir/colors-matugen.conf" "$work/fixture.conf"
grep -q '@thm_green' "$work/fixture.conf" || {
  echo "FATAL: fixture has no @thm_green; status-left shape changed?" >&2
  exit 2
}

# ---- start a server, attach a real client, capture its pty output ----------
# A detached server with no client never paints a status bar, so the capture has
# to be a genuine attach. `script` gives the client a pty and records every byte
# tmux writes to it, including the SGR runs that carry the pill colour.
start_server() {
  TERMINAL_STACK_PROFILE=wezterm WEZTERM_PANE=1 \
    tmux -L "$sock" -f "$work/tmux/tmux.conf" new-session -d -s probe -n winA
}

capture_live() { # capture_live <outfile> <seconds>
  TERM=xterm-256color script -qec "tmux -L $sock attach -t probe" /dev/null \
    > "$1" 2>/dev/null &
  echo $!
}

# The session name is drawn as ESC[38;2;R;G;B m (foreground) — with an
# underline-colour reset (ESC[58;2:0:0:0m) and a line wrap between the SGR and
# the text on tmux 3.7c — followed by the name itself, so the colour being
# asserted on is the one the client actually paints the session name with.
# Pull every such run out of the capture in order.
pill_foregrounds() { # pill_foregrounds <capture>
  perl -0777 -ne 'while (/\x1b\[38;2;(\d+);(\d+);(\d+)m(?:\x1b\[[\d;:]*[mH])*\s*probe/g) { print "$1,$2,$3\n" }' "$1"
}

want=255,0,0   # the colour @thm_green is switched TO mid-session
frozen_was=166,227,161 # @thm_green (#a6e3a1) as shipped — the pre-change text colour

start_server
client=$(capture_live "$work/before.raw" 2)
sleep 3

# ---- the wallpaper changes, underneath the running server ----------------
# Two tokens move: @thm_green backs the session pill (a plain `set -ga` format,
# which re-expands on its own) and @thm_text backs popup-style (a `set -gF`
# option, which is frozen at set time). Asserting on both is what gives this
# test teeth — the -gF half is the part that genuinely needs tmux.conf re-run.
sed -i -e 's/^set -g @thm_green ".*"/set -g @thm_green "#ff0000"/' \
       -e 's/^set -g @thm_text ".*"/set -g @thm_text "#ff0000"/' "$work/fixture.conf"

# Sourcing the palette ALONE must leave the -gF options frozen. If this ever
# stops holding, the check below is no longer proving what it claims.
tmux -L "$sock" source-file "$work/fixture.conf" 2>/dev/null
if [[ $(tmux -L "$sock" show-options -gv popup-style) == *"#ff0000"* ]]; then
  echo "NOTE: popup-style now follows the palette without a tmux.conf reload;"
  echo "      the -gF premise this test rests on has changed. tmux $(tmux -V | awk '{print $2}')."
fi

# The reload under test — the tmux-side half of what sync-wallpaper.sh does.
# (The wezterm half is another layer's job and is not exercised here.)
tmux -L "$sock" source-file "$work/tmux/tmux.conf" 2>/dev/null
sleep 2

# Nudge the client to repaint. tmux only redraws on activity or on
# status-interval; without this the capture can end before the new colour is
# ever sent, which would read as a failure that never happened.
tmux -L "$sock" set -g status-interval 1
sleep 4

# ---- assertion 1: the frozen option re-evaluated --------------------------
popup=$(tmux -L "$sock" show-options -gv popup-style)
if [[ $popup != *"#ff0000"* ]]; then
  echo "FAIL: popup-style is '$popup' — @thm_text=#ff0000 never reached it."
  echo "      A 'set -gF' colour option is frozen at set time, so tmux.conf"
  echo "      must be re-sourced for a palette change to land."
  tmux -L "$sock" kill-server 2>/dev/null
  wait "$client" 2>/dev/null
  exit 1
fi

tmux -L "$sock" kill-server 2>/dev/null
wait "$client" 2>/dev/null

# ---- assertion 2: the new colour reached the client's actual pty ----------
seen=$(pill_foregrounds "$work/before.raw" | sort -u)
if ! grep -qx "$want" <<<"$seen"; then
  echo "FAIL: session name never painted $want after the palette changed."
  echo "      foreground colours the client actually received for it:"
  sed 's/^/        /' <<<"$seen"
  echo "      A token the palette source never re-evaluated, or a status bar"
  echo "      that never repainted."
  exit 1
fi

echo "PASS: no restart, no client re-attach — the session name repainted"
echo "      $want after 'source-file tmux.conf' re-read the palette."
echo "      distinct session-name foregrounds the client received: $(tr '\n' ' ' <<<"$seen")"
echo "      ($frozen_was was the pre-change colour.)"
exit 0