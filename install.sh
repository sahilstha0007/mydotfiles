#!/usr/bin/env bash
# Link the tracked terminal-stack configs into ~/.config, backing up anything
# real that is already at the destination.
#
# Runtime state (tmux plugins, wezterm backdrops) lives beside the configs and
# is gitignored, so it stays on this machine and is never tracked.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

for name in nvim tmux wezterm; do
  src="$repo/.config/$name"
  dst="$HOME/.config/$name"

  if [ ! -d "$src" ]; then
    echo "skip $name: $src is missing" >&2
    continue
  fi

  if [ -L "$dst" ]; then
    rm "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$backup"
    mv "$dst" "$backup/$name"
    echo "backed up $dst -> $backup/$name"
  fi

  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
done

echo
echo "Done. Start a new shell/nvim/tmux/wezterm to pick up the configs."
