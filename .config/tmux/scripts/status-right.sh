#!/usr/bin/env bash
# status-right.sh <pane_current_path> [pane_current_command]
#
# Unified status-right producer for tmux. Consolidates 4 separate subshell
# invocations (git-info, git-state, agents, containers) into a SINGLE lightweight
# script call, reducing process fork overhead by 75% on every status tick.
set -u

dir="${1:-$PWD}"
cmd="${2:-}"

# 1. Git branch & state (hidden while nvim/vim owns the pane to avoid duplication with lualine)
git_info=""
git_state=""

case "$cmd" in
  nvim | vim | vi ) ;;
  * )
    if [ -d "$dir" ] && command -v git >/dev/null 2>&1; then
      if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        # Branch
        branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null ||
          git -C "$dir" rev-parse --short HEAD 2>/dev/null)
        [ -n "$branch" ] || branch='?'
        if [ "${#branch}" -gt 20 ]; then
          branch="…${branch: -19}"
        fi
        dirty=''
        [ -n "$(git -C "$dir" status --porcelain -uno 2>/dev/null | head -1)" ] && dirty='*'
        git_info="  ⎇ ${branch}${dirty} "

        # State (ahead/behind / stash)
        out=''
        if upstream=$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
          set -- $(git -C "$dir" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)
          [ -n "${1:-}" ] && [ "$1" -gt 0 ] 2>/dev/null && out="${out}↓$1"
          [ -n "${2:-}" ] && [ "$2" -gt 0 ] 2>/dev/null && out="${out}↑$2"
        fi
        stashes=$(git -C "$dir" stash list 2>/dev/null | wc -l)
        [ "${stashes:-0}" -gt 0 ] && out="${out} ⚑${stashes}"
        [ -n "$out" ] && git_state=" ${out} "
      fi
    fi
    ;;
esac

# 2. Coding agents (cached 5s)
agents=""
cache_agents=/tmp/tmux-agents
now=$(date +%s)
read_agent_cache=0
if [ -f "$cache_agents" ]; then
  read -r ts val <"$cache_agents" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 5 ]; then
    agents="$val"
    read_agent_cache=1
  fi
fi
if [ "$read_agent_cache" -eq 0 ]; then
  n=$(ps -eo comm= 2>/dev/null |
    grep -Eic '^(claude|opencode|opencode\.exe|cline|cline\.exe|codex|copilot|aider|goose|crush|amp|gemini|herdr|omni)$')
  [ "${n:-0}" -gt 0 ] && agents="  󰚩 ${n} "
  printf '%s %s\n' "$now" "$agents" >"$cache_agents" 2>/dev/null || true
fi

# 3. Containers (cached 10s)
containers=""
cache_cont=/tmp/tmux-containers
read_cont_cache=0
if [ -f "$cache_cont" ]; then
  read -r ts val <"$cache_cont" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 10 ]; then
    containers="$val"
    read_cont_cache=1
  fi
fi
if [ "$read_cont_cache" -eq 0 ] && command -v podman >/dev/null 2>&1; then
  names=$(podman ps --format '{{.Names}}' 2>/dev/null | sort)
  if [ -n "$names" ]; then
    n=$(printf '%s\n' "$names" | wc -l | tr -d ' ')
    NAMES_BUDGET=24
    joined=''
    dropped=0
    while IFS= read -r nm; do
      [ -n "$nm" ] || continue
      if [ -z "$joined" ]; then
        cand=$nm
      else
        cand="$joined,$nm"
      fi
      if [ "${#cand}" -gt "$NAMES_BUDGET" ]; then
        if [ -z "$joined" ]; then
          joined="${nm:0:$((NAMES_BUDGET - 1))}…"
          break
        fi
        dropped=1
        continue
      fi
      joined=$cand
    done <<EOF
$names
EOF
    [ "$dropped" -eq 1 ] && joined="${joined}…"
    containers="  󰡨 ${n}  ${joined} "
  fi
  printf '%s %s\n' "$now" "$containers" >"$cache_cont" 2>/dev/null || true
fi

# Output composite status with color styling tokens
res=""
[ -n "$git_info" ] && res="${res}#[fg=#{@thm_mauve}]${git_info}"
[ -n "$git_state" ] && res="${res}#[fg=#{@thm_yellow}]${git_state}"
[ -n "$agents" ] && res="${res}#[fg=#{@thm_teal}]${agents}"
[ -n "$containers" ] && res="${res}#[fg=#{@thm_sapphire}]${containers}"

printf '%s' "$res"
