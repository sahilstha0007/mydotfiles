#!/usr/bin/env bash
# git-state.sh <pane_current_path> [pane_current_command]
#
# The focused pane's git STATE for the tmux status bar — the part that wants a
# different colour from the branch (see git-info.sh):
#     ↑2↓1 ⚑3        (commits ahead / behind upstream, stashed changes)
# or nothing when everything is clean and in sync.
#
# Each token is omitted independently: a repo with no upstream shows no arrows,
# a repo with no stash shows no flag, and a fully clean+synced repo prints
# nothing at all (so the panel shows no empty coloured gap).
#
# Hidden while an editor owns the pane (lualine owns git then), and cached 5s
# per directory — same contract as git-info.sh.
set -u

dir="${1:-$PWD}"
cmd="${2:-}"

case "$cmd" in
  nvim | vim | vi ) exit 0 ;;
esac

[ -d "$dir" ] || dir="$PWD"

command -v git >/dev/null 2>&1 || exit 0
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cache="/tmp/tmux-gitstate-$(printf '%s' "$dir" | md5sum | cut -c1-16)"
now=$(date +%s)
if [ -f "$cache" ]; then
  read -r ts val <"$cache" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 5 ]; then
    printf '%s' "$val"
    exit 0
  fi
fi

out=''

# Ahead/behind vs the tracking branch, if there is one.
if upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
  # rev-list --left-right --count upstream...HEAD prints "<behind>\t<ahead>"
  set -- $(git -C "$dir" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)
  [ -n "${1:-}" ] && [ "$1" -gt 0 ] 2>/dev/null && out="${out}↓$1"
  [ -n "${2:-}" ] && [ "$2" -gt 0 ] 2>/dev/null && out="${out}↑$2"
fi

# Stash entries.
stashes=$(git -C "$dir" stash list 2>/dev/null | wc -l)
[ "${stashes:-0}" -gt 0 ] && out="${out} ⚑${stashes}"

# Leading/trailing space only when there is something to show.
val=''
[ -n "$out" ] && val=" ${out} "

printf '%s' "$val"
printf '%s %s\n' "$now" "$val" >"$cache"
