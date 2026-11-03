#!/usr/bin/env bash
# Project tasks from tmux (Prefix+P).
#
# fzf menu over project-task's four actions, then opens a NEW WINDOW in the
# caller's directory (not a popup: a dev server or test watcher needs to
# outlive the popup) running the action through the shared dispatcher.
#
# $1 = directory of the pane the popup was opened from.
set -uo pipefail

dir=${1:-$PWD}
bin=${PROJECT_TASK:-$HOME/.local/bin/project-task}

if [[ ! -x $bin ]]; then
    printf 'project-task not found at %s\n' "$bin" >&2
    exit 1
fi

action=$(printf 'run\ntest\nlint\nformat\n' |
    fzf --prompt "project action ❯ " --height 100% --reverse \
        --header "$(basename "$dir")") || exit 0

[[ -n $action ]] || exit 0

tmux new-window -c "$dir" -n "$action" \
    "$bin $action; printf '\n[done — press Enter to close]'; read -r"
