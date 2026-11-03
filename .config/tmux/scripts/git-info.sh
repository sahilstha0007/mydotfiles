#!/usr/bin/env bash
# git-info.sh <pane_current_path> [pane_current_command]
#
# The focused pane's git BRANCH for the tmux status bar:
#     ⎇ <branch><*>          (dirty marker)
# or nothing at all when the pane is not inside a work tree.
#
# Split from git-state.sh (ahead/behind + stash) so the two can carry different
# colours: the branch is identity (mauve), the state is warning-ish (yellow).
# A #() segment cannot carry per-part styling — tmux paints the whole command
# output in the colour wrapped around it — so separate facts that want separate
# colours need separate segments.
#
# Two deliberate behaviours:
#   1. HIDDEN WHILE NVIM OWNS THE PANE. nvim's lualine already renders the
#      buffer's repo. Printing the cwd repo on the tmux line at the same time
#      would be the same fact twice.
#   2. CACHED PER DIRECTORY (5s). `git status --porcelain` is the expensive
#      call and tmux re-runs #() every status-interval.
set -u

dir="${1:-$PWD}"
cmd="${2:-}"

case "$cmd" in
  nvim | vim | vi ) exit 0 ;;
esac

[ -d "$dir" ] || dir="$PWD"

command -v git >/dev/null 2>&1 || exit 0
git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

cache="/tmp/tmux-git-$(printf '%s' "$dir" | md5sum | cut -c1-16)"
now=$(date +%s)
if [ -f "$cache" ]; then
  read -r ts val <"$cache" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 5 ]; then
    printf '%s' "$val"
    exit 0
  fi
fi

branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null ||
  git -C "$dir" rev-parse --short HEAD 2>/dev/null)
[ -n "$branch" ] || branch='?'

# Long branch names are the single biggest thing that pushes the right panel
# off a narrow terminal; cap it and ellipsize the middle-left (the tail usually
# names the change). One glyph + up to 20 chars.
if [ "${#branch}" -gt 20 ]; then
  branch="…${branch: -19}"
fi

dirty=''
[ -n "$(git -C "$dir" status --porcelain -uno 2>/dev/null | head -1)" ] && dirty='*'

# ⎇ branch, dirty star, one leading space so segments never touch.
val="  ⎇ ${branch}${dirty} "
printf '%s' "$val"
printf '%s %s\n' "$now" "$val" >"$cache"
