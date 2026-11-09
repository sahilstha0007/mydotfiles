# mydotfiles — Universal Terminal Stack & Developer Environment

A portable, self-contained developer stack configuration for **any Linux distribution**. Zero machine-specific hardcoded paths, zero proprietary lock-in.

---

### Included Components

| Component | Path | Key Highlights |
|---|---|---|
| **Neovim** | `.config/nvim/` | Kickstart + LazyVim leader conventions, 13 LSP servers, DAP debugger, Snacks suite, Oil, Flash motions, `<leader>P` project tasks. |
| **Tmux** | `.config/tmux/` | `Ctrl+a` prefix, sessionizer (`Prefix+f`), session switcher (`Prefix+S`), popup LazyGit & LazyDocker, dynamic profile switching. |
| **Kitty Dev** | `.config/kitty/` | High-performance dev profile (`dev.conf`), modern floating rounded pills HUD (`tab_bar.py`), Nightfox theme, 100% zero-mouse QuickSelect suite (`Ctrl+Shift+P > ...`). |
| **WezTerm** | `.config/wezterm/` | GPU-accelerated visual workstation, dynamic wallpaper cascade, custom Lua tab pills & HUD, WSL/domain tabs. |
| **VS Code** | `.config/Code/User/` | Keyboard-harmonized `settings.json`, `keybindings.json`, and tracked extension list (`extensions.txt`). |
| **Shell & Runtime** | `shell/` | Portable environment (`.zshrc_custom`, `.bashrc_custom`, `.zshenv`), dual-profile Oh-My-Posh prompts, dynamic PATH & FZF bindings. |

---

### Architecture & Portability

- **No Root Required**: Everything deploys cleanly into `$HOME/.config/`.
- **Works on Any Linux Distribution**: Fedora, Arch, Ubuntu, Debian, openSUSE, Alpine, and WSL2.
- **Dynamic User Paths**: Uses `$HOME` and dynamic path expansions rather than hardcoded usernames.
- **Graceful Hardware Degradation**: Status modules (battery, containers, git, agents) automatically detect host capabilities and hide without errors if running in a VM, container, or desktop without a battery.
- **Non-Destructive Installation**: Safe automatic timestamped backup of existing configurations (`~/.config-backup-<timestamp>/`).

---

### Installation on Any Linux Machine

```bash
# 1. Clone repository
git clone https://github.com/sahiltuchheshrestha/mydotfiles.git ~/mydotfiles
cd ~/mydotfiles

# 2. Run installer (safely links configs into ~/.config)
./install.sh

# 3. Optional: Install VS Code extensions
xargs -n 1 code --install-extension < .config/Code/User/extensions.txt
```

---

### Keybindings Master Overview

- **Neovim Leader**: `Space` (buffers, files, LSP, tasks, git)
- **Tmux Prefix**: `Ctrl+a` (windows, splits, popups, session switcher)
- **Kitty Dev**: `Ctrl+Shift+<key>` (splits, layouts, fzf search, nvim pager, hints)
- **WezTerm Leader**: `Alt+Ctrl+Space` (key tables, font resizing, wallpaper preview)
- **Universal Cross-Layer Navigation**: `Ctrl+h/j/k/l` moves seamlessly across terminal splits and Neovim splits.
