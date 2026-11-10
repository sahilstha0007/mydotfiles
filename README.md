# mydotfiles — Unified Terminal Stack & Developer Environment

A modular, self-contained developer stack designed primarily for **Arch Linux / Wayland / Hyprland**, with portable `$HOME`-relative paths and graceful fallbacks across Linux distributions, SSH sessions, and containers.

---

### Included Components

| Component | Path | Key Highlights |
|---|---|---|
| **Neovim** | `.config/nvim/` | Kickstart-derived + LazyVim conventions, 13 LSP servers, DAP debugger, Snacks suite, `nvim-tree` (`Space+e`) + Oil (`-`), Flash motions, `<leader>P` project tasks. |
| **Tmux** | `.config/tmux/` | `Ctrl+a` prefix, Project Hub (`Prefix+f`), session switcher (`Prefix+S`), session/window tree (`Prefix+s`/`w`), popups (`g` LazyGit, `G` gh-dash, `d` LazyDocker, `b` Yazi, `T` btop, `V` nvtop, `k` keymap dump), Kitty Nightfox / WezTerm Matugen profile sync. |
| **Kitty Dev** | `.config/kitty/` | Unified dev profile (`custom.conf`, included by `kitty.conf`), floating rounded pills HUD (`tab_bar.py`), Nightfox theme, QuickSelect & hints (`Ctrl+Shift+Space`, `Ctrl+Shift+p > ...`), `Ctrl+h/j/k/l` split nav, overlay apps. |
| **WezTerm** | `.config/wezterm/` | GPU-accelerated visual workstation, dynamic wallpaper cascade + Matugen colors, custom Lua tab pills & HUD, named workspaces (`Alt+s`, `Alt+Ctrl+Space, w`), ready `domains.lua` scaffold (`ssh_domains` / `unix_domains` / `wsl_domains`). |
| **Shell & History** | `shell/`, `.config/atuin/`, `.config/ohmyposh/` | High-performance Zsh (`.zshrc` ~63ms startup, `.zshenv`), dual-profile Oh-My-Posh (`ohmyposh`), `atuin` synced history (`Ctrl+r`), Zoxide (`z`), lazy Mise activation, FZF (`Ctrl+t`, `Alt+c`), and Bash fallback (`.bashrc_custom`). |
| **CLI & TUI Tools** | `.config/bat/`, `.config/btop/`, `.config/yazi/`, `.config/lazygit/`, `.config/lazydocker/`, `.config/fastfetch/` | Theme-synchronized `bat`, `btop` (Matugen + Nightfox), `yazi`, `lazygit` (Matugen + Nightfox), `lazydocker` (Matugen + Nightfox), and `fastfetch`. |
| **VS Code** | `.config/Code/User/` | Keyboard-harmonized `settings.json`, `keybindings.json`, and tracked extension list (`extensions.txt`). |
| **CLI Binaries & Gates** | `bin/` | Single-command verification gate (`devcheck`), multi-language task runner (`project-task`), Project Hub sessionizer (`project-hub`), dev profile launcher (`kitty-dev`), and interactive keybinding HUD (`terminal-cheatsheet`). |

---

### Architecture & Portability

- **Primary Target & Portable Fallbacks**: Tuned first for Arch Linux / Wayland / Hyprland (including ML4W installer blacklist protection), with dynamic binary/browser detection and clean fallbacks for other Linux distros, headless SSH, and containers.
- **No Root Required**: Everything deploys cleanly via symlinks into `$HOME/.config/`, `$HOME/.local/bin/`, and `$HOME`.
- **Dynamic User Paths**: Uses `$HOME` and `$commands` lookups rather than hardcoded usernames or distro-specific absolute paths.
- **Graceful Hardware Degradation**: Status modules (battery, containers, git, agents) automatically detect host capabilities and hide without errors if running in a VM, container, or desktop without a battery.
- **Non-Destructive Installation**: Safe automatic timestamped backup of existing configurations (`~/.config-backup-<timestamp>/`).

---

### Installation

```bash
# 1. Clone repository
git clone https://github.com/sahiltuchheshrestha/mydotfiles.git ~/mydotfiles
cd ~/mydotfiles

# 2. Run installer (safely links configs into ~/.config, ~/.local/bin, and ~/)
./install.sh

# 3. Optional: Install VS Code extensions
xargs -n 1 code --install-extension < .config/Code/User/extensions.txt
```

---

### Keybindings Master Overview

- **Neovim Leader**: `Space` (`Space+e` nvim-tree, `-` Oil, `Space+ff/fg/sg` pickers, `Space+P` project tasks)
- **Tmux Prefix**: `Ctrl+a` (`Prefix+|/-` splits, `Prefix+f` Project Hub, `Prefix+S` session switcher, `Prefix+k` cross-layer keymap dump)
- **Kitty Dev**: `Ctrl+Shift+<key>` (`d/s` splits, `t/w` tabs, `f/h` scrollback, `g/y/m/o` overlays, `Ctrl+Shift+Space` QuickSelect, `Ctrl+Shift+p > ...` hints)
- **WezTerm Leader**: `Alt+Ctrl+Space` (`w` workspaces, `f` font resize, `p` pane resize; `Alt+o` backdrop panel, `Alt+p` wallpaper picker, `Alt+s` switch workspace)
- **Universal Cross-Layer Navigation**: `Ctrl+h/j/k/l` moves seamlessly across Kitty/Tmux splits and Neovim splits, and `terminal-cheatsheet` searches the full keybind table interactively.
