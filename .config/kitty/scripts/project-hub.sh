#!/usr/bin/env bash
# =============================================================================
# Kitty Dev — Interactive Project Hub
# Fast, visual fzf hub for projects, active sessions, and scratch workspaces.
# Works both inside tmux (popup) and outside tmux (direct attach).
# =============================================================================
set -uo pipefail

export TERMINAL_STACK_PROFILE="${TERMINAL_STACK_PROFILE:-kitty}"

# --- Preview Dispatcher ------------------------------------------------------
if [[ "${1:-}" == "--preview" ]]; then
    item_type="${2:-}"
    target="${3:-}"

    case "$item_type" in
        session)
            printf "\033[1;34m󰓦 TMUX SESSION: %s\033[0m\n" "$target"
            if tmux has-session -t "$target" 2>/dev/null; then
                printf "\033[36m──────────────────────────────────────────────────\033[0m\n"
                tmux display-message -p -t "$target" \
                    "Created: #{t:session_created}  |  Windows: #{session_windows}  |  Attached: #{?session_attached,yes,no}"
                printf "\033[36m──────────────────────────────────────────────────\033[0m\n"
                printf "\033[1;33mWindows in session:\033[0m\n"
                tmux list-windows -t "$target" -F "  #I: #W #{?window_active,★ ,} \033[2m(cwd: #{pane_current_path})\033[0m"
                printf "\n\033[1;33mActive pane command:\033[0m\n"
                tmux display-message -p -t "$target" "  #{pane_current_command} (PID #{pane_pid})"

                # If session has a known project root, display git status
                proj_root=$(tmux show-option -qv -t "$target" @project_root 2>/dev/null || true)
                if [[ -n "$proj_root" && -d "$proj_root" ]]; then
                    printf "\n\033[1;32mProject Root: %s\033[0m\n" "$proj_root"
                    if git -C "$proj_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                        git -C "$proj_root" status -sb 2>/dev/null | head -5
                    fi
                fi
            else
                printf "Session is no longer running.\n"
            fi
            ;;
        action)
            case "$target" in
                scratch)
                    printf "\033[1;32m󰅩 QUICK SCRATCH DEV SESSION\033[0m\n"
                    printf "\033[36m──────────────────────────────────────────────────\033[0m\n"
                    printf "Opens an ad-hoc scratch development session.\n"
                    printf "Ideal for quick tests, one-off scripts, and debugging.\n\n"
                    printf "Root: ~/Projects (or \$HOME)\n"
                    ;;
                projects_root)
                    printf "\033[1;34m󰋜 PROJECTS ROOT DIRECTORY\033[0m\n"
                    printf "\033[36m──────────────────────────────────────────────────\033[0m\n"
                    printf "Opens a dedicated tmux session rooted at ~/Projects.\n"
                    printf "Path: %s\n" "$HOME/Projects"
                    if [ -d "$HOME/Projects" ]; then
                        printf "\n\033[1;33mTop-level directories:\033[0m\n"
                        eza --icons --group-directories-first "$HOME/Projects" 2>/dev/null | head -15 || ls -A "$HOME/Projects" | head -15
                    fi
                    ;;
            esac
            ;;
        project)
            if [[ -d "$target" ]]; then
                printf "\033[1;34m󰉋 PROJECT: %s\033[0m\n" "$(basename "$target")"
                printf "\033[2m%s\033[0m\n" "$target"
                printf "\033[36m──────────────────────────────────────────────────\033[0m\n"

                # Git details if a git repository
                if git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
                    printf "\033[1;32mGit Status:\033[0m\n"
                    git -C "$target" status -sb 2>/dev/null | head -8
                    printf "\n\033[1;33mRecent Commits:\033[0m\n"
                    git -C "$target" log -n 4 --oneline --color=always 2>/dev/null
                    printf "\n"
                fi

                # Readme or file list
                if [[ -f "$target/README.md" ]]; then
                    printf "\033[1;35mREADME.md:\033[0m\n"
                    bat --style=plain --color=always --line-range :25 "$target/README.md" 2>/dev/null || head -25 "$target/README.md"
                else
                    printf "\033[1;35mDirectory Contents:\033[0m\n"
                    eza --color=always --icons --group-directories-first "$target" 2>/dev/null | head -20 || ls -A "$target" | head -20
                fi
            else
                printf "Directory not found: %s\n" "$target"
            fi
            ;;
        *)
            printf "Select an active session or project to inspect.\n"
            ;;
    esac
    exit 0
fi

# --- Helper: Generate Item List ----------------------------------------------
generate_items() {
    local projects="$HOME/Projects"

    # 1. Active Tmux Sessions
    if command -v tmux >/dev/null 2>&1; then
        tmux list-sessions -F '#{session_name}|#{session_windows}|#{?session_attached,attached,detached}' 2>/dev/null | \
        while IFS='|' read -r sname nwin status; do
            [[ -z "$sname" ]] && continue
            printf "󰓦 [session]  %-20s (%s win, %s)\tsession\t%s\n" "$sname" "$nwin" "$status" "$sname"
        done
    fi

    # 2. Quick Actions
    printf "󰅩 [action]   Quick Scratch Session\taction\tscratch\n"
    printf "󰋜 [action]   Projects Root (~/Projects)\taction\tprojects_root\n"

    # 3. Categorized & Standalone Projects under ~/Projects
    if [[ -d "$projects" ]]; then
        local known_cats="^(Active|Archive|Coursework|Current|Learning|Personal|Sandbox|Tools|Work|Client)$"
        for d in "$projects"/*; do
            [[ -d "$d" ]] || continue
            local b; b=$(basename "$d")
            [[ "$b" =~ ^\..* ]] && continue
            if [[ "$b" =~ $known_cats ]]; then
                for sub in "$d"/*; do
                    [[ -d "$sub" ]] || continue
                    local subb; subb=$(basename "$sub")
                    [[ "$subb" =~ ^\..* ]] && continue
                    [[ "$subb" =~ ^(node_modules|target|build|dist)$ ]] && continue
                    printf "󰉋 [project]  %s/%s\tproject\t%s\n" "$b" "$subb" "$sub"
                done
            else
                printf "󰉋 [project]  %s\tproject\t%s\n" "$b" "$d"
            fi
        done
    fi

    # 4. Key Dotfiles & Knowledge Vaults
    for extra in "$HOME/mydotfiles" "$HOME/Documents/Notes/Atlas"; do
        if [[ -d "$extra" ]]; then
            printf "󰉋 [project]  %s\tproject\t%s\n" "$(basename "$extra")" "$extra"
        fi
    done
}

# --- Action Execution Handler ------------------------------------------------
launch_target() {
    local itype="$1"
    local itarget="$2"

    case "$itype" in
        session)
            if [[ -n "${TMUX:-}" ]]; then
                tmux switch-client -t "$itarget"
            else
                exec tmux attach-session -t "$itarget"
            fi
            ;;
        action)
            case "$itarget" in
                scratch)
                    local sname="scratch"
                    if ! tmux has-session -t "$sname" 2>/dev/null; then
                        local root="$HOME/Projects"
                        [ -d "$root" ] || root="$HOME"
                        tmux new-session -ds "$sname" -c "$root"
                    fi
                    if [[ -n "${TMUX:-}" ]]; then
                        tmux switch-client -t "$sname"
                    else
                        exec tmux attach-session -t "$sname"
                    fi
                    ;;
                projects_root)
                    local sname="projects"
                    if ! tmux has-session -t "$sname" 2>/dev/null; then
                        tmux new-session -ds "$sname" -c "$HOME/Projects"
                    fi
                    if [[ -n "${TMUX:-}" ]]; then
                        tmux switch-client -t "$sname"
                    else
                        exec tmux attach-session -t "$sname"
                    fi
                    ;;
            esac
            ;;
        project)
            local selected="$itarget"
            [[ -z "$selected" || ! -d "$selected" ]] && return 1

            # Sanitize session name
            local name; name=$(basename "$selected" | tr '.:' '__')

            # Case-insensitive session match
            local existing; existing=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -i -m 1 "^${name}$" || true)
            [[ -n "$existing" ]] && name="$existing"

            # Create and seed if session does not exist
            if ! tmux has-session -t "$name" 2>/dev/null; then
                tmux new-session -ds "$name" -c "$selected"
                tmux set-option -t "$name" @project_root "$selected"

                # Wait for shell to be ready before seeding nvim
                for _ in 1 2 3 4 5 6 7 8 9 10; do
                    local cmd; cmd=$(tmux display-message -p -t "$name" '#{pane_current_command}' 2>/dev/null || true)
                    case "$cmd" in
                        zsh|bash|sh|fish|dash) break ;;
                    esac
                    sleep 0.05
                done
                tmux send-keys -t "$name" \
                    "nvim -c \"lua pcall(function() require('mini.sessions').read('$name') end)\"" C-m
            else
                tmux set-option -t "$name" @project_root "$selected"
            fi

            if [[ -n "${TMUX:-}" ]]; then
                tmux switch-client -t "$name"
            else
                exec tmux attach-session -t "$name" -c "$selected"
            fi
            ;;
    esac
}

resume_most_recent() {
    local recent
    recent=$(tmux list-sessions -F '#{session_name}:#{session_activity}' 2>/dev/null | sort -t: -k2 -nr | head -1 | cut -d: -f1 || true)
    if [[ -n "$recent" ]]; then
        if [[ -n "${TMUX:-}" ]]; then
            tmux switch-client -t "$recent"
        else
            exec tmux attach-session -t "$recent"
        fi
    else
        launch_target "action" "scratch"
    fi
}

# --- Main Interactive Hub Loop -----------------------------------------------
SELF_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

if [[ "${TERMINAL_STACK_PROFILE:-kitty}" == "kitty" ]]; then
  export FZF_DEFAULT_OPTS=" \
    --color=bg+:#212e3f,bg:-1,spinner:#719cd6,hl:#719cd6 \
    --color=fg:#cdcecf,header:#719cd6,info:#828f9f,pointer:#719cd6 \
    --color=marker:#81b29a,fg+:#cdcecf,prompt:#719cd6,hl+:#719cd6,border:#719cd6 \
    --prompt='󰉋 Dev Hub ❯ ' \
    --pointer='▶' \
    --marker='✓' \
    --layout=reverse \
    --border=rounded \
    --height=100% \
    --info=inline"
else
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} \
    --prompt='󰉋 Dev Hub ❯ ' \
    --pointer='▶' \
    --marker='✓' \
    --layout=reverse \
    --border=rounded \
    --height=100% \
    --info=inline"
fi

header_text="[Enter] Open  [C-r] Resume Last  [C-n] Scratch  [C-p] ~/Projects  [C-x] Kill Session  [Esc] Shell"

# Run FZF with live preview and keybindings
out=$(
    generate_items | fzf \
        --ansi \
        --delimiter=$'\t' \
        --with-nth=1 \
        --header="$header_text" \
        --expect=ctrl-r,ctrl-n,ctrl-p,ctrl-x \
        --preview="$SELF_PATH --preview {2} {3}" \
        --preview-window="right:52%:wrap" \
        --bind="ctrl-/:toggle-preview"
) || true

[[ -z "$out" ]] && {
    # If launched outside tmux and user pressed Esc/q, drop to shell cleanly
    if [[ -z "${TMUX:-}" ]]; then
        printf "\033[36m[Kitty Dev]\033[0m Interactive shell ready. Run \033[1;34mproject-hub\033[0m anytime.\n"
        exec zsh -l
    fi
    exit 0
}

key=$(printf '%s\n' "$out" | sed -n '1p')
selection=$(printf '%s\n' "$out" | sed -n '2p')

# Key intercepts
case "$key" in
    ctrl-r)
        resume_most_recent
        exit 0
        ;;
    ctrl-n)
        launch_target "action" "scratch"
        exit 0
        ;;
    ctrl-p)
        launch_target "action" "projects_root"
        exit 0
        ;;
    ctrl-x)
        if [[ -n "$selection" ]]; then
            stype=$(printf '%s' "$selection" | cut -f2)
            starget=$(printf '%s' "$selection" | cut -f3)
            if [[ "$stype" == "session" ]]; then
                tmux kill-session -t "$starget" 2>/dev/null || true
            fi
        fi
        # Re-invoke hub after killing
        exec "$SELF_PATH"
        ;;
esac

# Standard selection on Enter
if [[ -n "$selection" ]]; then
    sel_type=$(printf '%s' "$selection" | cut -f2)
    sel_target=$(printf '%s' "$selection" | cut -f3)
    launch_target "$sel_type" "$sel_target"
else
    if [[ -z "${TMUX:-}" ]]; then
        exec zsh -l
    fi
fi
