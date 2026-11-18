---
title: "03 — Tmux 3.8 Multiplexing Masterclass"
description: "Process hierarchy, systemd daemon persistence, 90% floating popup tooling hub, Vi copy-mode masterclass, and exhaustive keymap encyclopedia."
tags: [tmux, multiplexer, popups, vi-mode, continuum, resurrect, keymaps, terminal]
---

# 03 — Tmux 3.8 Multiplexing Masterclass

<nav class="breadcrumb-nav">
  <a href="00-ecosystem-architecture.md">00 Ecosystem Architecture</a> •
  <a href="01-wezterm-mastery.md">01 WezTerm Deep-Dive</a> •
  <a href="02-kitty-mastery.md">02 Kitty Architecture</a> •
  <strong>03 Tmux 3.8 Masterclass</strong> •
  <a href="04-neovim-mastery.md">04 Neovim 0.12.6 Guide</a> •
  <a href="05-muscle-memory-drills.md">05 Muscle Memory Drills</a> •
  <a href="06-troubleshooting-runbook.md">06 Troubleshooting Runbook</a>
</nav>

---

## 1. Process Hierarchy & Persistence Architecture

In this ecosystem, Tmux operates as an independent, persistent process supervisor managed by systemd (`systemd --user tmux.service`). Terminal emulators (WezTerm and Kitty) act strictly as ephemeral graphical display surfaces.

```
+-------------------------------------------------------------------------------------------------------+
|                                      SYSTEMD USER DAEMON LAYER                                        |
|                          systemd --user start tmux.service (Socket: ~/.cache/tmux)                    |
+-------------------------------------------------------------------------------------------------------+
                                                   |
                                                   v
+-------------------------------------------------------------------------------------------------------+
|                                         TMUX SERVER PROCESS                                           |
|       * Shared State Engine: Tracks windows, layouts, paste buffers, environment variables           |
|       * Terminal Overrides: Truecolor (Tc), Cursor (Ss/Se), Undercurl (Smulx), OSC52 (Ms)             |
|       * Auto-Persistence: tmux-continuum (every 5 min) + auto-save-session.sh on detach               |
+-------------------------------------------------------------------------------------------------------+
         |                                         |                                         |
         v                                         v                                         v
+-----------------------+                 +-----------------------+                 +-------------------+
|  SESSION 1: "main"    |                 | SESSION 2: "dotfiles" |                 | SESSION 3: "api"  |
|  * @project_root: ... |                 | * @project_root: ...  |                 | * @project_root:  |
+-----------------------+                 +-----------------------+                 +-------------------+
         |                                                                                   |
    +----+----+                                                                         +----+----+
    |         |                                                                         |         |
    v         v                                                                         v         v
+-------+ +-------+                                                                 +-------+ +-------+
| WIN 1 | | WIN 2 |                                                                 | WIN 1 | | WIN 2 |
| "dev" | | "log" |                                                                 | "srv" | | "tst" |
+-------+ +-------+                                                                 +-------+ +-------+
    |                                                                                   |
  +-+-------+                                                                         +-+-------+
  |         |                                                                         |         |
  v         v                                                                         v         v
+-------+ +-------+                                                                 +-------+ +-------+
| PANE 1| | PANE 2|                                                                 | PANE 1| | PANE 2|
| (nvim)| |(build)|                                                                 | (run) | | (db)  |
+-------+ +-------+                                                                 +-------+ +-------+
```

### Decoupled Lifecycle Guarantees:
1. **Zero Session Loss on Emulator Crash:** Closing Kitty (`SUPER+q`) or terminating WezTerm completely detaches the GUI without signaling the underlying shells. Re-opening Kitty (`SUPER+RETURN`) instantly attaches back to the running session via `tmux-smart-attach`.
2. **Dynamic Client Synchronization (`on-client-attached.sh`):**
   When a terminal attaches, Tmux interrogates `/proc/$client_pid/environ` to detect the host profile and sets the ancillary theme vars accordingly (the palette is one shared static file):
   - A WezTerm client keeps the WezTerm markers and TUI config.
   - A Kitty client strips the WezTerm markers and selects the Apple Glass lazygit/lazydocker themes.
3. **Continuous State Snapshotting:**
   - `tmux-continuum`: Saves session trees every 5 minutes (`@continuum-save-interval '5'`).
   - `client-detached` hook: Automatically invokes `auto-save-session.sh`, recording the active session name and running `resurrect/save.sh`.
   - Process restoration: Re-attaches live running instances of `python`, `node`, `cargo`, `lazygit`, and `btop` across system reboots.

---

## 2. Floating Popups & Tooling Hub Architecture

Tmux 3.8 eliminates the need for separate desktop OS windows by leveraging native floating popups (`display-popup`). Popups in this configuration are styled with 24-bit rounded borders in `@thm_blue`, centered geometry, and automatic working-directory isolation.

```
+-------------------------------------------------------------------------------------------------------+
| TMUX WINDOW CANVAS (dimmed)                                                                           |
|                                                                                                       |
|         +-----------------------------------------------------------------------------------+         |
|         |╭──  Project Hub  ────────────────────────────────────────────────────────────────╮|         |
|         |│  > search projects, active sessions, scratchpads...                             │|         |
|         |│                                                                                 │|         |
|         |│  󰓦  main           (active: 2 windows, nvim running)                            │|         |
|         |│  󰓦  atlas          (active: 1 window, obsidian vault)                           │|         |
|         |│  󰓦  ecommerce-api  (detached: 3 windows, branch: feature/cart)                 │|         |
|         |│  󰅩  [New Project]  (clone or open from ~/Projects)                              │|         |
|         |│  󰅩  [Scratchpad]   (throwaway quick dev session)                                │|         |
|         |│                                                                                 │|         |
|         |│  [FZF Interactive Preview: Windows, Active Pane PID, Git Status, Project Root]  │|         |
|         |╰─────────────────────────────────────────────────────────────────────────────────╯|         |
|         +-----------------------------------------------------------------------------------+         |
|                                                                                                       |
+-------------------------------------------------------------------------------------------------------+
```

### Dedicated Tooling Hub Popups:

| Popup Name | Trigger Chord | Dimensions | Target Program & Operational Role |
|---|---|---|---|
| **Project Hub** | `Prefix + f` | 85% W × 85% H | `$HOME/.local/bin/project-hub`: Fast session jumper and project selector. |
| **Session Switcher** | `Prefix + S` | 85% W × 85% H | `~/.config/tmux/session-switcher.sh`: Live switcher across all background sessions. |
| **Git Hub / Lazygit** | `Prefix + g` | 90% W × 90% H | `lazygit`: Surgical staging, interactive rebase, and stash triage in current pane cwd. |
| **GitHub Dashboard** | `Prefix + G` | 90% W × 90% H | `gh dash`: Full pull request and issue management dashboard. |
| **Docker Manager** | `Prefix + d` | 90% W × 90% H | `lazydocker`: Container management, streaming log inspection, and restart hub. |
| **Terminal File Hub** | `Prefix + b` | 90% W × 90% H | `yazi`: High-speed terminal file manager with inline image preview support. |
| **Neovim Pager** | `Prefix + h` | 90% W × 90% H | `scrollback-pager.sh`: Dumps up to 5,000 lines of pane history into a read-only Neovim buffer. |
| **Traceback Jumper** | `Prefix + e` | 85% W × 65% H | `error-jump.sh`: Scrapes compiler errors from scrollback and jumps straight into Neovim. |
| **Project Tasks** | `Prefix + P` / `Prefix + ;` | 60% W × 40% H | `project-task.sh`: FZF menu to run, test, lint, or format the current project. |
| **Throwaway Shell** | `Prefix + u` | 80% W × 75% H | `exec ${SHELL:-zsh}`: Instant scratchpad shell; automatically destroyed on `exit`. |
| **System Monitor** | `Prefix + T` | 90% W × 90% H | `btop`: Process tree, thermal metrics, and core utilization. |
| **GPU Monitor** | `Prefix + V` | 90% W × 90% H | `nvtop`: Dedicated GPU core, memory, and PCIe bandwidth monitor. |
| **Universal Key Dump** | `Prefix + k` | 85% W × 80% H | `keymap-dump.sh`: Interactive fuzzy finder across WezTerm, Tmux, and Neovim keymaps. |

---

## 3. Zero-Mouse Vi Copy-Mode Masterclass

Tmux defaults to Emacs keybindings in copy mode; this stack explicitly activates native Vi emulation via `set -g mode-keys vi` and custom OSC52 clipboard forwarding.

### Step-by-Step Workflow:

```
[Trigger Copy Mode] (Prefix + [ or PageUp)
        |
        v
[Vim Navigation] (h, j, k, l, w, b, e, 0, $, g, G, {, })
        |
        +---> [Search Scrollback] (/ forward, ? backward, n next, N prev)
        |
        v
[Select Text] 
        |---> Character Selection: 'v'
        |---> Whole Line Selection: 'V'
        |---> Block / Rectangular Selection: 'Ctrl+v'
        v
[Yank to Clipboard] ('y')
        |
        v
[OSC52 Transmission -> Wayland wl-copy]
```

### Complete Vi Copy-Mode Command Reference (`-T copy-mode-vi`):

| Key | Operation |
|---|---|
| `v` | Begin character selection (`send-keys -X begin-selection`) |
| `V` | Begin line selection (`send-keys -X select-line`) |
| `Ctrl + v` | Toggle block / rectangular selection mode (`send-keys -X rectangle-toggle`) |
| `y` | Yank selection directly to OS clipboard via OSC52 and exit (`copy-selection-and-cancel`) |
| `Escape` / `q` / `Ctrl + c` | Cancel copy mode (`send-keys -X cancel`) |
| `/` | Incremental search forward |
| `?` | Incremental search backward |
| `n` | Next search match |
| `N` | Previous search match |
| `h` / `j` / `k` / `l` | Cursor left, down, up, right |
| `w` / `b` / `e` | Jump forward word, backward word, end of word |
| `W` / `B` / `E` | Jump forward whitespace word, backward whitespace word, end of whitespace word |
| `0` | Jump to start of line |
| `^` | Jump to first non-whitespace character |
| `$` | Jump to end of line |
| `g` | Jump to top of scrollback history |
| `G` | Jump to bottom of scrollback history |
| `H` / `M` / `L` | Move cursor to top, middle, bottom of visible screen |
| `{` / `}` | Move to previous / next paragraph |
| `Ctrl + u` / `Ctrl + d` | Half-page scroll up / down |
| `Ctrl + b` / `Ctrl + f` | Full-page scroll up / down |
| `PageUp` / `PageDown` | Full-page scroll up / down |

---

## 4. Session Lifecycle & Safe Shutdown Protocol

### Hot Reloading (`Prefix + r`):
Executes `source-file ~/.config/tmux/tmux.conf` and re-attaches active window rails. Re-parsing is completely non-destructive: running shell jobs, editor buffers, and SSH connections are left undisturbed.

### Graceful Server Termination (`Prefix + Q`):
Standard `kill -9` or accidental terminal window closure risks leaving corrupted session states or unsaved editor buffers. Pressing `Prefix + Q` invokes the safe termination pipeline:
1. Prompts for confirmation: `"Save state and shutdown tmux server? (y/n)"`.
2. Triggers `~/.local/bin/tmux-shutdown`.
3. Records the currently focused session into `~/.local/share/tmux/last-session`.
4. Executes `resurrect/save.sh quiet` to flush window layouts, active pane processes, and scrollback histories to disk.
5. If running under systemd, stops `systemd --user tmux.service` cleanly; otherwise, sends an orderly server kill.

---

## 5. Exhaustive Keymap Encyclopedia

Every keybinding verified against the live Tmux server runtime (`tmux list-keys`).

### Group A: Prefix Key Chords (`Ctrl+a` -> Key)

| Chord | Action Description | Underlying Tmux Command |
|---|---|---|
| `Prefix + C-a` | Send literal `Ctrl+a` through to terminal shell | `send-prefix` |
| `Prefix + r` | Reload `~/.config/tmux/tmux.conf` and display toast | `source-file ~/.config/tmux/tmux.conf` |
| `Prefix + \|` | Split pane vertically (side-by-side) in current path | `split-window -h -c "#{pane_current_path}"` |
| `Prefix + -` | Split pane horizontally (stacked) in current path | `split-window -v -c "#{pane_current_path}"` |
| `Prefix + c` | Create new window in current path | `new-window -c "#{pane_current_path}"` |
| `Prefix + x` | Kill current pane with confirmation prompt | `confirm-before -p "kill-pane #P? (y/n)" kill-pane` |
| `Prefix + X` | Kill current pane immediately without confirmation | `kill-pane` |
| `Prefix + z` | Toggle pane zoom state (fullscreen pane) | `resize-pane -Z` |
| `Prefix + Q` | Save state and gracefully terminate Tmux server | `confirm-before ... "run-shell '~/.local/bin/tmux-shutdown'"` |
| `Prefix + D` | Detach active client from session | `detach-client` |
| `Prefix + f` | Open interactive Project Hub floating popup (85% × 85%) | `display-popup -w 85% -h 85% -T " Project Hub " ...` |
| `Prefix + S` | Open interactive Sessions Switcher floating popup | `display-popup -w 85% -h 85% -T " Sessions " ...` |
| `Prefix + s` | Open interactive session tree selector | `choose-tree -Zs` |
| `Prefix + w` | Open interactive window and session zoom tree | `choose-tree -Zw` |
| `Prefix + Tab` | Flip back to previous active session | `switch-client -l` |
| `Prefix + l` | Flip back to previous active window | `last-window` |
| `Prefix + g` | Open floating LazyGit popup (90% × 90%) | `display-popup -w 90% -h 90% -E lazygit` |
| `Prefix + G` | Open floating GitHub Dashboard popup (90% × 90%) | `display-popup -w 90% -h 90% -E "gh dash"` |
| `Prefix + d` | Open floating LazyDocker popup (90% × 90%) | `display-popup -w 90% -h 90% -E lazydocker` |
| `Prefix + b` | Open floating Yazi file manager popup (90% × 90%) | `display-popup -w 90% -h 90% -E yazi` |
| `Prefix + u` | Open floating scratchpad shell popup (80% × 75%) | `display-popup -w 80% -h 75% -E 'exec ${SHELL:-zsh}'` |
| `Prefix + h` | Open active pane history in Neovim floating pager | `display-popup -w 90% -h 90% -E .../scrollback-pager.sh` |
| `Prefix + e` | Open compiler error jumper over pane history | `display-popup -w 85% -h 65% -E .../error-jump.sh` |
| `Prefix + P` / `Prefix + \;`| Open Project Tasks menu (run/test/lint/format) | `display-popup -w 60% -h 40% -E .../project-task.sh` |
| `Prefix + T` | Open Btop system monitor popup (90% × 90%) | `display-popup -w 90% -h 90% -E btop ...` |
| `Prefix + V` | Open Nvtop GPU monitor popup (90% × 90%) | `display-popup -w 90% -h 90% -E nvtop` |
| `Prefix + k` | Open cross-layer keybindings fuzzy finder popup | `display-popup -w 85% -h 80% -E .../keymap-dump.sh` |
| `Prefix + y` | Open interactive paste buffer history selector | `choose-buffer -Z` |
| `Prefix + B` | Toggle Tmux top status bar visibility | `set -g status` |
| `Prefix + =` | Reset panes to even horizontal distribution | `select-layout even-horizontal` |
| `Prefix + Space` | Cycle to next layout | `next-layout` |
| `Prefix + !` | Break active pane into its own window | `break-pane` |
| `Prefix + [` | Enter Vi Copy Mode | `copy-mode` |
| `Prefix + ]` | Paste contents of topmost paste buffer | `paste-buffer` |
| `Prefix + C-s` | Manually persist session state via resurrect | `run-shell .../tmux-resurrect/scripts/save.sh` |
| `Prefix + C-r` | Manually restore session state via resurrect | `run-shell .../tmux-resurrect/scripts/restore.sh` |
| `Prefix + H` / `J` / `K` / `L` | Resize active pane by 5 cells (repeatable) | `resize-pane -L/D/U/R 5` |
| `Prefix + Left` / `Right` | Cycle to previous / next window (repeatable) | `previous-window` / `next-window` |
| `Prefix + p` / `n` | Cycle to previous / next window (repeatable) | `previous-window` / `next-window` |
| `Prefix + 1` .. `9` | Select window by numeric index | `select-window -t :=1 .. :=9` |

### Group B: Root Direct Keybindings (No Prefix Required)

| Key Combination | Action Description | Direct Command |
|---|---|---|
| `Alt + 1` .. `Alt + 9` | Instant jump to window 1 through 9 | `select-window -t 1 .. 9` |
| `Alt + Shift + Left` | Move active window leftwards in the tab list | `swap-window -d -t -1` |
| `Alt + Shift + Right` | Move active window rightwards in the tab list | `swap-window -d -t +1` |
| `Ctrl + h` | Smart navigate split left (delegated to tmux.nvim) | `run-shell "#{@tmux-nvim-navigation-left}"` |
| `Ctrl + j` | Smart navigate split down (delegated to tmux.nvim) | `run-shell "#{@tmux-nvim-navigation-down}"` |
| `Ctrl + k` | Smart navigate split up (delegated to tmux.nvim) | `run-shell "#{@tmux-nvim-navigation-up}"` |
| `Ctrl + l` | Smart navigate split right (delegated to tmux.nvim) | `run-shell "#{@tmux-nvim-navigation-right}"` |
| `Alt + h` | Resize active pane left by 5 columns | `run-shell "#{@tmux-nvim-resize-left}"` |
| `Alt + j` | Resize active pane down by 3 rows | `run-shell "#{@tmux-nvim-resize-down}"` |
| `Alt + k` | Resize active pane up by 3 rows | `run-shell "#{@tmux-nvim-resize-up}"` |
| `Alt + l` | Resize active pane right by 5 columns | `run-shell "#{@tmux-nvim-resize-right}"` |
| `Ctrl + Alt + h` | Swap active pane with left neighbor | `run-shell "#{@tmux-nvim-swap-left}"` |
| `Ctrl + Alt + j` | Swap active pane with lower neighbor | `run-shell "#{@tmux-nvim-swap-down}"` |
| `Ctrl + Alt + k` | Swap active pane with upper neighbor | `run-shell "#{@tmux-nvim-swap-up}"` |
| `Ctrl + Alt + l` | Swap active pane with right neighbor | `run-shell "#{@tmux-nvim-swap-right}"` |
| `PageUp` | Enter copy mode and scroll up (only when outside TUI apps) | `if-shell -b "! ps -o comm= ... grep -qE ..." 'copy-mode -u'` |
