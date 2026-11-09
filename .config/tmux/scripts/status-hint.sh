#!/usr/bin/env bash
# status-hint.sh — rotating keyboard-hint coach for the tmux right status bar.
#
# WHY THIS EXISTS (2026-10-13): the user over-uses the mouse. A full audit of
# the live keymaps showed every mouse action ALREADY has a keyboard equivalent
# (focus pane, jump window, scroll, resize, select/copy, paste, menus, splits,
# zoom, lazygit, lazydocker — all bound). So the gap is recall, not bindings.
# This replaced the git/containers/agents info segments: instead of decorating
# the bar with state, it quietly teaches the key for the most common mouse
# habits, one at a time, so the bar pays rent by reducing mouse reaches.
#
# It rotates on a calm cadence (default 18s) so it is a coach, not a strobe.
# The status bar re-runs #() every status-interval (5s); the hint is chosen
# from an epoch-time bucket so it holds steady between refreshes and only steps
# when the bucket rolls over. Tune with TMUX_HINT_SECS (smaller = faster cycle).
#
# Colour/marker live in tmux.conf (an @thm_* token — this file emits only text,
# so it contains no style escapes and never injects a stray #[ into the bar).
# Output must not contain the literal sequences #[ or #{ — none of these do.

set -uo pipefail

ROTATE_SECS="${TMUX_HINT_SECS:-18}"

# Curated, high-value mouse→key mappings, most common habit first. Keep each
# short enough to sit inside status-right-length (60). Arrow glyph → is U+2192.
hints=(
  'focus pane → C-h j k l'
  'jump window → Alt+1-9'
  'scroll → PgUp / C-a ['
  'resize pane → Alt+h j k l'
  'select text → C-a [ v y'
  'paste → C-a ]'
  'split → C-a | -'
  'zoom pane → C-a z'
  'lazygit → C-a g'
  'lazydocker → C-a d'
  'session → C-a s / S'
  'pane menu → C-a >'
  'window menu → C-a <'
  'new window → C-a c'
  'kill pane → C-a x'
)

n=${#hints[@]}
(( n == 0 )) && exit 0
idx=$(( ( $(date +%s) / ROTATE_SECS ) % n ))
printf '%s' "${hints[$idx]}"
