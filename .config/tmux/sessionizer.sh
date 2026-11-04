#!/usr/bin/env bash
# tmux sessionizer — Prefix + f (tmux) / Alt+Ctrl+s (wezterm)
# fzf over project dirs -> create/switch to a named session rooted there.
# Works from inside tmux (popup) and from a bare shell (attaches).

projects="$HOME/Projects"

if [[ $# -eq 1 ]]; then
    selected="$1"
else
    # Upgraded interactive Project Hub with active sessions, git preview & scratch support
    if [[ -x "$HOME/.config/kitty/scripts/project-hub.sh" ]]; then
        exec "$HOME/.config/kitty/scripts/project-hub.sh"
    fi
    # Fallback to local discovery
    list=$(
        {
            known_cats="^(Active|Archive|Coursework|Current|Learning|Personal|Sandbox|Tools|Work|Client)$"
            for d in "$projects"/*; do
                [[ -d "$d" ]] || continue
                b=$(basename "$d")
                [[ "$b" =~ ^\..* ]] && continue
                if [[ "$b" =~ $known_cats ]]; then
                    find "$d" -mindepth 1 -maxdepth 1 -type d \
                        ! -name '.*' ! -name 'node_modules' ! -name 'target' ! -name 'build' ! -name 'dist' 2>/dev/null
                else
                    echo "$d"
                fi
            done
        } | sort -u
    )

    selected=$(printf '%s\n' "$list" | fzf --prompt='project ❯ ' --preview='ls -A {} | head -20')
fi

[[ -z $selected ]] && exit 0

# session names can't contain . or :
name=$(basename "$selected" | tr '.:' '__')

# Reuse existing session even if existing name differs only by casing (e.g. iothub vs iotHUB)
existing=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep -i -m 1 "^${name}$" || true)
if [[ -n $existing ]]; then
    name="$existing"
fi

# Only seed a fresh session with nvim; an existing session is switched to as-is
# so a re-pick never clobbers work already open in it.
if ! tmux has-session -t "$name" 2>/dev/null; then
    tmux new-session -ds "$name" -c "$selected"
    # Stamp project root on the session so all future windows and panes inherit it
    tmux set-option -t "$name" @project_root "$selected"

    # Open nvim in the project's first window. nvim loads this project's own
    # mini.session if one was saved under the project name (MiniSessions.write
    # "<name>"), so jumping back to a project restores its window layout; a
    # project with no saved session just opens a plain nvim. The pcall wrapper
    # means a missing/failed session load never blocks nvim from opening.
    #
    # Wait for the pane's shell to actually be running before sending keys:
    # new-session -d returns before the shell has exec'd, and keys sent too
    # early can land in the pre-shell buffer. Poll pane_current_command until
    # it is a shell (bounded, so a weird pane can't hang the popup forever).
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        cmd=$(tmux display-message -p -t "$name" '#{pane_current_command}' 2>/dev/null)
        case "$cmd" in
            zsh|bash|sh|fish|dash) break ;;
        esac
        sleep 0.1
    done
    tmux send-keys -t "$name" \
        "nvim -c \"lua pcall(function() require('mini.sessions').read('$name') end)\"" C-m
else
    # Existing session: ensure @project_root is stamped with this project's root path
    tmux set-option -t "$name" @project_root "$selected"
fi

cd "$selected" || exit 1

if [[ -n $TMUX ]]; then
    tmux switch-client -t "$name"
else
    exec tmux attach -t "$name" -c "$selected"
fi
