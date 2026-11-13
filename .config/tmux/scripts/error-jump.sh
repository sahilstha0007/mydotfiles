#!/usr/bin/env bash
# =============================================================================
# Tmux: Interactive Error / Traceback Jumper (Prefix + e)
# Scrapes pane scrollback for file:line patterns, presents fzf picker,
# and jumps directly to that error in Neovim.
# =============================================================================
set -euo pipefail

target_pane="${1:-}"
if [ -z "$target_pane" ]; then
  target_pane="$(tmux display-message -p '#{pane_id}')"
fi

pane_cwd="$(tmux display-message -p -t "$target_pane" '#{pane_current_path}')"
if [ -d "$pane_cwd" ]; then
  cd "$pane_cwd"
fi

# Capture the last 300 lines of scrollback
scrollback="$(tmux capture-pane -p -J -S -300 -t "$target_pane" 2>/dev/null || true)"

# Extract patterns like:
# path/to/file.ext:42 or path/to/file.ext:42:10 or File "path/to/file.py", line 42
matches="$(echo "$scrollback" | grep -oE '([a-zA-Z0-9_\.\/-]+\.[a-zA-Z0-9_-]+)(:[0-9]+|", line [0-9]+)' | sed -E 's/", line /:/g' | sort -u || true)"

candidates=""
while IFS= read -r match; do
  [ -z "$match" ] && continue
  file="${match%%:*}"
  line="${match##*:}"
  # Check if file exists relative to pane_cwd or as an absolute path
  if [ -f "$file" ]; then
    candidates+="$file:$line"$'\n'
  fi
done <<< "$matches"

if [ -z "$candidates" ]; then
  tmux display-message "No file errors or tracebacks detected in pane"
  exit 0
fi

# Select match via fzf with live file preview
chosen="$(echo -n "$candidates" | fzf \
  --prompt=" Jump to Error > " \
  --delimiter=":" \
  --preview="bat --style=numbers --color=always --highlight-line={2} {1} 2>/dev/null || cat {1}" \
  --preview-window="right:60%:wrap" \
  --reverse \
  --info=inline \
  --border=none || true)"

[ -z "$chosen" ] && exit 0

file="${chosen%%:*}"
line="${chosen##*:}"

# Check if target pane or any pane in current window is running Neovim
nvim_pane=""
while IFS=' ' read -r pid cmd; do
  if [[ "$cmd" =~ nvim|vim ]]; then
    nvim_pane="$pid"
    break
  fi
done < <(tmux list-panes -F '#{pane_id} #{pane_current_command}')

if [ -n "$nvim_pane" ]; then
  tmux select-pane -t "$nvim_pane"
  tmux send-keys -t "$nvim_pane" Escape ":e +${line} ${file}" Enter
else
  tmux select-pane -t "$target_pane"
  tmux send-keys -t "$target_pane" "nvim +${line} ${file}" Enter
fi
