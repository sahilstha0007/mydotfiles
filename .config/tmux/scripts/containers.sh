#!/usr/bin/env bash
# containers.sh — running podman containers, for the tmux status bar.
#
#   󰡨 3 grafana,mongo,nginx…
#
# Count first, then the NAMES — the count alone answers "is anything running",
# but not which of the eight images in this project is the one that keeps
# eating a core. Silent at zero: a "0" is not information, and an empty name
# list is not either.
#
# The names carry a hard budget (NAMES_BUDGET, 24 cols) before they would push
# the agents segment off the right of the bar — status-right-length 60 is a
# budget, not a maximum, and tmux truncates status-right to fit, so an over-long
# segment silently costs you the one after it. The budget arithmetic lives with
# the packing loop below.
#
# Cached 10s: `podman ps` is a socket round-trip and tmux re-runs #() every
# status-interval. The cache holds the whole rendered line (one line), which is
# why read(1) into `ts`/`val` takes the names too — `val` gets the rest of the
# line.
set -u

cache=/tmp/tmux-containers
now=$(date +%s)
if [ -f "$cache" ]; then
  read -r ts val <"$cache" 2>/dev/null || true
  if [ -n "${ts:-}" ] && [ $((now - ts)) -lt 10 ]; then
    printf '%s' "$val"
    exit 0
  fi
fi

val=''
if command -v podman >/dev/null 2>&1; then
  names=$(podman ps --format '{{.Names}}' 2>/dev/null | sort)
  if [ -n "$names" ]; then
    n=$(printf '%s\n' "$names" | wc -l | tr -d ' ')

    # Pack as many WHOLE names as fit the budget, then one ellipsis — instead
    # of clipping one long name mid-word and dropping every other container.
    # (Clipping the joined string gives `a-very-long-cont…` and tells you one
    # thing badly; filling gives `grafana,nginx…` and tells you three.)
    #
    # 24 is not arbitrary: status-right-length is 60 for the WHOLE right block
    # — git branch (~15) + state (~8) + agents (~7) + this segment's glyph and
    # count (~8) leave ~22. Growing names instead means either truncating the
    # agents segment away (tmux clips status-right to fit) or pushing total past
    # ~150, at which point tmux starts eating the centred window list.
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
        # The FIRST name alone being too long means there is nothing better
        # than clipping it -- without this the segment would be empty for a
        # single long-named container.
        if [ -z "$joined" ]; then
          joined="${nm:0:$((NAMES_BUDGET - 1))}…"
          break
        fi
        # Otherwise skip this name and keep going: the remaining names may be
        # short enough to show, and showing three short ones beats showing one
        # long one. The ellipsis below records that something was left out.
        dropped=1
        continue
      fi
      joined=$cand
    done <<EOF
$names
EOF
    [ "$dropped" -eq 1 ] && joined="${joined}…"

    val="  󰡨 ${n}  ${joined} "
  fi
fi

printf '%s' "$val"
printf '%s %s\n' "$now" "$val" >"$cache"
