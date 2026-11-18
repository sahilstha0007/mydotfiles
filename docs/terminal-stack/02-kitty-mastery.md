---
title: "02 — Kitty Architecture & Kittens Manual"
description: "OpenGL rendering, Unix socket IPC remote control, tab_bar.py rounded pills HUD, seamless window navigation, and exhaustive kitten manual."
tags: [kitty, kittens, architecture, remote-control, tab-bar, wayland, nightfox, keymaps]
---

# 02 — Kitty Architecture & Kittens Manual

<nav class="breadcrumb-nav">
  <a href="00-ecosystem-architecture.md">00 Ecosystem Architecture</a> •
  <a href="01-wezterm-mastery.md">01 WezTerm Deep-Dive</a> •
  <strong>02 Kitty Architecture</strong> •
  <a href="03-tmux-masterclass.md">03 Tmux 3.8 Masterclass</a> •
  <a href="04-neovim-mastery.md">04 Neovim 0.12.6 Guide</a> •
  <a href="05-muscle-memory-drills.md">05 Muscle Memory Drills</a> •
  <a href="06-troubleshooting-runbook.md">06 Troubleshooting Runbook</a>
</nav>

---

## 1. Rendering Engine & Wayland IPC Architecture

Kitty functions as the primary daily driver terminal in this ecosystem, bound globally to `SUPER+RETURN` in Hyprland. Its configuration is split between standard ML4W defaults (`kitty.conf`) and an isolated, update-proof override file (`~/.config/kitty/custom.conf`).

```
+-------------------------------------------------------------------------------------------------------+
|                                    KITTY RENDERING & IPC PIPELINE                                     |
|                                                                                                       |
|  [Hyprland Window Compositor]                                                                         |
|                |                                                                                      |
|                v                                                                                      |
|  [Wayland Remote Control Socket]                                                                      |
|       * Protocol: allow_remote_control socket-only                                                    |
|       * Abstract Linux Socket: listen_on unix:@kitty-{kitty_pid}                                      |
|       * CLI Access: kitty @ --to unix:@kitty-<pid> <command> (Zero network exposure)                 |
|                |                                                                                      |
|                v                                                                                      |
|  [Hardware-Accelerated Render Engine]                                                                 |
|       * Rasterizer: OpenGL core profile with subpixel anti-aliasing                                   |
|       * Low-Latency Sync: repaint_delay 8, input_delay 2, sync_to_monitor yes (60Hz VSync)           |
|       * Particle Cursor: cursor_trail 3, cursor_trail_decay 0.1 0.4 (Spring physics trail)            |
|                |                                                                                      |
|                v                                                                                      |
|  [Visual Ergonomics & Frosted Glass]                                                                  |
|       * Opacity & Blur: background_opacity 0.88, background_blur 40                                   |
|       * Dimming: inactive_text_alpha 0.85 (Unfocused panes automatically dim)                         |
|       * Palette: Apple Dark Glass (~/.config/kitty/themes/apple-glass.conf)                           |
|                |                                                                                      |
|                v                                                                                      |
|  [Custom Tab Bar & Split Engine]                                                                      |
|       * Engine: tab_bar_style custom -> tab_bar.py (Floating rounded pills HUD)                       |
|       * Layouts: enabled_layouts splits,tall,fat,grid,stack                                           |
|       * Smart Navigation: pass_keys.py (Cross-window navigation between Kitty splits & Neovim)        |
+-------------------------------------------------------------------------------------------------------+
```

### IPC Security & Abstract Unix Domain Sockets:
Rather than opening an insecure TCP port or broad remote control, Kitty isolates its IPC interface:
- `allow_remote_control socket-only`: Banned from accepting control sequences from running terminal programs over standard escape codes.
- `listen_on unix:@kitty-{kitty_pid}`: Generates a process-isolated Linux abstract socket namespace identifier (prefixed with `@`). Abstract sockets do not leave orphan filesystem nodes in `/tmp`.
- External tools (such as `stack-reload`) inspect `/proc/net/unix` for active `@kitty-*` sockets and dispatch commands directly:
  ```bash
  kitty @ --to "unix:@kitty-${PID}" load-config
  ```

---

## 2. Python Custom Tab Bar Architecture (`tab_bar.py`)

Kitty's top tab bar is rendered via an event-driven Python subsystem at `~/.config/kitty/tab_bar.py`. It bypasses Kitty's default string templates in favor of a 24-bit floating pill HUD.

```
+-------------------------------------------------------------------------------------------------------+
|   ▸ 1   nvim [2]     2   lazygit                main   󰚩 2    main*   󰂀 91%   󰥔 21:05  |
|  [Active Tab Pill]     [Inactive Pill]             [Tmux Session] [AI]   [Git]      [Battery]   [Clock]   |
+-------------------------------------------------------------------------------------------------------+
```

### Core Architecture Components:
1. **Pill Drawing Primitive (`_draw_pill`):**
   Renders rounded powerline caps (`\ue0b6` left, `\ue0b4` right) wrapping cell text. The active tab uses the active theme's accent (Apple Dark Glass `#2dd4bf`), while inactive tabs use muted background fills (`#2c2c2e`); colors are resolved live from Kitty's palette rather than hardcoded.
2. **Dynamic Process Badges:**
   Inspects the foreground process running inside the active window of each tab and maps it to a designated Nerd Font icon:
   - `nvim` / `vim` -> `` (`\uf36f`)
   - `lazygit` / `git` -> `` (`\ue702`)
   - `yazi` / `ranger` -> `󰇥` (`\udb80\udde5`)
   - `btop` / `htop` -> `󰓅` (`\udb81\udcc5`)
   - `tmux` -> `` (`\udb83\udfc8`)
   - `docker` / `lazydocker` -> `󰡨` (`\udb82\udc68`)
   - `claude` / `opencode` / `agent` -> `󰚩` (`\udb81\udea9`)
3. **Cached Battery & Hardware Polling (`_POWER_SUPPLY_DIR`):**
   Battery readings are read asynchronously from `/sys/class/power_supply/BAT*` and protected behind a threading lock (`_bat_lock`) with an evaluation throttle (`15.0s`). This completely eliminates redundant disk I/O and kernel context switches during rapid window typing.
4. **Adaptive Width Folding:**
   Before rendering the right-status container, `tab_bar.py` measures remaining terminal columns (`screen.columns - used_tab_cols`). If the terminal window is resized below narrow thresholds, it progressively sheds non-critical segments:
   - *Width < 120 cols:* Drops container counters and battery readout.
   - *Width < 90 cols:* Drops breadcrumb CWD path.
   - *Width < 70 cols:* Collapses right status down to clock only.
5. **WCAG AA Relative Luminance Verification (`_contrast_rgb`):**
   Calculates the relative contrast ratio between foreground text and pill fills:
   $$\text{Contrast} = \frac{L_1 + 0.05}{L_2 + 0.05}$$
   If contrast falls below 4.5:1, the luminance of the text color is automatically inverted to protect readability.

---

## 3. Mastering Kittens

Kittens are modular Python extensions that execute in dedicated child processes or directly within Kitty's runtime.

### 1. Compiler Stack Trace & Error Jumper (`ctrl+shift+p > n`)
Interrogates the visible screen scrollback buffer using `kitten hints --type linenum`. It detects patterns like `src/main.rs:42:15` or `app.py:108`. Pressing the hint badge spawns an instance of Neovim jumped directly to the specified file and line:
```conf
map ctrl+shift+p>n kitten hints --type linenum --linenum-action=self nvim +{line} {path}
```

### 2. Hyperlink & File Path Hints (`ctrl+shift+p > f`)
- `ctrl+shift+p > f`: Scans the terminal screen for absolute and relative filesystem paths, placing letter flags on each match. Pressing the matching key inserts the exact path directly into your active shell prompt without mouse interaction.
- `ctrl+shift+p > shift+f`: Performs the same scan but immediately opens the target path in your default system handler.

### 3. Git Commit Hash Grabber (`ctrl+shift+p > h`)
- `ctrl+shift+p > h`: Extracts 7-to-40 character hexadecimal strings from `git log` or status outputs and pastes them into your shell command line.
- `ctrl+shift+p > shift+h`: Copies the target commit hash straight to the Wayland system clipboard.

### 4. Zero-Mouse QuickSelect (`ctrl+shift+space`)
Executes `kitten hints --type word --program @`. Tags every alphanumeric word on screen with jump letters. Typing the letter instantly writes that word to the OS clipboard.

### 5. Seamless Window Navigation (`pass_keys.py`)
Provides transparent `Ctrl+h/j/k/l` movement across Kitty splits and Neovim editor windows:
```conf
map ctrl+h kitten pass_keys.py left ctrl+h
map ctrl+j kitten pass_keys.py bottom ctrl+j
map ctrl+k kitten pass_keys.py top ctrl+k
map ctrl+l kitten pass_keys.py right ctrl+l
```
When `pass_keys.py` is invoked, it checks if the foreground process in the active window is `nvim`. If yes, it passes the raw `ctrl+h` chord to Neovim. If the cursor is at the edge of the Neovim window (or Neovim is not running), Kitty navigates to the adjacent terminal split.

### 6. Side-by-Side Git Diffing (`ctrl+shift+p > k`)
Spawns Kitty's built-in difftool overlay (`git difftool --tool=kitty --no-prompt`), rendering rich side-by-side terminal syntax-highlighted diffs without leaving the terminal canvas.

### 7. Interactive Command Palette (`ctrl+shift+k` / `ctrl+shift+p > c`)
Opens an interactive, searchable menu (`kitten command_palette`) displaying every configured action, shortcut, and script mapping.

### 8. Pane Synchronisation / Broadcast (`ctrl+shift+b`)
Toggles `kitten broadcast --match-tab state:focused`. Every subsequent keystroke typed is duplicated in parallel across all splits within the current tab (essential for multi-server orchestration).

---

## 4. Exhaustive Keymap Encyclopedia

Every keybinding verified directly from `~/.config/kitty/custom.conf` and `kitty.conf`.

### Group A: Window Splits & Layout Management

| Keybinding | Action Description | Underlying Directive |
|---|---|---|
| `Ctrl + Shift + d` | Split window vertically (side-by-side) | `launch --location=vsplit --cwd=current` |
| `Ctrl + Shift + s` | Split window horizontally (stacked) | `launch --location=hsplit --cwd=current` |
| `Ctrl + Shift + Enter` | Spawn split in current working directory | `launch --cwd=current` |
| `Ctrl + Shift + z` | Toggle Stack layout (maximize active pane) | `toggle_layout stack` |
| `Ctrl + Shift + p > z` | Secondary Stack / Zoom toggle | `toggle_layout stack` |
| `Ctrl + Shift + l` | Cycle to next enabled layout | `next_layout` |
| `Ctrl + Shift + q` | Close active window / split | `close_window` |
| `Ctrl + Shift + F11` | Toggle fullscreen window mode | `toggle_fullscreen` |

### Group B: Seamless & Unconditional Window Navigation

| Keybinding | Action Description | Mechanism |
|---|---|---|
| `Ctrl + h` | Smart navigate split left | `kitten pass_keys.py left ctrl+h` |
| `Ctrl + j` | Smart navigate split down | `kitten pass_keys.py bottom ctrl+j` |
| `Ctrl + k` | Smart navigate split up | `kitten pass_keys.py top ctrl+k` |
| `Ctrl + l` | Smart navigate split right | `kitten pass_keys.py right ctrl+l` |
| `Ctrl + Shift + Left` | Unconditional navigate split left | `neighboring_window left` |
| `Ctrl + Shift + Down` | Unconditional navigate split down | `neighboring_window down` |
| `Ctrl + Shift + Up` | Unconditional navigate split up | `neighboring_window up` |
| `Ctrl + Shift + Right` | Unconditional navigate split right | `neighboring_window right` |

### Group C: Window Positioning & Resizing

| Keybinding | Action Description | Parameters |
|---|---|---|
| `Ctrl + Shift + Alt + Left` | Move active split leftwards | `move_window left` |
| `Ctrl + Shift + Alt + Down` | Move active split downwards | `move_window down` |
| `Ctrl + Shift + Alt + Up` | Move active split upwards | `move_window up` |
| `Ctrl + Shift + Alt + Right` | Move active split rightwards | `move_window right` |
| `Ctrl + Shift + Alt + h` | Resize split narrower | `resize_window narrower 3` |
| `Ctrl + Shift + Alt + l` | Resize split wider | `resize_window wider 3` |
| `Ctrl + Shift + Alt + k` | Resize split taller | `resize_window taller 3` |
| `Ctrl + Shift + Alt + j` | Resize split shorter | `resize_window shorter 3` |
| `Ctrl + Shift + Alt + r` | Reset split dimensions to equal | `resize_window reset` |

### Group D: Tab Navigation & Management

| Keybinding | Action Description | Command |
|---|---|---|
| `Ctrl + Shift + t` | Create new tab in current working directory | `launch --type=tab --cwd=current` |
| `Ctrl + Shift + w` | Close active tab | `close_tab` |
| `Ctrl + Shift + ]` | Step to next tab | `next_tab` |
| `Ctrl + Shift + [` | Step to previous tab | `previous_tab` |
| `Ctrl + Shift + 1` | Switch directly to tab 1 | `goto_tab 1` |
| `Ctrl + Shift + 2` | Switch directly to tab 2 | `goto_tab 2` |
| `Ctrl + Shift + 3` | Switch directly to tab 3 | `goto_tab 3` |
| `Ctrl + Shift + 4` | Switch directly to tab 4 | `goto_tab 4` |
| `Ctrl + Shift + 5` | Switch directly to tab 5 | `goto_tab 5` |
| `Ctrl + Shift + ,` | Reorder active tab leftwards | `move_tab_backward` |
| `Ctrl + Shift + .` | Reorder active tab rightwards | `move_tab_forward` |
| `Ctrl + Shift + Alt + t` | Interactively set custom tab title | `set_tab_title` |
| `Ctrl + Shift + Tab` | Interactive fuzzy tab & window switcher | `launch --type=overlay .../tab-switcher.sh` |
| `Ctrl + Shift + p > t` | Secondary fuzzy tab switcher shortcut | `launch --type=overlay .../tab-switcher.sh` |

### Group E: Scrollback Pagers & Floating TUI Overlays

| Keybinding | Action Description | Target Executable |
|---|---|---|
| `Ctrl + Shift + f` | Fuzzy search scrollback with FZF overlay | `fzf --no-sort --exact -i --reverse` |
| `Ctrl + Shift + h` | Interactive Neovim scrollback pager | `~/.config/kitty/scripts/nvim-scrollback-pager.sh` |
| `Ctrl + Shift + g` | Floating LazyGit overlay | `lazygit` |
| `Ctrl + Shift + p > g` | Secondary LazyGit overlay | `lazygit` |
| `Ctrl + Shift + p > d` | Floating LazyDocker overlay | `lazydocker` |
| `Ctrl + Shift + y` | Floating Yazi file manager overlay | `yazi` |
| `Ctrl + Shift + p > y` | Secondary Yazi overlay | `yazi` |
| `Ctrl + Shift + m` | Floating Btop monitor (Apple Dark Glass theme) | `btop -c ~/.config/btop/btop-apple-glass.conf` |
| `Ctrl + Shift + p > m` | Secondary Btop overlay | `btop -c ~/.config/btop/btop-apple-glass.conf` |
| `Ctrl + Shift + o` | Interactive Project Hub overlay | `~/.config/kitty/scripts/project-hub.sh` |
| `Ctrl + Shift + p > p` | Secondary Project Hub overlay | `~/.config/kitty/scripts/project-hub.sh` |
| `Ctrl + Shift + b` | Broadcast typing across all tab splits | `kitten broadcast --match-tab state:focused` |
| `Ctrl + Shift + k` | Interactive Command Palette | `kitten command_palette` |
| `Ctrl + Shift + p > c` | Secondary Command Palette | `kitten command_palette` |
| `Ctrl + Shift + u` | Unicode symbol and emoji input picker | `kitten unicode_input` |
| `Ctrl + Shift + p > k` | Side-by-side terminal Git difftool | `git difftool --tool=kitty --no-prompt` |

### Group F: The Hints Suite

| Shortcut Chord | Target Type | Action Behavior |
|---|---|---|
| `Ctrl + Shift + Space` | Word | QuickSelect word directly to clipboard (`@`) |
| `Ctrl + Shift + e` | URL | Open matching URL in default web browser |
| `Ctrl + Shift + p > n` | Line Number | Open compiler error in Neovim at exact line (`+{line} {path}`) |
| `Ctrl + Shift + p > f` | File Path | Insert matching path into shell prompt (`-`) |
| `Ctrl + Shift + p > Shift + f` | File Path | Open matching path in default system handler |
| `Ctrl + Shift + p > h` | Git Hash | Insert matching commit hash into shell prompt (`-`) |
| `Ctrl + Shift + p > Shift + h` | Git Hash | Copy matching commit hash to system clipboard (`@`) |
| `Ctrl + Shift + p > l` | Text Line | Insert matching line into shell prompt (`-`) |
| `Ctrl + Shift + p > Shift + l` | Text Line | Copy matching line to system clipboard (`@`) |
| `Ctrl + Shift + p > w` | Word | Insert matching word into shell prompt (`-`) |
| `Ctrl + Shift + p > i` | IP Address | Insert matching IPv4/IPv6 into shell prompt (`-`) |

### Group G: Dynamic Opacity & Font Sizing

| Shortcut Chord | Action Description | Delta / Value |
|---|---|---|
| `Ctrl + Shift + a > m` | Increase background opacity | `+0.05` |
| `Ctrl + Shift + a > l` | Decrease background opacity | `-0.05` |
| `Ctrl + Shift + a > d` | Revert background opacity to default | `0.85` |
| `Ctrl + Shift + a > 1` | Set background fully opaque | `1.0` |
| `Ctrl + Shift + =` / `+` | Increase font size across all windows | `+1.0pt` |
| `Ctrl + Shift + -` | Decrease font size across all windows | `-1.0pt` |
| `Ctrl + Shift + Backspace`| Reset font size to default | `12.0pt` |
