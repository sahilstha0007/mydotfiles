# mydotfiles — terminal stack

Neovim, tmux and WezTerm only. No system-wide files, no ml4w tree.
Kitty stays local at `~/.config/kitty` and is deliberately untracked.

| Path | Contents |
|---|---|
| `.config/nvim/` | Neovim (lazy.nvim, LSP, DAP, snacks, conform) |
| `.config/tmux/` | `tmux.conf`, scripts, hooks, sessionizer |
| `.config/wezterm/` | WezTerm Lua config, colors, utils, tests |

Not tracked — runtime state that stays on the machine:

- `.config/tmux/plugins/` — clones managed by tpm
- `.config/wezterm/backdrops/` — wallpaper images

## Install

```bash
./install.sh
```

The script symlinks each directory into `~/.config/`, moving any existing real
directory to `~/.config-backup-<timestamp>/` first. Run it on a new machine, or
after cloning.
