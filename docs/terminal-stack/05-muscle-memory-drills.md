---
title: "05 — High-Velocity Muscle Memory Drills"
description: "8 concrete, real-world development workflows with exact keypress-by-keypress instructions covering the entire terminal stack."
tags: [drills, workflows, muscle-memory, terminal-stack, practice, playbooks, tmux, nvim]
---

# 05 — High-Velocity Muscle Memory Drills

<nav class="breadcrumb-nav">
  <a href="00-ecosystem-architecture.md">00 Ecosystem Architecture</a> •
  <a href="01-wezterm-mastery.md">01 WezTerm Deep-Dive</a> •
  <a href="02-kitty-mastery.md">02 Kitty Architecture</a> •
  <a href="03-tmux-masterclass.md">03 Tmux 3.8 Masterclass</a> •
  <a href="04-neovim-mastery.md">04 Neovim 0.12.6 Guide</a> •
  <strong>05 Muscle Memory Drills</strong> •
  <a href="06-troubleshooting-runbook.md">06 Troubleshooting Runbook</a>
</nav>

---

## Drill 1: Zero to Code in Under 5 Seconds

### Goal:
Cold-start your entire development workspace: terminal emulator, project session, editor, backend task runner, and database log monitor without touching the mouse.

```
+-------------------------------------------------------------------------------------------------------+
| WORKFLOW PROGRESSION:                                                                                 |
|  [Compositor Launch] -> [Project Hub] -> [Open Editor] -> [Run Server] -> [Split Logs] -> [Sync Zoom]  |
+-------------------------------------------------------------------------------------------------------+
```

### Exact Keypress Sequence:
1. `SUPER + RETURN`
   - Spawns the primary daily driver terminal (**Kitty**) instantly under Hyprland.
2. `Ctrl + a` then `f` (or `Prefix + f`)
   - Spawns the floating **Project Hub** popup (85% × 85%).
3. Type `api` (or project name) and press `Enter`
   - FZF filters registered projects and active Tmux sessions.
   - Attaches or creates the dedicated session in the project root.
4. Type `v` and press `Enter`
   - Invokes Neovim (`v` is aliased to `nvim`). Snacks loads at boot (measured ~0.2ms for the module; full headless boot ~78ms with `hyperfine`).
5. `<Space> f f` (or `<Space> <Space>`)
   - Opens the fast file picker. Type `main.py` (or `server.ts`) and press `Enter`.
6. `<Space> r c`
   - Executes the code runner (`lua/utils/runner.lua`).
   - Neovim detects filetype, creates a 30% horizontal Tmux runner pane below, executes the file, and returns cursor focus to Neovim.
7. `Ctrl + a` then `-`
   - Splits a horizontal log pane below the runner:
     `docker compose logs -f db` -> `Enter`.
8. `<Space> w z`
   - **Synchronized Zoom:** Maximizes the Neovim split and simultaneously zooms the outer Tmux pane (`tmux resize-pane -Z`) for distraction-free editing.

---

## Drill 2: Stack Trace Triage & Instant Jumper

### Goal:
Jump from a terminal stack trace, traceback, or compiler error directly into the offending file and line inside Neovim without copying text.

### Scenario A: Inside Kitty Terminal (`SUPER+RETURN`)
1. A compiler error appears in your terminal scrollback:
   `error: cannot find value `token` in this scope --> src/auth/jwt.rs:48:12`
2. Press `Ctrl + Shift + p` then `n`
   - Triggers Kitty's **Line Number Hints Kitten** (`kitten hints --type linenum`).
   - Yellow/cyan hint labels appear over every file:line pattern on screen.
3. Press the matching single-letter hint badge (e.g. `f`)
   - Kitty immediately executes `nvim +48 src/auth/jwt.rs`, jumping directly to line 48 in Neovim.
4. Perform the fix, then press `<Space> r c` to re-trigger the runner.

### Scenario B: Inside Tmux Multiplexer
1. An error occurs inside a Tmux pane.
2. Press `Ctrl + a` then `e`
   - Spawns the floating **Error Jumper Popup** (`error-jump.sh`).
   - Scrapes the last 300 lines of scrollback and filters valid local file paths.
3. Use `j`/`k` to highlight the target trace and press `Enter`.
   - Opens the target file directly at the exact line number in Neovim.

### Scenario C: Inside WezTerm Workstation
1. Press `Ctrl + Shift + Space`
   - Enters WezTerm **QuickSelect Mode**.
   - Mnemonic letter labels tag compiler errors and URLs.
2. Press the 1-2 character tag matching the target error.
   - Clickable regex triggers WezTerm's `open-uri` event handler, invoking `nvim +{line} {path}`.

---

## Drill 3: 40-File Project Refactoring

### Goal:
Safely rename a shared symbol across 40+ files using native Neovim Quickfix triage without installing heavy refactoring plugins.

```
[<leader>sg: Ripgrep] -> [<C-q>: Quickfix] -> [:Cfilter: Prune] -> [dd: Triage] -> [:cfdo: Bulk Replace]
```

### Exact Keypress Sequence:
1. `<Space> s g`
   - Opens project-wide live grep (`snacks.picker.grep`).
2. Type `fetchUserPermissions` and press `Enter`.
3. Press `Ctrl + q`
   - Dumps all search matches into the native Neovim Quickfix list (`:copen`).
4. `:Cfilter /services\//` and press `Enter`
   - Native quickfix filter: removes all test files and fixtures, retaining only matches inside `services/`.
5. Review matches in the quickfix window:
   - Use `j` and `k` to browse.
   - Press `dd` on any line you wish to exclude from refactoring.
6. Run the bulk substitution:
   ```vim
   :cfdo %s/fetchUserPermissions/getUserPermissions/g | update
   ```
   - `:cfdo` executes the replacement across every file in the quickfix list and saves the buffer to disk (`update`).
7. `<Space> g g`
   - Opens the floating **LazyGit** popup.
   - Review the staged diffs across all modified files.
   - Press `a` (stage all), `c` (commit), type commit message, and press `Enter`.
   - Press `q` to dismiss LazyGit and return to your code.

---

## Drill 4: Surgical AST Refactor Without Arrow Keys or Mouse

### Goal:
Refactor nested function parameters and edit surrounding punctuation entirely via Treesitter AST objects.

### Initial Code:
```typescript
function calculateTaxes(accountId: string, [userId, rawConfig]: [string, ConfigMap], options: TaxOptions): Promise<TaxResult> {
```

### Objective:
1. Jump to `rawConfig`.
2. Delete the surrounding array pattern.
3. Replace single quotes in types with double quotes.
4. Surround `options: TaxOptions` with a null-check wrapper.

### Exact Keypress Sequence:
1. Press `s` (Flash jump)
   - Visual jump tags overlay all matching tokens across the screen.
2. Type `rc`
   - Cursor jumps directly to `rawConfig` in a single motion.
3. `d a a` (Delete Around Argument via `mini.ai`)
   - Treesitter AST deletes `rawConfig` along with the trailing comma cleanly.
4. `g s d [` (Delete Surrounding Bracket via `mini.surround`)
   - Strips the `[` and `]` wrapping `userId`.
5. Press `s` then `st`
   - Cursor jumps to `'string'`.
6. `g s r ' "` (Replace Surrounding Delimiter)
   - Replaces `'string'` with `"string"`.
7. `v a a` (Visual Around Argument)
   - Selects `options: TaxOptions` as a semantic Treesitter node.
8. `g s a )` (Add Surrounding Delimiters)
   - Wraps the argument in parentheses `(options: TaxOptions)`.

---

## Drill 5: 3-Way Merge Conflict Resolution

### Goal:
Resolve a complex Git merge conflict using `diffview.nvim` without leaving Neovim.

### Exact Keypress Sequence:
1. Pull conflicting changes (`git pull origin main`).
2. Open Neovim: `<Space> g D`
   - Opens Diffview 3-way split: `LOCAL (Left) | BASE (Middle) | REMOTE (Right)`.
3. Jump between conflict markers:
   - Press `] c` to jump to the next conflict hunk.
   - Press `[ c` to jump to the previous conflict hunk.
4. Apply conflict resolutions via leader chords:
   - `<Space> g c o`: Choose **Ours** (retains local changes).
   - `<Space> g c t`: Choose **Theirs** (accepts incoming remote changes).
   - `<Space> g c b`: Choose **Both** (preserves both branches).
   - `<Space> g c 0`: Choose **None** (deletes conflicting region).
5. `<Space> g b s`
   - Stages the resolved buffer via `gitsigns`.
6. `<Space> g q`
   - Closes the Diffview tab and returns to standard editor layout.

---

## Drill 6: Extending Toolchains with `opts_extend`

### Goal:
Add a new language server (`astro`) and formatter (`blade-formatter`) using modular plugin configuration, then verify quality gates.

### Exact Keypress Sequence:
1. Open Neovim: `<Space> f f` -> `lua/plugins/languages/astro.lua`.
2. Add the language server specification:
   ```lua
   return {
     {
       'WhoIsSethDaniel/mason-tool-installer.nvim',
       opts_extend = { 'ensure_installed' },
       opts = {
         ensure_installed = { 'astro-language-server' },
       },
     },
   }
   ```
3. Save the file: `:w`.
4. Open the Lazy actions popup: `<Space> l`.
   - Select `Sync` and press `Enter`. Mason downloads the missing language binaries in the background.
5. Exit Neovim: `:qa`.
6. Open your shell and execute the full test verification suite:
   ```bash
   devcheck
   ```
   - Confirms all 40 quality gates pass with 0 errors.

---

## Drill 7: Long-Running Jobs Inside Floating Scratchpads

### Goal:
Execute long-lived background tasks (e.g. watching database migrations or builds) inside a floating popup without sacrificing editor screen real estate.

### Exact Keypress Sequence:
1. While focused inside Neovim, press `Ctrl + a` then `u`
   - Spawns a floating **Terminal Scratchpad** (80% × 75%) centered over your editor.
2. Start the watcher:
   ```bash
   pnpm run build --watch
   ```
3. Press `Ctrl + a` then `d` (or `Ctrl + a` then `u` again)
   - Detaches the popup immediately.
   - Neovim is fully restored to 100% of your screen canvas. The watcher process continues running in the background.
4. To check progress at any time:
   - Press `Ctrl + a` then `T` to open **Btop** in a floating popup and observe CPU/RAM usage.
   - Or press `Ctrl + a` then `u` to re-attach to the scratchpad instantly.

---

## Drill 8: Cross-Machine Remote Sync via OSC 52

### Goal:
Seamlessly yank code from a remote SSH server into your local Wayland system clipboard (`wl-copy`) without configuring X11 forwarding or shared network mounts.

### Exact Keypress Sequence:
1. Open WezTerm (`SUPER + SHIFT + RETURN`).
2. SSH to remote machine:
   ```bash
   ssh developer@staging-server
   ```
3. Notice the WezTerm Status Bar:
   - The **Remote Host Badge** (`events/hud.lua`) illuminates with `[ staging-server ]` in the top right HUD.
4. Attach to remote Tmux session:
   ```bash
   tmux attach -t main
   ```
5. Enter Tmux copy-mode:
   - Press `Ctrl + a` then `[` (or press `PageUp`).
6. Navigate and yank:
   - Use `h`/`j`/`k`/`l` to reach target log line.
   - Press `V` to select whole line.
   - Press `y` to yank.
7. Technical Pipeline:
   - Tmux encodes selection into Base64 format and emits an OSC 52 sequence: `\E]52;c;<base64>\007`.
   - The sequence passes over the SSH connection to WezTerm.
   - WezTerm receives the sequence and issues `wl-copy` to your local Wayland compositor.
8. Switch to local editor:
   - Press `Ctrl + v` in any local application — the remote text pastes immediately.
