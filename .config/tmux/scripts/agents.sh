#!/usr/bin/env bash
# agents.sh — coding-agent processes currently running, for the tmux status bar.
#
# herdr / opencode / claude / codex / ... run as ordinary processes; this
# counts the agent binaries actually alive so the bar answers "is an agent
# working for me right now?" without switching panes. Matching on comm= (the
# executable name) rather than the full command line avoids matching editors,
# shells or this script itself. Silent at zero. Cached 5s.
set -u

cache=/tmp/tmux-agents
now=$(date +%s)
if [ -f "$cache" ]; then
  read -r ts val <"$cache" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 5 ]; then
    printf '%s' "$val"
    exit 0
  fi
fi

n=$(ps -eo comm= 2>/dev/null |
  grep -Eic '^(claude|opencode|opencode\.exe|cline|cline\.exe|codex|copilot|aider|goose|crush|amp|gemini|herdr|omni)$')

val=''
[ "${n:-0}" -gt 0 ] && val="  󰚩 ${n} "

printf '%s' "$val"
printf '%s %s\n' "$now" "$val" >"$cache"
