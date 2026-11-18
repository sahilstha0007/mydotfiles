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

### Stow layout

The repo is also a valid GNU Stow package, which is the fastest way to re-link after a
fresh clone or a partially broken `$HOME`:

```bash
cd ~/mydotfiles
./bin/stow-apply --check   # dry run: exit 0 means $HOME already matches the repo
./bin/stow-apply           # link every .config/<tool> dir into $HOME (idempotent)
./bin/stow-apply --remove  # unlink everything this repo owns
```

Stow owns **`~/.config/<tool>` directory symlinks only** (folding on, so nvim's `lazy/`
cache and tmux plugins stay inside the repo). `install.sh` still owns what stow cannot
express: `bin/` → `~/.local/bin/`, the renamed shell files (`shell/zshrc` → `~/.zshrc`),
and `~/.config/Code/User`. Running both is safe — `install.sh` skips links that are
already correct.

Validate the whole thing with `devcheck` or `install.sh --doctor`.

---

<!-- BEGIN KEYBINDINGS -->
### Keybindings Master Overview

- **Neovim Leader**: `Space` (`Space+e` nvim-tree, `-` Oil, `Space+ff/fg/sg` pickers, `Space+P` project tasks)
- **Tmux Prefix**: `Ctrl+a` (`Prefix+|/-` splits, `Prefix+f` Project Hub, `Prefix+S` session switcher, `Prefix+k` cross-layer keymap dump)
- **Kitty Dev**: `Ctrl+Shift+<key>` (`d/s` splits, `t/w` tabs, `f/h` scrollback, `g/y/m/o` overlays, `Ctrl+Shift+Space` QuickSelect, `Ctrl+Shift+p > ...` hints)
- **WezTerm Leader**: `Alt+Ctrl+Space` (`w` workspaces, `f` font resize, `p` pane resize; `Alt+o` backdrop panel, `Alt+p` wallpaper picker, `Alt+s` switch workspace)
- **Universal Cross-Layer Navigation**: `Ctrl+h/j/k/l` moves seamlessly across Kitty/Tmux splits and Neovim splits, and `terminal-cheatsheet` searches the full keybind table interactively.

<details>
<summary>Complete Live Keybinding Reference (220 generated bindings: WezTerm 99, Kitty 65, Tmux 56)</summary>

| Layer | Scope | Key | Action | Canonical ID |
|---|---|---|---|---|
| WezTerm | Default | `Alt + Backspace` | Delete line before cursor (Ctrl-U) | `WezTerm\|default:ALT:Backspace` |
| WezTerm | Default | `Alt + Enter` | Toggle pane zoom state | `WezTerm\|default:ALT:Enter` |
| WezTerm | Default | `Alt + Ctrl + Enter` | Maximize WezTerm window | `WezTerm\|default:ALT+CTRL:Enter` |
| WezTerm | Default | `Alt + +` | Grow window by 50px | `WezTerm\|default:ALT:+` |
| WezTerm | Default | `Alt + ,` | Previous wallpaper | `WezTerm\|default:ALT:,` |
| WezTerm | Default | `Alt + -` | Shrink window by 50px | `WezTerm\|default:ALT:-` |
| WezTerm | Default | `Alt + .` | Next wallpaper | `WezTerm\|default:ALT:.` |
| WezTerm | Default | `Alt + /` | Random wallpaper | `WezTerm\|default:ALT:/` |
| WezTerm | Default | `Alt + Ctrl + /` | Interactive wallpaper selector | `WezTerm\|default:ALT+CTRL:/` |
| WezTerm | Default | `Alt + 0` | Rename current tab title | `WezTerm\|default:ALT:0` |
| WezTerm | Default | `Alt + Ctrl + 0` | Reset tab title to default | `WezTerm\|default:ALT+CTRL:0` |
| WezTerm | Default | `Alt + Ctrl + 9` | Toggle top tab bar visibility | `WezTerm\|default:ALT+CTRL:9` |
| WezTerm | Default | `Alt + <` | Previous wallpaper | `WezTerm\|default:ALT:<` |
| WezTerm | Default | `Alt + =` | Grow window by 50px | `WezTerm\|default:ALT:=` |
| WezTerm | Default | `Alt + >` | Next wallpaper | `WezTerm\|default:ALT:>` |
| WezTerm | Default | `Ctrl + C` | Copy selection to clipboard | `WezTerm\|default:CTRL:C` |
| WezTerm | Default | `Alt + Ctrl + Q` | Quit WezTerm | `WezTerm\|default:ALT+CTRL:Q` |
| WezTerm | Default | `Alt + Ctrl + S` | Rename current workspace | `WezTerm\|default:ALT+CTRL:S` |
| WezTerm | Default | `Ctrl + T` | Create new tab (default domain) | `WezTerm\|default:CTRL:T` |
| WezTerm | Default | `Alt + U` | Increase backdrop frost wash | `WezTerm\|default:ALT:U` |
| WezTerm | Default | `Ctrl + V` | Paste from clipboard | `WezTerm\|default:CTRL:V` |
| WezTerm | Default | `Alt + Y` | Increase window opacity | `WezTerm\|default:ALT:Y` |
| WezTerm | Default | `Alt + [` | Previous tab | `WezTerm\|default:ALT:[` |
| WezTerm | Default | `Shift + Ctrl + [` | Previous tab | `WezTerm\|default:CTRL+SHIFT:[` |
| WezTerm | Default | `Alt + Ctrl + [` | Move tab left | `WezTerm\|default:ALT+CTRL:[` |
| WezTerm | Default | `Alt + ]` | Next tab | `WezTerm\|default:ALT:]` |
| WezTerm | Default | `Shift + Ctrl + ]` | Next tab | `WezTerm\|default:CTRL+SHIFT:]` |
| WezTerm | Default | `Alt + Ctrl + ]` | Move tab right | `WezTerm\|default:ALT+CTRL:]` |
| WezTerm | Default | `Alt + _` | Shrink window by 50px | `WezTerm\|default:ALT:_` |
| WezTerm | Default | `Alt + b` | Toggle backdrop focus mode | `WezTerm\|default:ALT:b` |
| WezTerm | Default | `Alt + f` | Search scrollback (case-insensitive) | `WezTerm\|default:ALT:f` |
| WezTerm | Default | `Leader > f` | Enter font resize key table (1s timeout) | `WezTerm\|default:LEADER:f` |
| WezTerm | Default | `Alt + n` | Spawn new WezTerm window | `WezTerm\|default:ALT:n` |
| WezTerm | Default | `Alt + o` | Open backdrop control panel key table | `WezTerm\|default:ALT:o` |
| WezTerm | Default | `Alt + p` | Open wallpaper picker key table | `WezTerm\|default:ALT:p` |
| WezTerm | Default | `Alt + Ctrl + p` | Swap active pane interactively (PaneSelect) | `WezTerm\|default:ALT+CTRL:p` |
| WezTerm | Default | `Leader > p` | Enter pane resize key table (1s timeout) | `WezTerm\|default:LEADER:p` |
| WezTerm | Default | `Alt + Ctrl + r` | Run Project Task dispatcher in new tab | `WezTerm\|default:ALT+CTRL:r` |
| WezTerm | Default | `Alt + s` | Interactive workspace switcher | `WezTerm\|default:ALT:s` |
| WezTerm | Default | `Alt + Ctrl + s` | Open Project Hub in new tmux tab | `WezTerm\|default:ALT+CTRL:s` |
| WezTerm | Default | `Alt + t` | Create new tab (default domain) | `WezTerm\|default:ALT:t` |
| WezTerm | Default | `Alt + u` | Decrease backdrop frost wash | `WezTerm\|default:ALT:u` |
| WezTerm | Default | `Alt + Ctrl + u` | QuickSelect URL and open in browser | `WezTerm\|default:ALT+CTRL:u` |
| WezTerm | Default | `Alt + Ctrl + w` | Close current tab | `WezTerm\|default:ALT+CTRL:w` |
| WezTerm | Default | `Leader > w` | Enter workspaces key table | `WezTerm\|default:LEADER:w` |
| WezTerm | Default | `Alt + Ctrl + x` | Close current pane (confirm) | `WezTerm\|default:ALT+CTRL:x` |
| WezTerm | Default | `Alt + y` | Decrease window opacity | `WezTerm\|default:ALT:y` |
| WezTerm | Default | `Shift + Ctrl + Space` | QuickSelect (URLs, hashes, paths) | `WezTerm\|default:CTRL+SHIFT:Space` |
| WezTerm | Default | `Shift + PageUp` | Jump to previous prompt | `WezTerm\|default:SHIFT:PageUp` |
| WezTerm | Default | `Shift + PageDown` | Jump to next prompt | `WezTerm\|default:SHIFT:PageDown` |
| WezTerm | Default | `F1` | Enter copy mode | `WezTerm\|default::F1` |
| WezTerm | Default | `F2` | Open command palette | `WezTerm\|default::F2` |
| WezTerm | Default | `F3` | Open launcher menu | `WezTerm\|default::F3` |
| WezTerm | Default | `F4` | Fuzzy tab switcher (Launcher) | `WezTerm\|default::F4` |
| WezTerm | Default | `F5` | Fuzzy workspace switcher (Launcher) | `WezTerm\|default::F5` |
| WezTerm | Default | `F6` | Unicode / Nerd Font / emoji symbol picker | `WezTerm\|default::F6` |
| WezTerm | Default | `F11` | Toggle fullscreen | `WezTerm\|default::F11` |
| WezTerm | Default | `F12` | Open WezTerm debug overlay | `WezTerm\|default::F12` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] Escape` | Close backdrop control panel | `WezTerm\|backdrops_panel::Escape` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] h` | Decrease window opacity | `WezTerm\|backdrops_panel::h` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] j` | Decrease frost wash | `WezTerm\|backdrops_panel::j` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] k` | Increase frost wash | `WezTerm\|backdrops_panel::k` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] l` | Increase window opacity | `WezTerm\|backdrops_panel::l` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] n` | Preview next wallpaper | `WezTerm\|backdrops_panel::n` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] p` | Preview previous wallpaper | `WezTerm\|backdrops_panel::p` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] q` | Close backdrop control panel | `WezTerm\|backdrops_panel::q` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] r` | Reset backdrop to session-start defaults | `WezTerm\|backdrops_panel::r` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] LeftArrow` | Decrease window opacity | `WezTerm\|backdrops_panel::LeftArrow` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] RightArrow` | Increase window opacity | `WezTerm\|backdrops_panel::RightArrow` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] UpArrow` | Increase frost wash | `WezTerm\|backdrops_panel::UpArrow` |
| WezTerm | Table:backdrops_panel | `[backdrops_panel] DownArrow` | Decrease frost wash | `WezTerm\|backdrops_panel::DownArrow` |
| WezTerm | Table:resize_font | `[resize_font] Escape` | Exit resize_font table | `WezTerm\|resize_font::Escape` |
| WezTerm | Table:resize_font | `[resize_font] j` | Decrease font size | `WezTerm\|resize_font::j` |
| WezTerm | Table:resize_font | `[resize_font] k` | Increase font size | `WezTerm\|resize_font::k` |
| WezTerm | Table:resize_font | `[resize_font] q` | Exit resize_font table | `WezTerm\|resize_font::q` |
| WezTerm | Table:resize_font | `[resize_font] r` | Reset font size | `WezTerm\|resize_font::r` |
| WezTerm | Table:resize_pane | `[resize_pane] Escape` | Exit resize_pane table | `WezTerm\|resize_pane::Escape` |
| WezTerm | Table:resize_pane | `[resize_pane] h` | Resize pane left 1 cell | `WezTerm\|resize_pane::h` |
| WezTerm | Table:resize_pane | `[resize_pane] j` | Resize pane down 1 cell | `WezTerm\|resize_pane::j` |
| WezTerm | Table:resize_pane | `[resize_pane] k` | Resize pane up 1 cell | `WezTerm\|resize_pane::k` |
| WezTerm | Table:resize_pane | `[resize_pane] l` | Resize pane right 1 cell | `WezTerm\|resize_pane::l` |
| WezTerm | Table:resize_pane | `[resize_pane] q` | Exit resize_pane table | `WezTerm\|resize_pane::q` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] Enter` | Commit wallpaper selection | `WezTerm\|wallpaper_picker::Enter` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] Escape` | Cancel and restore wallpaper | `WezTerm\|wallpaper_picker::Escape` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] ,` | Preview previous wallpaper | `WezTerm\|wallpaper_picker::,` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] .` | Preview next wallpaper | `WezTerm\|wallpaper_picker::.` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] /` | Preview random wallpaper | `WezTerm\|wallpaper_picker::/` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] h` | Preview previous wallpaper | `WezTerm\|wallpaper_picker::h` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] l` | Preview next wallpaper | `WezTerm\|wallpaper_picker::l` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] q` | Cancel and restore wallpaper | `WezTerm\|wallpaper_picker::q` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] r` | Preview random wallpaper | `WezTerm\|wallpaper_picker::r` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] LeftArrow` | Preview previous wallpaper | `WezTerm\|wallpaper_picker::LeftArrow` |
| WezTerm | Table:wallpaper_picker | `[wallpaper_picker] RightArrow` | Preview next wallpaper | `WezTerm\|wallpaper_picker::RightArrow` |
| WezTerm | Table:workspaces | `[workspaces] Escape` | Exit workspaces table | `WezTerm\|workspaces::Escape` |
| WezTerm | Table:workspaces | `[workspaces] d` | Delete workspace interactively | `WezTerm\|workspaces::d` |
| WezTerm | Table:workspaces | `[workspaces] n` | Next workspace | `WezTerm\|workspaces::n` |
| WezTerm | Table:workspaces | `[workspaces] q` | Exit workspaces table | `WezTerm\|workspaces::q` |
| WezTerm | Table:workspaces | `[workspaces] r` | Rename current workspace | `WezTerm\|workspaces::r` |
| WezTerm | Table:workspaces | `[workspaces] s` | EmitEvent("user-defined-1") | `WezTerm\|workspaces::s` |
| Kitty | Keys | `ctrl+shift+d` | launch --location=vsplit --cwd=current | `Kitty\|ctrl+shift+d` |
| Kitty | Keys | `ctrl+shift+s` | launch --location=hsplit --cwd=current | `Kitty\|ctrl+shift+s` |
| Kitty | Keys | `ctrl+shift+enter` | launch --cwd=current | `Kitty\|ctrl+shift+enter` |
| Kitty | Keys | `ctrl+shift+z` | toggle_layout stack | `Kitty\|ctrl+shift+z` |
| Kitty | Keys | `ctrl+shift+l` | next_layout | `Kitty\|ctrl+shift+l` |
| Kitty | Keys | `ctrl+h` | neighboring_window left | `Kitty\|ctrl+h` |
| Kitty | Keys | `ctrl+j` | neighboring_window bottom | `Kitty\|ctrl+j` |
| Kitty | Keys | `ctrl+k` | neighboring_window top | `Kitty\|ctrl+k` |
| Kitty | Keys | `ctrl+l` | neighboring_window right | `Kitty\|ctrl+l` |
| Kitty | Keys | `ctrl+shift+left` | neighboring_window left | `Kitty\|ctrl+shift+left` |
| Kitty | Keys | `ctrl+shift+right` | neighboring_window right | `Kitty\|ctrl+shift+right` |
| Kitty | Keys | `ctrl+shift+up` | neighboring_window up | `Kitty\|ctrl+shift+up` |
| Kitty | Keys | `ctrl+shift+down` | neighboring_window down | `Kitty\|ctrl+shift+down` |
| Kitty | Keys | `ctrl+shift+alt+left` | move_window left | `Kitty\|ctrl+shift+alt+left` |
| Kitty | Keys | `ctrl+shift+alt+right` | move_window right | `Kitty\|ctrl+shift+alt+right` |
| Kitty | Keys | `ctrl+shift+alt+up` | move_window up | `Kitty\|ctrl+shift+alt+up` |
| Kitty | Keys | `ctrl+shift+alt+down` | move_window down | `Kitty\|ctrl+shift+alt+down` |
| Kitty | Keys | `ctrl+shift+alt+h` | resize_window narrower 3 | `Kitty\|ctrl+shift+alt+h` |
| Kitty | Keys | `ctrl+shift+alt+l` | resize_window wider 3 | `Kitty\|ctrl+shift+alt+l` |
| Kitty | Keys | `ctrl+shift+alt+k` | resize_window taller 3 | `Kitty\|ctrl+shift+alt+k` |
| Kitty | Keys | `ctrl+shift+alt+j` | resize_window shorter 3 | `Kitty\|ctrl+shift+alt+j` |
| Kitty | Keys | `ctrl+shift+alt+r` | resize_window reset | `Kitty\|ctrl+shift+alt+r` |
| Kitty | Keys | `ctrl+shift+t` | launch --type=tab --cwd=current | `Kitty\|ctrl+shift+t` |
| Kitty | Keys | `ctrl+shift+w` | close_tab | `Kitty\|ctrl+shift+w` |
| Kitty | Keys | `ctrl+shift+q` | close_window | `Kitty\|ctrl+shift+q` |
| Kitty | Keys | `ctrl+shift+f11` | toggle_fullscreen | `Kitty\|ctrl+shift+f11` |
| Kitty | Leader > | `ctrl+shift+p>z` | toggle_layout stack | `Kitty\|ctrl+shift+p>z` |
| Kitty | Keys | `ctrl+shift+]` | next_tab | `Kitty\|ctrl+shift+]` |
| Kitty | Keys | `ctrl+shift+[` | previous_tab | `Kitty\|ctrl+shift+[` |
| Kitty | Keys | `ctrl+shift+1` | goto_tab 1 | `Kitty\|ctrl+shift+1` |
| Kitty | Keys | `ctrl+shift+2` | goto_tab 2 | `Kitty\|ctrl+shift+2` |
| Kitty | Keys | `ctrl+shift+3` | goto_tab 3 | `Kitty\|ctrl+shift+3` |
| Kitty | Keys | `ctrl+shift+4` | goto_tab 4 | `Kitty\|ctrl+shift+4` |
| Kitty | Keys | `ctrl+shift+5` | goto_tab 5 | `Kitty\|ctrl+shift+5` |
| Kitty | Keys | `ctrl+shift+,` | move_tab_backward | `Kitty\|ctrl+shift+,` |
| Kitty | Keys | `ctrl+shift+.` | move_tab_forward | `Kitty\|ctrl+shift+.` |
| Kitty | Keys | `ctrl+shift+alt+t` | set_tab_title | `Kitty\|ctrl+shift+alt+t` |
| Kitty | Keys | `ctrl+shift+tab` | launch --type=overlay tab-switcher.sh | `Kitty\|ctrl+shift+tab` |
| Kitty | Leader > | `ctrl+shift+p>t` | launch --type=overlay tab-switcher.sh | `Kitty\|ctrl+shift+p>t` |
| Kitty | Keys | `ctrl+shift+f` | launch --type=overlay --stdin-source=@screen_scrollback fzf --no-sort --exact -i --reverse | `Kitty\|ctrl+shift+f` |
| Kitty | Keys | `ctrl+shift+h` | launch --stdin-source=@screen_scrollback --type=overlay nvim-scrollback-pager.sh | `Kitty\|ctrl+shift+h` |
| Kitty | Keys | `ctrl+shift+k` | kitten command_palette | `Kitty\|ctrl+shift+k` |
| Kitty | Leader > | `ctrl+shift+p>c` | kitten command_palette | `Kitty\|ctrl+shift+p>c` |
| Kitty | Keys | `ctrl+shift+g` | launch --type=overlay --cwd=current lazygit | `Kitty\|ctrl+shift+g` |
| Kitty | Leader > | `ctrl+shift+p>g` | launch --type=overlay --cwd=current lazygit | `Kitty\|ctrl+shift+p>g` |
| Kitty | Leader > | `ctrl+shift+p>d` | launch --type=overlay --cwd=current lazydocker | `Kitty\|ctrl+shift+p>d` |
| Kitty | Keys | `ctrl+shift+y` | launch --type=overlay --cwd=current yazi | `Kitty\|ctrl+shift+y` |
| Kitty | Leader > | `ctrl+shift+p>y` | launch --type=overlay --cwd=current yazi | `Kitty\|ctrl+shift+p>y` |
| Kitty | Keys | `ctrl+shift+m` | launch --type=overlay btop -c ~/.config/btop/btop-apple-glass.conf | `Kitty\|ctrl+shift+m` |
| Kitty | Leader > | `ctrl+shift+p>m` | launch --type=overlay btop -c ~/.config/btop/btop-apple-glass.conf | `Kitty\|ctrl+shift+p>m` |
| Kitty | Leader > | `ctrl+shift+p>k` | launch --type=overlay --cwd=current zsh -c 'git difftool --tool=kitty --no-prompt \|\| { echo "No git diff to display"; sleep 1; }' | `Kitty\|ctrl+shift+p>k` |
| Kitty | Keys | `ctrl+shift+u` | kitten unicode_input | `Kitty\|ctrl+shift+u` |
| Kitty | Keys | `ctrl+shift+e` | open_url_with_hints | `Kitty\|ctrl+shift+e` |
| Kitty | Leader > | `ctrl+shift+p>n` | kitten hints --type linenum --linenum-action=self nvim +{line} {path} | `Kitty\|ctrl+shift+p>n` |
| Kitty | Leader > | `ctrl+shift+p>shift+f` | kitten hints --type path | `Kitty\|ctrl+shift+p>shift+f` |
| Kitty | Keys | `ctrl+shift+o` | launch --type=overlay project-hub.sh | `Kitty\|ctrl+shift+o` |
| Kitty | Leader > | `ctrl+shift+p>p` | launch --type=overlay project-hub.sh | `Kitty\|ctrl+shift+p>p` |
| Kitty | Leader > | `ctrl+shift+a>m` | set_background_opacity +0.05 | `Kitty\|ctrl+shift+a>m` |
| Kitty | Leader > | `ctrl+shift+a>l` | set_background_opacity -0.05 | `Kitty\|ctrl+shift+a>l` |
| Kitty | Leader > | `ctrl+shift+a>d` | set_background_opacity default | `Kitty\|ctrl+shift+a>d` |
| Kitty | Leader > | `ctrl+shift+a>1` | set_background_opacity 1.0 | `Kitty\|ctrl+shift+a>1` |
| Kitty | Keys | `ctrl+shift+equal` | change_font_size all +1.0 | `Kitty\|ctrl+shift+equal` |
| Kitty | Keys | `ctrl+shift+plus` | change_font_size all +1.0 | `Kitty\|ctrl+shift+plus` |
| Kitty | Keys | `ctrl+shift+minus` | change_font_size all -1.0 | `Kitty\|ctrl+shift+minus` |
| Kitty | Keys | `ctrl+shift+backspace` | change_font_size all 0 | `Kitty\|ctrl+shift+backspace` |
| Tmux | Prefix | `Prefix + C-a` | send-prefix | `Tmux\|prefix:C-a` |
| Tmux | Prefix | `Prefix + B` | set-option -g status | `Tmux\|prefix:B` |
| Tmux | Prefix | `Prefix + r` | source-file /home/sahil/.config/tmux/tmux.conf \; display-message "/home/sahil/.config/tmux/tmux.conf reloaded" | `Tmux\|prefix:r` |
| Tmux | Prefix | `Prefix + H` | resize-pane -L 5 | `Tmux\|prefix:H` |
| Tmux | Prefix | `Prefix + J` | resize-pane -D 5 | `Tmux\|prefix:J` |
| Tmux | Prefix | `Prefix + K` | resize-pane -U 5 | `Tmux\|prefix:K` |
| Tmux | Prefix | `Prefix + L` | resize-pane -R 5 | `Tmux\|prefix:L` |
| Tmux | Prefix | `Prefix + \|` | split-window -h -c "#{?pane_current_path,#{pane_current_path},#{?@project_root,#{@project_root},#{session_path}}}" | `Tmux\|prefix:\|` |
| Tmux | Prefix | `Prefix + -` | split-window -v -c "#{?pane_current_path,#{pane_current_path},#{?@project_root,#{@project_root},#{session_path}}}" | `Tmux\|prefix:-` |
| Tmux | Prefix | `Prefix + c` | new-window -c "#{?pane_current_path,#{pane_current_path},#{?@project_root,#{@project_root},#{session_path}}}" | `Tmux\|prefix:c` |
| Tmux | Prefix | `Prefix + x` | confirm-before -p "kill-pane #P? (y/n)" kill-pane | `Tmux\|prefix:x` |
| Tmux | Prefix | `Prefix + X` | kill-pane | `Tmux\|prefix:X` |
| Tmux | Prefix | `Prefix + Q` | confirm-before -p "Save state and shutdown tmux server? (y/n)" "run-shell '~/.local/bin/tmux-shutdown'" | `Tmux\|prefix:Q` |
| Tmux | Prefix | `Prefix + f` | display-popup -E -S "fg=#{@thm_blue}" -T "  Project Hub " -b rounded -h "85%" -s bg=default -w "85%" /home/sahil/.local/bin/project-hub | `Tmux\|prefix:f` |
| Tmux | Prefix | `Prefix + S` | display-popup -E -S "fg=#{@thm_blue}" -T "  Sessions " -b rounded -s bg=default /home/sahil/.config/tmux/session-switcher.sh | `Tmux\|prefix:S` |
| Tmux | Prefix | `Prefix + w` | choose-tree -Zw | `Tmux\|prefix:w` |
| Tmux | Prefix | `Prefix + g` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "90%" -s bg=default -w "90%" lazygit | `Tmux\|prefix:g` |
| Tmux | Prefix | `Prefix + G` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "90%" -s bg=default -w "90%" "gh dash" | `Tmux\|prefix:G` |
| Tmux | Prefix | `Prefix + d` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "90%" -s bg=default -w "90%" lazydocker | `Tmux\|prefix:d` |
| Tmux | Prefix | `Prefix + b` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "90%" -s bg=default -w "90%" yazi | `Tmux\|prefix:b` |
| Tmux | Prefix | `Prefix + y` | choose-buffer -Z | `Tmux\|prefix:y` |
| Tmux | Prefix | `Prefix + h` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -h "90%" -s bg=default -w "90%" "/home/sahil/.config/tmux/scripts/scrollback-pager.sh '#{pane_id}'" | `Tmux\|prefix:h` |
| Tmux | Prefix | `Prefix + e` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "65%" -s bg=default -w "85%" "/home/sahil/.config/tmux/scripts/error-jump.sh '#{pane_id}'" | `Tmux\|prefix:e` |
| Tmux | Prefix | `Prefix + P` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "40%" -s bg=default -w "60%" "/home/sahil/.config/tmux/project-task.sh '#{pane_current_path}'" | `Tmux\|prefix:P` |
| Tmux | Prefix | `Prefix + ;` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "40%" -s bg=default -w "60%" "/home/sahil/.config/tmux/project-task.sh '#{pane_current_path}'" | `Tmux\|prefix:;` |
| Tmux | Prefix | `Prefix + T` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -h "90%" -s bg=default -w "90%" "if [ \"\$TERMINAL_STACK_PROFILE\" = \"kitty\" ]; then exec btop -c \"\$HOME/.config/btop/btop-apple-glass.conf\"; else exec btop; fi" | `Tmux\|prefix:T` |
| Tmux | Prefix | `Prefix + V` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -h "90%" -s bg=default -w "90%" nvtop | `Tmux\|prefix:V` |
| Tmux | Prefix | `Prefix + D` | detach-client | `Tmux\|prefix:D` |
| Tmux | Prefix | `Prefix + s` | choose-tree -Zs | `Tmux\|prefix:s` |
| Tmux | Prefix | `Prefix + Tab` | switch-client -l | `Tmux\|prefix:Tab` |
| Tmux | Prefix | `Prefix + u` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "75%" -s bg=default -w "80%" "exec \${SHELL:-zsh}" | `Tmux\|prefix:u` |
| Tmux | Prefix | `Prefix + =` | select-layout even-horizontal | `Tmux\|prefix:=` |
| Tmux | Prefix | `Prefix + Left` | previous-window | `Tmux\|prefix:Left` |
| Tmux | Prefix | `Prefix + Right` | next-window | `Tmux\|prefix:Right` |
| Tmux | Prefix | `Prefix + p` | previous-window | `Tmux\|prefix:p` |
| Tmux | Prefix | `Prefix + n` | next-window | `Tmux\|prefix:n` |
| Tmux | Root | `[root] M-1` | select-window -t 1 | `Tmux\|root:M-1` |
| Tmux | Root | `[root] M-2` | select-window -t 2 | `Tmux\|root:M-2` |
| Tmux | Root | `[root] M-3` | select-window -t 3 | `Tmux\|root:M-3` |
| Tmux | Root | `[root] M-4` | select-window -t 4 | `Tmux\|root:M-4` |
| Tmux | Root | `[root] M-5` | select-window -t 5 | `Tmux\|root:M-5` |
| Tmux | Root | `[root] M-6` | select-window -t 6 | `Tmux\|root:M-6` |
| Tmux | Root | `[root] M-7` | select-window -t 7 | `Tmux\|root:M-7` |
| Tmux | Root | `[root] M-8` | select-window -t 8 | `Tmux\|root:M-8` |
| Tmux | Root | `[root] M-9` | select-window -t 9 | `Tmux\|root:M-9` |
| Tmux | Root | `[root] M-S-Left` | swap-window -d -t -1 | `Tmux\|root:M-S-Left` |
| Tmux | Root | `[root] M-S-Right` | swap-window -d -t +1 | `Tmux\|root:M-S-Right` |
| Tmux | Root | `[root] PPage` | if-shell -b "! ps -o comm= -t '#{pane_tty}' \| grep -qE '(less\|more\|man\|htop\|btop\|top\|vim\|nvim\|view\|emacs\|psql\|watch\|fzf\|lazygit\|yazi)'" "copy-mode -u" | `Tmux\|root:PPage` |
| Tmux | copy-mode-vi | `[copy-mode-vi] y` | send-keys -X copy-selection-and-cancel | `Tmux\|copy-mode-vi:y` |
| Tmux | copy-mode-vi | `[copy-mode-vi] v` | send-keys -X begin-selection | `Tmux\|copy-mode-vi:v` |
| Tmux | copy-mode-vi | `[copy-mode-vi] V` | send-keys -X select-line | `Tmux\|copy-mode-vi:V` |
| Tmux | copy-mode-vi | `[copy-mode-vi] C-v` | send-keys -X rectangle-toggle | `Tmux\|copy-mode-vi:C-v` |
| Tmux | Prefix | `Prefix + l` | last-window | `Tmux\|prefix:l` |
| Tmux | Prefix | `Prefix + k` | display-popup -E -S "fg=#{@thm_blue}" -b rounded -d "#{pane_current_path}" -h "80%" -s bg=default -w "85%" /home/sahil/.config/tmux/keymap-dump.sh | `Tmux\|prefix:k` |
| Tmux | Prefix | `Prefix + C-s` | if-shell "[ -x ~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh ]" "run-shell '~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh'" "display-message 'tmux-resurrect not installed (press prefix + I)'" | `Tmux\|prefix:C-s` |
| Tmux | Prefix | `Prefix + C-r` | if-shell "[ -x ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh ]" "run-shell '~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh'" "display-message 'tmux-resurrect not installed (press prefix + I)'" | `Tmux\|prefix:C-r` |

</details>
<!-- END KEYBINDINGS -->
