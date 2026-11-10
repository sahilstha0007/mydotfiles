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

fzf_args=(
    --prompt "project action ❯ "
    --height 100%
    --reverse
    --border=rounded
    --header "$(basename "$dir")"
)
if [[ "${TERMINAL_STACK_PROFILE:-}" == "kitty" ]]; then
    fzf_args+=(
        "--color=bg+:#212e3f,bg:-1,spinner:#719cd6,hl:#719cd6"
        "--color=fg:#cdcecf,header:#719cd6,info:#828f9f,pointer:#719cd6"
        "--color=marker:#81b29a,fg+:#cdcecf,prompt:#719cd6,hl+:#719cd6,border:#719cd6"
    )
fi

action=$(printf 'run\ntest\nlint\nformat\n' | fzf "${fzf_args[@]}") || exit 0

[[ -n $action ]] || exit 0

tmux new-window -c "$dir" -n "$action" \
    "$bin $action; printf '\n[done — press Enter to close]'; read -r"
