---
title: "06 — Hardware, Compositor & Troubleshooting Runbook"
description: "Resolving sticky LSP floats, escape sequence collisions (CSI u), Wayland fractional scaling quirks, and running quality verification gates."
tags: [troubleshooting, runbook, wayland, hyprland, lsp, csi-u, devcheck, verification]
---

# 06 — Hardware, Compositor & Troubleshooting Runbook

<nav class="breadcrumb-nav">
  <a href="00-ecosystem-architecture.md">00 Ecosystem Architecture</a> •
  <a href="01-wezterm-mastery.md">01 WezTerm Deep-Dive</a> •
  <a href="02-kitty-mastery.md">02 Kitty Architecture</a> •
  <a href="03-tmux-masterclass.md">03 Tmux 3.8 Masterclass</a> •
  <a href="04-neovim-mastery.md">04 Neovim 0.12.6 Guide</a> •
  <a href="05-muscle-memory-drills.md">05 Muscle Memory Drills</a> •
  <strong>06 Troubleshooting Runbook</strong>
</nav>

---

## 1. Sticky Signature & LSP Floating Windows

### Incident Symptom:
Floating hover documentation windows, signature help boxes, or diagnostic preview floats become stranded on screen, failing to close when moving the cursor or switching windows.

### Root Cause Analysis:
Language servers (especially TypeScript `vtsls`, Python `basedpyright`, and `lua_ls`) emit repeated `textDocument/signatureHelp` and hover responses during rapid typing. If an LSP response arrives right as cursor focus shifts or if a plugin lacks an explicit dismissal event handler, Neovim's window tree retains the floating window ID as an active unlinked surface.

### Implemented Architectural Fixes:
1. **Aggressive `<Esc>` Floating Window Sweeper (`lua/keymaps.lua`):**
   In this configuration, pressing `<Esc>` in Normal mode is bound to a tab-wide window sweeper:
   ```lua
   keymap.set('n', '<Esc>', function()
     vim.cmd 'nohlsearch'
     for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
       local config = vim.api.nvim_win_get_config(win)
       if config.relative ~= '' and not config.external then
         local buf = vim.api.nvim_win_get_buf(win)
         local ft = vim.bo[buf].filetype
         if ft ~= 'snacks_notif' and ft ~= 'snacks_dashboard' then
           pcall(vim.api.nvim_win_close, win, false)
         end
       end
     end
   end, { desc = 'Clear highlights and close floating windows' })
   ```
   Pressing `<Esc>` sweeps every floating window on the current tabpage and instantly deletes it, exempting only passive notifications (`snacks_notif`) and the dashboard.
2. **Buffer-Local Auto-Dismiss Autocmd (`lua/keymaps.lua`):**
   Special floating filetypes (`qf`, `help`, `man`, `lspinfo`, `trouble`) automatically attach local `q` and `<Esc>` close handlers on creation.
3. **Explicit Signature Help Triggers (`lua/plugins/coding/lspconfig.lua`):**
   Automatic signature help popups on every keystroke are suppressed in favor of explicit manual inspection:
   - Insert Mode: `<C-k>`
   - Normal Mode: `<leader>ck`

---

## 2. Terminal Escape Sequence Passthrough & `CSI u` Collisions

### Incident Symptom:
Keystrokes involving `Ctrl+Shift+<letter>`, `Ctrl+Arrow`, or modified function keys fail inside Tmux or Neovim, producing plain characters or behaving like unmodified keystrokes.

### Root Cause Analysis:
Legacy ASCII terminals send the exact same byte sequences for certain modified keys (e.g. `Tab` and `Ctrl+i` are both byte `0x09`). Without extended keyboard protocols, terminal multiplexers cannot distinguish whether a user pressed `Ctrl+Up` (Neovim split resize) or `Up` (readline history).

### Implemented Architectural Fixes:
1. **Kitty Keyboard Protocol in WezTerm (`config/general.lua`):**
   ```lua
   enable_kitty_keyboard = true
   ```
   Enables full disambiguation of key chords using the CSI u / progressive enhancement protocol.
2. **Extended Keys Support in Tmux (`tmux.conf`):**
   ```tmux
   set -g extended-keys on
   ```
   Instructs Tmux to parse extended escape sequences and forward them intact across the pseudo-terminal pipe into Neovim.
3. **Atomic Terminal Overrides (`tmux.conf`):**
   Configured with atomic `set -s` (preventing duplicate accumulation on reload):
   ```tmux
   set -s terminal-overrides ',*:Tc,*:Ss=\E[%p1%d q:Se=\E[ q,*:Smulx=\E[4::%p1%dm,*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m,*:Ms=\E]52;%p1%s;%p2%s\007'
   ```
   - `Tc`: 24-bit TrueColor passthrough.
   - `Ss` / `Se`: Modal cursor shaping (steady beam in insert mode, block in normal mode).
   - `Smulx`: Modern curly undercurls for syntax errors.
   - `Setulc`: Colored undercurls (red for error, yellow for warning).
   - `Ms`: Base64 OSC 52 clipboard forwarding.

---

## 3. Wayland & Hyprland Display Quirks

### 1. Window Border Double Chrome:
- **Symptom:** Both Hyprland and WezTerm draw accent borders, resulting in a misaligned double border.
- **Fix:** In `config/appearance.lua`, `window_decorations = 'NONE'` disables WezTerm's internal borders. Hyprland manages all geometry via the `wezterm-noborder` class rule.

### 2. Fractional Scaling Text Blurriness:
- **Symptom:** Text appears slightly blurred or fuzzy on 1.25x or 1.5x HiDPI displays.
- **Fix:** 
  - Kitty runs natively on Wayland (`display_server wayland`).
  - Font sizes in WezTerm (`config/fonts.lua`) use fractional points (`9.75pt`) tuned for pixel grids.
  - In Hyprland (`~/.config/hypr/hyprland.conf`), ensure fractional scaling uses the Wayland wp-fractional-scale protocol rather than XWayland bitmap stretching.

### 3. Theme colors stale after a palette edit:
- **Symptom:** a committed Apple Glass hex changed, but tmux/kitty/WezTerm still show the old palette. Wallpaper switching is never the cause — palettes are static files.
- **Fix:** Run the non-destructive stack reloader:
  ```bash
  stack-reload
  ```
  `stack-reload` sends `load-config` over running `@kitty-*` sockets (falling back to `SIGUSR1`), sources `tmux.conf`, and touches `wezterm.lua` to trip its mtime watch. It does not re-exec Zsh — see section 6.

---

## 4. Quality Verification Pipeline & Gate Enforcement

The repository maintains automated verification gates to prevent documentation drift and configuration breakage.

```
+-------------------------------------------------------------------------------------------------------+
|                                    QUALITY VERIFICATION PIPELINE                                      |
+-------------------------------------------------------------------------------------------------------+
|  [devcheck]                 Fast-Tier Gate (40 checks): Specs, linters, keymaps, parity, syntax       |
|  [devcheck --all]           Slow-Tier Gate: Clean-clone harness, Wiki lint, /tmp leak checks          |
|  [check_docs_vs_config.py]  Validates Obsidian documentation tables against live WezTerm & Tmux dumps  |
|  [sync-keybindings --check] Asserts 1:1 parity between live configs, cheatsheet, and README.md       |
|  [stack-reload]             Zero-downtime hot reload across Kitty sockets, Tmux, and WezTerm          |
+-------------------------------------------------------------------------------------------------------+
```

### Running Fast-Tier Quality Gates:
To verify the entire system after modifying any config or keymap:
```bash
devcheck
```
*Expected Output:*
```
all gates pass   dims: 40 run, 0 skipped (skips are NOT passes)
```

### Running Documentation vs Config Consistency Checker:
```bash
python3 "$HOME/Documents/Notes/Atlas/scripts/check_docs_vs_config.py"
```
*Verification Scope:*
- Probes Tmux server using a dedicated temporary socket (`-L devcheck-docs`).
- Runs `wezterm show-keys` and parses all live bindings.
- Asserts that every binding documented in the reference manual exists in runtime tables.
- Validates that `hide_tab_bar_if_only_one_tab = false` and `tab_bar_min_tabs 1` are accurately stated across all markdown files.

### Running Non-Destructive Live Reload:
```bash
stack-reload
```
To test reload behavior without making changes:
```bash
stack-reload --dry-run
```

`stack-reload` covers Tmux, Kitty, and WezTerm only. It does **not** re-exec interactive shells: run `exec zsh` in each open shell for `.zshrc` / prompt changes to take effect. See section 6 for the exact per-layer actions and limits.

---

## 5. Common Incident Response Matrix

| Failure Symptom | Probable Root Cause | Resolution Command / Recovery Procedure |
|---|---|---|
| **Tmux prefix `Ctrl+a` sends raw `Ctrl+a`** | Nested Tmux session active or `send-prefix` looped | Press `Prefix + C-a` or detach nested client with `Ctrl+a d`. |
| **Neovim `opts_extend` fails to load server** | Missing binary in Mason directory | Run `<leader>l` -> Select `Sync` or run `make update`. |
| **WezTerm stranded in modal mode** | Key table active without key timeout | Press `Escape` or `q` to invoke `act.PopKeyTable`. |
| **Kitty splits navigation stops at Neovim edge** | `pass_keys.py` unable to read window process | Ensure `listen_on unix:@kitty-{kitty_pid}` is active in `custom.conf`. |
| **Zsh startup latency exceeds 120ms** | Stale cache or slow network query | Run `zsh -i -c exit` under `devcheck` to pinpoint slow plugin. |
| **Clipboard fails over SSH** | Outer terminal does not support OSC 52 | Verify `clipboard_control` in Kitty or `set-clipboard on` in Tmux. |
| **Prompt colors stale after a palette edit / `stack-reload`** | Long-lived Zsh shell kept its cached Oh-My-Posh init | Run `exec zsh` in each affected shell; `zen.toml` is written from committed hexes by `omp-palette.sh` and the other layers are handled by `stack-reload`. |
| **`devcheck` fails a palette-consistency / contrast gate** | A committed palette file drifted out of sync with kitty's `apple-glass.conf` | Fix the committed hexes, then `stack-reload`; verify with `install.sh --doctor` and `bin/devcheck`. There is no matugen/sanitizer chain or matugen config symlink to repair. |

---

## 6. Reload Mechanics — What `stack-reload` Does (and Does Not Do)

`stack-reload` is the zero-downtime, non-destructive reloader (`bin/stack-reload:1-4`). It reloads three layers in place and never kills Tmux sessions, Neovim buffers, or running shells. `--dry-run` prints the actions without executing them; `--help` prints the layer summary.

| Layer | Action (`bin/stack-reload`) | Limit |
|---|---|---|
| Tmux | `tmux source-file ~/.config/tmux/tmux.conf`, then `on-client-attached.sh`, only when a live server exists (`:82-93`) | Re-parses config; running jobs, buffers, and SSH sessions are untouched. |
| Kitty | Sends `load-config` over each active `@kitty-*` unix socket; falls back to `pkill -USR1 -x kitty` if no socket answers (`:98-126`) | Re-reads the committed `apple-glass.conf` include only; no sanitizer, no matugen hook, no symlink to repair. |
| WezTerm | `touch -c ~/.config/wezterm/wezterm.lua` to trip WezTerm's config mtime watcher (`:128-134`) | No process restart. |
| Zsh | **none** — the script explicitly notes that long-lived shells only adopt new `.zshenv` / `.zshrc` on `exec zsh` (`:136`) | Run `exec zsh` in **each** interactive shell; the prompt and OMP init stay stale until that shell re-execs. |

The palette is static (committed Apple Glass hexes); there is no wallpaper regeneration. After a palette config change, `stack-reload` makes Tmux, Kitty, and WezTerm pick up the new files, but an open shell keeps its old prompt until `exec zsh`. Verify config health with `install.sh --doctor` and `bin/devcheck` as described in section 7 of `00-ecosystem-architecture.md`.
