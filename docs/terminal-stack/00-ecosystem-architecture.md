---
title: "00 — Master Index & The 5-Layer Ecosystem Architecture"
description: "End-to-end keystroke pipeline, ownership contracts, and cross-layer mechanics across Hyprland, WezTerm, Kitty, Tmux, and Neovim."
tags: [terminal-stack, architecture, contracts, wezterm, kitty, tmux, nvim, wayland, linux]
---

# 00 — Master Index & The 5-Layer Ecosystem Architecture

<nav class="breadcrumb-nav">
  <strong>Master Navigation:</strong>
  <span>00 Ecosystem Architecture</span> •
  <a href="01-wezterm-mastery.md">01 WezTerm Deep-Dive</a> •
  <a href="02-kitty-mastery.md">02 Kitty Architecture</a> •
  <a href="03-tmux-masterclass.md">03 Tmux 3.8 Masterclass</a> •
  <a href="04-neovim-mastery.md">04 Neovim 0.12.6 Guide</a> •
  <a href="05-muscle-memory-drills.md">05 Muscle Memory Drills</a> •
  <a href="06-troubleshooting-runbook.md">06 Troubleshooting Runbook</a>
</nav>

---

## 1. Executive Architecture Summary

This documentation suite establishes the authoritative, verified engineering specification for the 5-layer terminal and editing stack deployed across Arch Linux / Hyprland Wayland environments. 

The stack consists of five tightly orchestrated execution layers:
1. **Compositor & Display Server:** Hyprland Wayland compositor (`hyprland.lua`, `custom.lua`).
2. **Terminal Emulators (Dual-Engine):**
   - **Kitty (0.50.0):** Primary daily driver (`SUPER+RETURN`), Apple Dark Glass palette (`themes/apple-glass.conf`), IPC socket control, custom Python tab bar HUD (`tab_bar.py`).
   - **WezTerm:** GPU dev workstation (`SUPER+SHIFT+RETURN`), WebGPU backend, static committed palette, modal key tables.
3. **Terminal Multiplexer:** Tmux (3.8 persistent user daemon via systemd), `C-a` prefix, floating popup tooling hubs, OSC52 clipboard bridge.
4. **Editor:** Neovim (0.12.6), native `vim.loader` bytecode cache, modular plugin architecture (`opts_extend`), single-picker Snacks architecture, zero-latency window navigation.
5. **Interactive Shell:** Zsh (~56ms cached startup, measured with `hyperfine 'zsh -i -c exit'`), Oh-My-Posh prompts, Atuin SQLite history, and unified task dispatchers (`project-hub`, `project-task`).

```
+-------------------------------------------------------------------------------------------------------+
|                                    HYPRLAND WAYLAND COMPOSITOR                                        |
|                          Global Window Rules • Fractional Scaling • evdev                             |
+-------------------------------------------------------------------------------------------------------+
                                                   |
                        +--------------------------+--------------------------+
                        | (SUPER+RETURN)                                      | (SUPER+SHIFT+RETURN)
                        v                                                     v
+-----------------------------------------------+     +-----------------------------------------------+
|             KITTY TERMINAL (0.50.0)           |     |                    WEZTERM                    |
|  * Profile: Dev Daily Driver (Apple Glass)    |     |  * Profile: Workstation (Static Apple Glass) |
|  * Rendering: OpenGL / 60Hz VSync             |     |  * Rendering: WebGPU LowPower (Rust engine)   |
|  * IPC: Unix Domain Sockets (@kitty-{pid})    |     |  * Input: Leader Key (Ctrl+Alt+Space)         |
|  * Chrome: tab_bar.py Rounded Pills HUD       |     |  * Chrome: Dynamic Lua Right-Status HUD       |
+-----------------------------------------------+     +-----------------------------------------------+
                        \                                                     /
                         +--------------------------+------------------------+
                                                    | (ptmx / pts slave pipe)
                                                    v
+-------------------------------------------------------------------------------------------------------+
|                                        TMUX MULTIPLEXER (3.8)                                         |
|  * Daemon: systemd --user tmux.service (Persistent socket: ~/.cache/tmux)                              |
|  * Prefix: Ctrl+a (Secondary: None)                                                                   |
|  * Status: Transparent 24-bit Glass Bar (No background fill; wallpaper backdrop passes through)       |
|  * Tooling Hub: 90% Floating Popups (lazygit, lazydocker, yazi, project-hub, error-jump, pager)       |
+-------------------------------------------------------------------------------------------------------+
                                                    |
                                                    v
+-------------------------------------------------------------------------------------------------------+
|                                        NEOVIM EDITOR (0.12.6)                                         |
|  * Core: init.lua -> vim.loader.enable() -> globals.lua -> options.lua -> lazy.nvim                  |
|  * Colorscheme: OSC4 / file-polling reader of the active terminal's committed palette                |
|  * LSP: 13 Language Servers (native vim.lsp.enable, blink.cmp capabilities, file watcher disabled)  |
|  * Navigation: snacks.picker (unified telescope replacement), flash.nvim (s/S), oil.nvim (-)         |
+-------------------------------------------------------------------------------------------------------+
                                                    |
                                                    v
+-------------------------------------------------------------------------------------------------------+
|                                      RUNNING PROCESSES & BUFFERS                                      |
|           Active Language Server • Running Code • Interactive REPL • Child Zsh Shell                  |
+-------------------------------------------------------------------------------------------------------+
```

---

## 2. End-to-End Keystroke & Signal Pipeline

Every keystroke generated by physical hardware undergoes a deterministic, multi-stage traversal before causing an edit or buffer transformation. Understanding the exact pipeline prevents keymap collisions and latency spikes:

```mermaid
sequenceDiagram
    autonumber
    actor User as User Keyboard
    participant Kernel as Linux Kernel (evdev/libinput)
    participant Compositor as Hyprland (Wayland)
    participant Terminal as Emulator (WezTerm / Kitty)
    participant PTY as Unix PTY Master/Slave
    participant Tmux as Tmux Multiplexer
    participant Nvim as Neovim 0.12.6
    participant App as Active Buffer / LSP

    User->>Kernel: Physical Key Depressed (Scancode)
    Kernel->>Compositor: Process evdev event into XKB Keysym
    alt Handled by Hyprland
        Compositor->>Compositor: Matched SUPER binding (e.g. SUPER+RETURN)
        Note over Compositor: Spawns terminal window; drops event
    else Forwarded to Window
        Compositor->>Terminal: wl_keyboard::key event over Wayland socket
        alt Intercepted by Terminal
            Terminal->>Terminal: Matches terminal shortcut or modal key table
            Note over Terminal: Executes action (e.g. QuickSelect, Tab Switch)
        else Forwarded into PTY
            Terminal->>PTY: Encodes into ANSI / CSI u / xterm escape bytes
            PTY->>Tmux: Raw byte stream received on master fd
            alt Intercepted by Tmux
                Tmux->>Tmux: Matches Prefix (C-a) or Root Table (M-1..9)
                Note over Tmux: Executes multiplexer command (popup, split)
            else Forwarded to Pane
                Tmux->>Nvim: Transmits escape sequence across pts
                alt Intercepted by Neovim
                    Nvim->>Nvim: Matches normal/visual/insert mode keymap
                    Nvim->>App: Executes buffer edit, AST jump, or LSP action
                else Unbound in Neovim
                    Nvim->>App: Default Vim movement / character insert
                end
            end
        end
    end
```

### Detailed Pipeline Mechanics:
1. **Linux evdev & libinput:** Translates raw hardware scancodes into Linux input events (`EV_KEY`).
2. **Hyprland Compositor:** Catches modifiers specified in `~/.config/hypr/custom.lua` or system rules. Keys using `SUPER` (`Mod4`) are intercepted here and never enter the terminal.
3. **Terminal Input Decoder:**
   - **WezTerm:** Evaluates default key table or leader chord (`Ctrl+Alt+Space`). If a modal key table is active (e.g. `resize_pane`, `workspaces`), the key is consumed by the table.
   - **Kitty:** Evaluates `custom.conf` mappings. Features like `pass_keys.py` examine whether the active process is Neovim before deciding to forward or consume.
4. **PTY Translation:** Encodes keystrokes into ANSI escape sequences or CSI u extended key format (`set -g extended-keys on` in Tmux preserves chords).
5. **Tmux Multiplexer Parser:** Inspects the byte stream against:
   - Root table (`-n` binds like `M-1`..`M-9`, `PageUp`).
   - Prefix table (`Ctrl+a` followed by chord).
   - If unmapped, forwards unchanged to the pane slave PTY.
6. **Neovim Event Loop (`libuv`):** Neovim reads standard input via its `uv` event loop, processes mode-specific maps (`keymaps.lua`, plugin specs), and dispatches actions to Treesitter, LSP clients, or the buffer text engine.

---

## 3. The Responsibility Mental Model

To prevent overlap, double chrome, and conflicting hotkeys, each layer owns a strict, non-negotiable domain of responsibility:

| Domain | Responsible Layer | Implementation Mechanism | Anti-Patterns (BANNED) |
|---|---|---|---|
| **OS Windowing & Tiling** | **Hyprland** | `hyprctl`, `windowrule = workspace`, `border_size = 0` | Resizing OS windows inside terminal configs. |
| **GPU Rasterization & Fonts** | **Terminal Emulator** | WebGPU (WezTerm) / OpenGL (Kitty), HarfBuzz, FontConfig | Software rendering, terminal font emulations in editor. |
| **Theme Palette** | **Committed config** | `kitty/themes/apple-glass.conf` is the source; each tool's palette file is static | Regenerating a palette from a wallpaper or running a theme daemon. |
| **Terminal Host Signals** | **Terminal Emulator** | WezTerm Right-Status (`events/right-status.lua`), Kitty Status | Repeating CPU/RAM/Battery metrics in Tmux or Neovim. |
| **Process Multiplexing** | **Tmux** | `systemd --user tmux.service`, persistent server socket | Spawning nested terminals instead of Tmux windows. |
| **Working Project Context** | **Tmux Status Right** | `status-right.sh`: Git branch/dirty, coding agents, containers | Duplicating Git info when Neovim Lualine is focused. |
| **Floating Scratchpads** | **Tmux Popups** | `display-popup -w 90% -h 90%` (`lazygit`, `project-hub`) | Opening separate OS windows for quick git/shell tasks. |
| **AST & Text Manipulation** | **Neovim** | Treesitter, `mini.ai`, `mini.surround`, `flash.nvim` | Using mouse or arrow keys for surgical code edits. |
| **Language Diagnostics** | **Neovim LSP** | 13 native servers, `blink.cmp`, `trouble.nvim` | Running linters in background terminal panes manually. |
| **Command Execution** | **Shell (Zsh)** | Zsh completion, Atuin SQLite history, aliases | Typing full paths or repeatedly re-running commands. |

---

## 4. The 5 Universal Cross-Layer Contracts

### Contract 1: Zero-Latency Smart Navigation (`Ctrl+h/j/k/l`)
Pane and split navigation feels like a single continuous canvas across Neovim, Tmux, and Kitty splits.

- **Neovim & Tmux:** Handled by `aserowy/tmux.nvim`. When you press `Ctrl+h`, Neovim checks if there is a window to the left (`vim.cmd.wincmd('h')`). If the cursor is already at the leftmost Neovim split edge, `tmux.nvim` sends a pane navigation command to Tmux (`select-pane -L`).
- **Outside Tmux (Kitty Direct Mode):** When running standalone in Kitty without Tmux, `lua/plugins/editor/tmux.lua` provides native fallback:
  ```lua
  if not vim.env.TMUX and (vim.env.KITTY_WINDOW_ID or vim.env.TERMINAL_STACK_PROFILE == 'kitty') then
    local dir_map = { h = 'left', j = 'bottom', k = 'top', l = 'right' }
    for key, dir in pairs(dir_map) do
      vim.keymap.set({ 'n', 't' }, '<C-' .. key .. '>', function()
        local cur_win = vim.api.nvim_get_current_win()
        vim.cmd.wincmd(key)
        if vim.api.nvim_get_current_win() == cur_win then
          pcall(vim.fn.system, { 'kitty', '@', 'focus-window', '-m', 'neighbor:' .. dir })
        end
      end)
    end
  end
  ```
- **WezTerm Guarantee:** WezTerm explicitly leaves bare `Ctrl+h/j/k/l` completely unmapped, ensuring the keystroke passes straight through to Tmux and Neovim without latency.

### Contract 2: Universal Zoom Parity
Maximizing the current focal view is synchronized across all layers:
- **Neovim Window Zoom:** `<leader>wm` or `<leader>Z` invokes `Snacks.zen.zoom()`, expanding the Neovim split to fill the entire editor canvas without closing other buffers.
- **Tmux Pane Zoom:** `Prefix + z` (or `C-a z`) zooms the active Tmux pane to consume 100% of the terminal window.
- **Synchronized Zoom (`<leader>wz`):** The dual-layer zoom trigger. It maximizes the current Neovim buffer AND instructs the outer Tmux session to zoom the active pane via `tmux resize-pane -Z`:
  ```lua
  keymap.set('n', '<leader>wz', function()
    require('snacks').zen.zoom()
    if vim.env.TMUX and vim.env.TMUX ~= '' then
      vim.fn.system 'tmux resize-pane -Z'
    end
  end, { desc = 'Zoom Window & Tmux Pane' })
  ```
- **Kitty Native Stack Zoom:** `ctrl+shift+z` toggles `toggle_layout stack`.

### Contract 3: Directional Split Parity
The visual geometry of splits matches across tools:
- **Vertical Split (Side-by-Side):**
  - Neovim: `<leader>|` (`:vsplit`)
  - Tmux: `Prefix + |` (`split-window -h`)
  - Kitty: `ctrl+shift+d` (`launch --location=vsplit --cwd=current`)
- **Horizontal Split (Stacked):**
  - Neovim: `<leader>-` (`:split`)
  - Tmux: `Prefix + -` (`split-window -v`)
  - Kitty: `ctrl+shift+s` (`launch --location=hsplit --cwd=current`)

### Contract 4: TrueColor & Frosted Glass Transparency Pipeline
The transparent background is rendered strictly from the outermost terminal container inward, preventing muddy double-composited backgrounds:
1. **Compositor / Terminal Layer:**
   - WezTerm sets `window_background_opacity = backdrops.opacity` (default 0.82) and paints artwork backdrops with adjustable wash (`SUPER+o`).
   - Kitty sets `background_opacity 0.88` and `background_blur 40`.
2. **Tmux Multiplexer Layer:**
   - Tmux has no internal alpha engine. Transparency is achieved by setting `status-style "fg=#{@thm_fg},bg=none"`. Every segment is foreground-only text floating directly over the terminal emulator's glass.
3. **Neovim Editor Layer:**
   - `vim.opt.termguicolors = true` ensures full 24-bit RGB rendering.
   - Catppuccin theme initializes with `transparent_background = true`.
   - Floating windows use minimal blend (`winblend = 10`, `pumblend = 10`) so float dialogs pop cleanly with a subtle frost rather than an opaque rectangle.
   - SGR undercurls (`Smulx`) and colored underlines (`Setulc`) survive Tmux through strict `terminal-overrides`.

### Contract 5: Universal OSC52 Clipboard Pipeline
Clipboard synchronisation operates seamlessly across local displays, Tmux multiplexers, and remote SSH tunnels:
- **Terminal Emulator:** WezTerm and Kitty support OSC 52 escape sequences natively; Kitty's `clipboard_control write-clipboard write-primary` is write-only (no clipboard-read capability).
- **Tmux Configuration:** 
  ```tmux
  set -s set-clipboard on
  set -s terminal-overrides ',*:Ms=\E]52;%p1%s;%p2%s\007'
  bind -T copy-mode-vi y send -X copy-selection-and-cancel
  ```
  Yanking text in Tmux copy-mode automatically emits an OSC 52 sequence containing Base64-encoded text to the outer emulator, which writes it to the Wayland system clipboard (`wl-copy`).
- **Neovim Configuration:** Neovim schedules `vim.opt.clipboard = 'unnamedplus'` after `UiEnter`. In SSH or headless environments, Neovim falls back directly to native OSC52 emission via `vim.ui.clipboard.osc52`.

---

## 5. Navigation & Master Documentation Index

| Page | Document Identifier | Primary Contents & Focus |
|---|---|---|
| **Page 0** | [`00-ecosystem-architecture.md`](00-ecosystem-architecture.md) | Pipeline sequence diagram, responsibility mental model, 5 universal contracts. |
| **Page 1** | [`01-wezterm-mastery.md`](01-wezterm-mastery.md) | WebGPU pipeline, modal key tables state machine, Lua HUD, complete keymap encyclopedia. |
| **Page 2** | [`02-kitty-mastery.md`](02-kitty-mastery.md) | IPC socket architecture, `tab_bar.py` renderer breakdown, kitten deep-dive, keymaps. |
| **Page 3** | [`03-tmux-masterclass.md`](03-tmux-masterclass.md) | Process hierarchy, floating popup engine, Vi copy-mode guide, session lifecycles. |
| **Page 4** | [`04-neovim-mastery.md`](04-neovim-mastery.md) | Boot sequence, 10 leader groups, AST editing, live runtime keymap dictionary (500+). |
| **Page 5** | [`05-muscle-memory-drills.md`](05-muscle-memory-drills.md) | 8 end-to-end practical scenarios with keypress-by-keypress operational walkthroughs. |
| **Page 6** | [`06-troubleshooting-runbook.md`](06-troubleshooting-runbook.md) | LSP floats, CSI u escape sequences, Wayland display artifacts, verification scripts. |

---

## 6. The Prompt Layer — Oh-My-Posh

The shell is layer 5, and its visible surface is the Oh-My-Posh prompt. Prompt selection is **profile-driven** and lives entirely in `shell/zshrc`; neither terminal emulator draws the prompt itself.

| Profile | Selected by | Config file | Cached init |
|---|---|---|---|
| Kitty (dev) | `TERMINAL_STACK_PROFILE=kitty` or `KITTY_WINDOW_ID` | `~/.config/ohmyposh/zen-apple-glass.toml` | `~/.cache/zsh-cache/omp-apple-glass.zsh` |
| WezTerm (immersion) | `TERMINAL_STACK_PROFILE=wezterm` or `WEZTERM_PANE` | `~/.config/ohmyposh/zen.toml` | `~/.cache/zsh-cache/omp-zen.zsh` |
| Generic / SSH / TTY fallback | neither terminal detected | `~/.config/ohmyposh/zen.toml` | `~/.cache/zsh-cache/omp-fallback.zsh` |

- **Detection order (`shell/zshrc:188-199`):** an explicit `TERMINAL_STACK_PROFILE` (`kitty` or `wezterm`) wins first, so attaching to a shared Tmux server from a different terminal is not hijacked by a stale `KITTY_WINDOW_ID` / `WEZTERM_PANE` captured when the server started; those environment variables are the fallback. The three `_omp_init_cached` call sites are at `shell/zshrc:210,262,309`.
- **Cached init (`shell/zshrc:137-152,201-206`):** `_omp_init_cached` calls `_zsh_cached_init`, which writes `oh-my-posh init zsh --config <cfg>` into a cache file and reuses it until the cache is missing/empty or the binary or config is newer. Each shell then exports a **fresh `POSH_SESSION_ID`** from `/proc/sys/kernel/random/uuid`, so a cached init is not shared verbatim across shells. The three branches use distinct cache files (`omp-apple-glass.zsh`, `omp-zen.zsh`, `omp-fallback.zsh`), so switching profile cannot reuse another profile's prompt.
- **`zen.toml` is generated from static hexes, not hand-edited (`.config/ohmyposh/omp-palette.sh:2-20`):** the script substitutes `@@ACCENT@@`, `@@OK@@`, `@@SOFT@@`, `@@ERR@@` in `zen.template.toml` with the committed Apple Dark Glass hexes hard-coded at `omp-palette.sh:11-14` (`#2dd4bf`, `#7dce8b`, `#f2d97a`, `#ff6b6b`) and writes `zen.toml`. There is no wallpaper-derived input and no caller that regenerates it on theme changes — the colors are static committed config. To change the prompt, edit `zen.template.toml`, not the generated output.
- **Verify:** `bash tests/shell/check-omp-init.sh` asserts that every referenced config exists, parses, and has no foreground/background collision, and that the detection order, per-branch config/cache mapping, and cache distinctness above all hold.

---

## 7. Static Theme Palette (v10, 2026-11-17)

The stack no longer derives colors from the wallpaper. Commit `3cf0f9b` (v10) removed the
entire matugen/sanitizer/sync-wallpaper chain: wallpaper-driven recoloring traded away
for a committed, static Apple Glass palette and faster startup. No wallpaper change
propagates to any terminal layer.

- **Single source of truth:** `~/.config/kitty/themes/apple-glass.conf` holds the
  canonical hexes (bg `#1c1c1e`, fg `#f5f5f7`, accent `#2dd4bf`). `custom.conf` includes
  it directly; kitty no longer includes any generated `colors-matugen*.conf`.
- **Consumers derive from that static file:** `wezterm/colors/custom.lua` and
  `matugen.lua` are committed static tables; tmux sources the committed
  `tmux/colors-apple-glass.conf` directly for every profile;
  `ohmyposh/omp-palette.sh` writes committed hexes into `zen.toml`.
- **Removed:** `.config/matugen/`, `bin/kitty-colors-sanitize`,
  `sync-wallpaper.sh`, kitty `colors-matugen.conf` / `.validated.conf`, OMP `colors.json`.
- **Verify:** `bin/devcheck` (kitty config parse + palette-consistency + contrast gates)
  and `install.sh --doctor`. No daemon/installer can drift the theme — it is static
  committed config. `stack-reload` reloads the layers; there is no palette regeneration.
