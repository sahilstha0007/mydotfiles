#!/usr/bin/env bash
# status-right.sh <pane_current_path> [pane_current_command]
#
# Unified status-right producer for tmux. Consolidates 4 separate subshell
# invocations (git-info, git-state, agents, containers) into a SINGLE lightweight
# script call, reducing process fork overhead by 75% on every status tick.
set -u

dir="${1:-$PWD}"
cmd="${2:-}"

# Bash builtins avoid 3 execve forks on every status tick (this script runs
# once per 5s client refresh; warm path should be near-zero forks).
cache_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/tmux-status-${EUID:-$(id -u)}"
[ -d "$cache_dir" ] || { mkdir -p "$cache_dir" 2>/dev/null && chmod 700 "$cache_dir" 2>/dev/null; } || true
now=${EPOCHSECONDS:-$(date +%s)}
_sep=$'\x1f'  # unit separator for composite cache values

read_cache() {
  local file="$1" ttl="$2" line="" ts="" val=""
  _cache_val=""
  [ -f "$file" ] || return 1
  IFS= read -r line <"$file" 2>/dev/null || return 1
  case "$line" in
    *'|'*)
      ts="${line%%|*}"
      val="${line#*|}"
      ;;
    *) return 1 ;;
  esac
  case "$ts" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ $((now - ts)) -ge 0 ] && [ $((now - ts)) -lt "$ttl" ] || return 1
  _cache_val="$val"
}

write_cache() {
  local file="$1" val="$2" tmp="${1}.tmp.$$"
  if printf '%s|%s\n' "$now" "$val" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$file" 2>/dev/null || rm -f "$tmp" 2>/dev/null || true
  fi
}

# 1. Git branch & state (hidden while nvim/vim owns the pane to avoid duplication with lualine)
git_info=""
git_state=""

# The git block below forks up to 6 times (rev-parse, symbolic-ref, status,
# rev-list, stash). Cache its two outputs keyed on dir with a 6s TTL — slightly
# longer than the 5s status-interval so every tick serves from cache. Staleness
# is at most one tick, imperceptible for a status bar.
cache_git="$cache_dir/git.$(printf '%s' "$dir" | tr -c 'A-Za-z0-9' '_')"
if read_cache "$cache_git" 6; then
  git_info="${_cache_val%%"$_sep"*}"
  git_state="${_cache_val#*"$_sep"}"
else
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
          ahead=0 behind=0
          IFS=$'\t ' read -r ahead behind _ < <(git -C "$dir" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null || true)
          [ -n "${ahead:-}" ] && [ "$ahead" -gt 0 ] 2>/dev/null && out="${out}↓$ahead"
          [ -n "${behind:-}" ] && [ "$behind" -gt 0 ] 2>/dev/null && out="${out}↑$behind"
        fi
        stashes=$(git -C "$dir" stash list 2>/dev/null | wc -l)
        [ "${stashes:-0}" -gt 0 ] && out="${out} ⚑${stashes}"
        [ -n "$out" ] && git_state=" ${out} "
      fi
    fi
    ;;
esac
  write_cache "$cache_git" "${git_info}${_sep}${git_state}"
fi

# 2. Coding agents (cached 5s)
agents_raw=""
cache_agents="$cache_dir/agents"
if read_cache "$cache_agents" 5; then
  agents_raw="$_cache_val"
else
  n=$(ps -eo comm= 2>/dev/null |
    LC_ALL=C awk '{s=tolower($0); if (s ~ /^(claude|opencode(\.exe)?|cline(\.exe)?|codex|copilot|aider|goose|crush|amp|gemini|herdr|omni)$/) c++} END{print c+0}')
  case "$n" in
    ''|*[!0-9]*) n=0 ;;
  esac
  [ "$n" -gt 0 ] && agents_raw="$n"
  write_cache "$cache_agents" "$agents_raw"
fi
agents=""
[ -n "$agents_raw" ] && agents="  󰚩 ${agents_raw} "

# 3. Containers (cached 10s)
containers_raw=""
cache_cont="$cache_dir/containers"
if read_cache "$cache_cont" 10; then
  containers_raw="$_cache_val"
elif command -v podman >/dev/null 2>&1; then
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
    containers_raw="${n}  ${joined}"
  fi
  write_cache "$cache_cont" "$containers_raw"
fi
containers=""
[ -n "$containers_raw" ] && containers="  󰡨 ${containers_raw} "

# Output composite status with color styling tokens
res=""
[ -n "$git_info" ] && res="${res}#[fg=#{@thm_mauve}]${git_info}"
[ -n "$git_state" ] && res="${res}#[fg=#{@thm_yellow}]${git_state}"
[ -n "$agents" ] && res="${res}#[fg=#{@thm_teal}]${agents}"
[ -n "$containers" ] && res="${res}#[fg=#{@thm_sapphire}]${containers}"

printf '%s' "$res"
