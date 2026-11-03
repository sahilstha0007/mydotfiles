#!/usr/bin/env bash
# Validate wezterm's config by actually LOADING it.
#
# Do not trust `wezterm ls-fonts 2>&1 >/dev/null` here. That is what this script
# replaced, and it is worthless: `ls-fonts` and `show-keys` never run config
# validation, so a config full of invented field names reports clean. That is
# how `show_window_title`, `buttons` and `title_bar_height` all shipped as
# startup warnings nobody caught.
#
# The trick is `DISPLAY=` : wezterm cannot open a GUI, so it loads the config
# to find out why, and every schema violation is reported on stderr. No window
# is created, nothing steals focus, and this is safe to run in a script.
#
#   usage: scripts/check-config.sh [config-file]
#   exit  0 = clean, 1 = one or more config errors
set -uo pipefail

cfg=${1:-$HOME/.config/wezterm/wezterm.lua}

# HOME is redirected because events/fail.lua writes a load marker into
# $HOME/.cache and removes it when the config finishes loading. Redirected at a
# scratch dir so a check never mutates the real one -- and so a marker left
# behind by a real run cannot fail this one.
#
# The sandbox is not removed on exit, unlike the pre-commit hook's, which is
# `rm -rf`'d. This one is left in place and named so a failing run leaves the
# marker to look at: a few bytes under TMPDIR per run.
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/wz-check-XXXXXX")
mkdir -p "$sandbox/.cache" "$sandbox/.config"
ln -s "$(dirname -- "$cfg")" "$sandbox/.config/wezterm"
marker=$sandbox/.cache/wezterm-config-loaded

out=$(HOME="$sandbox" DISPLAY= timeout 25 wezterm --config-file "$cfg" start 2>&1)

# A load that never finishes emits nothing wezterm prints: the error goes only
# to wezterm's own log, and the window that opens is drawn from the PREVIOUS
# config. So on a tree whose config is broken at load time there is no ERROR on
# stderr to grep, and this script passes. events/fail.lua writes the marker as
# its first statement and removes it as the last statement of wezterm.lua; the
# marker surviving means the module graph never finished evaluating.
if [ -e "$marker" ]; then
  echo "wezterm config ERRORS: the config did not finish loading."
  printf '%s\n' "$out" | sed 's/^/  /'
  echo "  load it directly to see the error wezterm logs:"
  echo "    wezterm --config-file $cfg ls-fonts 2>&1 | head -20"
  exit 1
fi

if printf '%s' "$out" | grep -qiE 'Configuration Error|ERROR'; then
  echo "wezterm config ERRORS:"
  printf '%s\n' "$out" | sed 's/^/  /'
  exit 1
fi
echo "wezterm config ok: $cfg"
