#!/usr/bin/env bash
# Session switcher — fzf over ALL tmux sessions with live window preview.
# Switches client if inside tmux; attaches otherwise.
set -uo pipefail

fzf_args=(
    --ansi
    --delimiter=$'\t'
    --with-nth=2
    --prompt='󰓦 session ❯ '
    --reverse
    --border=rounded
    --height=100%
    --preview='tmux list-windows -t {1} -F "  #I: #W #{?window_active,★ ,}(#{pane_current_command})  #{pane_current_path}"'
    --preview-window='right:55%:wrap'
)

if [[ "${TERMINAL_STACK_PROFILE:-}" == "kitty" ]]; then
    fzf_args+=(
        "--color=bg+:#212e3f,bg:-1,spinner:#719cd6,hl:#719cd6"
        "--color=fg:#cdcecf,header:#719cd6,info:#828f9f,pointer:#719cd6"
        "--color=marker:#81b29a,fg+:#cdcecf,prompt:#719cd6,hl+:#719cd6,border:#719cd6"
    )
fi

selected=$(tmux list-sessions -F $'#{session_name}\t#{session_name}  (#{session_windows} win#{?session_attached,, detached})' 2>/dev/null |
    fzf "${fzf_args[@]}" | cut -f1) || true

[[ -z $selected ]] && exit 0

if [[ -n "${TMUX:-}" ]]; then
    current=$(tmux display-message -p '#{session_name}')
    [[ $selected == "$current" ]] || tmux switch-client -t "$selected"
else
    exec tmux attach-session -t "$selected"
fi
