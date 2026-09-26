# AGENT.md — Neovim Setup Knowledge Base

> Single source of truth for this config: keybindings, workflows, tmux integration,
> gotchas, and a ranked backlog for making the workflow faster.
> Companion docs live in `docs/` (architecture, plugins, lsp, keymaps, cheatsheet).
> Obsidian mirror notes: `~/Documents/Notes/Atlas/02 - Dev/Terminal Stack/03 - Neovim.md`.
>
> **Environment:** Neovim 0.12.5 · lazy.nvim · leader = `Space` · terminal = Ghostty/wezterm
> inside tmux (prefix `C-a`) · Wayland (wl-copy available) · clipboard sync everywhere.

---

## 1. The Mental Model (read this first)

```
Ghostty/wezterm ── tmux (prefix C-a) ── nvim
        │                 │                │
        └── OSC52 clipboard wins: any `y` anywhere lands in the OS clipboard
```

- **One picker:** snacks.picker (telescope fully removed). Owns `vim.ui.select` too.
- **One completion:** blink.cmp (no nvim-cmp, no LuaSnip).
- **One status/tab UI:** lualine + bufferline, transparent, wallpaper-tinted via OSC palette adoption.
- **Sessions:** mini.sessions auto-saves on exit, auto-restores on `nvim <dir>`.
- **Clipboard:** `clipboard = unnamedplus` in nvim + `set-clipboard on` in tmux → OSC52.
  Plain `y` in nvim IS the system clipboard copy. No extra steps.

---

## 2. Daily-Driver Keybindings (the 80/20)

### Jumping & editing (normal mode)
| Keys | Action | Notes |
|------|--------|-------|
| `hjkl` `w b e` `f{c}` `/` `n N` `*` | native motions | relnumber = count jumps |
| `s` | **Flash jump** — 1-2 letters to any visible word | n/x/o. Splits moved off the `s` prefix (backlog #1 done) |
| `S` (op/visual) | Flash treesitter node jump | normal `S` (substitute-line) kept; `cc` covers it |
| `R` (op/visual) | Flash treesitter search | |
| `]p` / `[p` | Cycle last put through yank ring | right after `p`/`P` (yanky) |
| `]f` / `[f` | Next / previous function | treesitter-textobjects |
| `]d` / `[d` | Next / prev diagnostic | native 0.11+ |
| `]c` / `[c` | Next / prev git hunk | gitsigns (diff-mode aware) |
| `gsa` `gsd` `gsr` | Surround add / delete / replace | mini.surround |
| `af if ac ic ab ib aa ia` | treesitter textobjects (function/class/block/param) | mini.ai |
| `gc` / `gcc` | Comment toggle | native 0.10+ (no plugin) |
| `<` `>` (visual) | Indent, keeps selection | |
| `<C-l>` (insert) | Skip past `)` `]` `}` quotes comma | |

### Finding things (snacks.picker)
| Keys | Action |
|------|--------|
| `<leader><space>` or `<leader>ff` | Files |
| `<leader>,` or `<leader>fb` | Buffers (MRU) |
| `<leader>fg` | Git files |
| `<leader>sg` | Live grep |
| `<leader>sb` | Search current buffer lines |
| `<leader>sr` | **grug-far** project-wide replace (prefills file ext) |
| `<leader>ss` / `sS` | Document / workspace symbols |
| `<leader>sd` / `sD` | Diagnostics file / workspace |
| `<leader>sk` | All keymaps (use this when lost!) |
| `<leader>sR` | Resume last picker |
| `<leader>sy` | Yank history (yanky ring, persists via shada) |
| `<leader>fr` | File ring (mini.visits — harpoon-style) |

### LSP
| Keys | Action |
|------|--------|
| `gd` `gr` `gI` `gy` | Def / refs / impl / type-def (snacks pickers) |
| `K` | Hover **or fold-peek** (ufo dual-purpose) |
| `<leader>ca` | Code action (auto-deleted if LSP lacks support) |
| `<leader>cr` | Rename |
| `<leader>th` | Toggle inlay hints |
| `gO` | Document symbol outline (native) |
| TS/JS only: `gD` source-def · `gR` file-refs · `<leader>co` organize imports · `cM` add missing · `cu` remove unused · `cV` select TS version · `<leader>cD` fix-all |
| Python: `<leader>co` = ruff organize imports · `<leader>vs`/`vc` venv select/cached |

> `VtsExec fix_all` only fixes TS error codes 2420 (implements interface), 1308
> (await-in-sync), 7027 (unreachable code). Unused imports (6133) are NOT covered —
> use `<leader>co` (organize imports) or `:VtsExec remove_unused_imports` for those.

### Windows / buffers / tabs / panes
| Keys | Action |
|------|--------|
| `<leader>\|` / `<leader>-` | vsplit (side-by-side) / split (stacked) — LazyVim convention, key matches the split line. Native `<C-w>v`/`<C-w>s` still work |
| `<C-h> <C-j> <C-k> <C-l>` | Move between splits AND tmux panes seamlessly (is_vim passthrough) |
| `<M-h> <M-j> <M-k> <M-l>` | Resize pane/split (tmux.nvim + tmux.conf both bind these) |
| `<S-h>` / `<S-l>` or `]b` / `[b` | Prev / next buffer |
| `<leader>bp` | BufferLinePick — jump by letter from tab strip |
| `<leader>bd` / `bo` / `bD` | Delete buffer / others / +window |
| `gt` `gT` `<leader><tab>d` | Tab next/prev/close (`<Tab>` deliberately unmapped = `<C-i>` jumplist) |

### Git
| Keys | Action |
|------|--------|
| `<leader>gg` | LazyGit float |
| `<leader>gD` / `gH` / `gq` | Diffview open / file history / close |
| `<leader>ghs ghr ghu ghp` | Stage / reset / undo-stage / preview hunk |
| `<leader>gbs` `gbr` `gbl` | Stage / reset buffer, blame line |
| `<leader>gB` | **Blame popup** — full commit (author/date/message) for current line |
| `<leader>gdi` `gdc` `gds` | Diff vs index / commit, show deleted |

### Tests / Debug
| Keys | Action |
|------|--------|
| `<leader>tr` `tt` `tT` | Nearest / file / all tests |
| `<leader>tl` `ts` `to` `tw` | Last / summary / output / watch |
| `<leader>db` `dc` `do` `di` `du` | DAP: breakpoint / continue / over / into / UI |

### Misc
| Keys | Action |
|------|--------|
| `<leader>e` | nvim-tree (right side, quits on open) |
| `<C-/>` | **Terminal toggle** (snacks.terminal float; also `<C-_>` spelling) |
| `<leader>ft` / `fT` | Terminal toggle: cwd / git root |
| `<leader>a` | AI agent picker (Claude Code / opencode) → right tmux pane or float |
| `<leader>l` | Lazy actions picker (sync/update/clean/…) |
| `<leader>o*` | Overseer tasks (run, toggle list, quick action) |
| `<leader>pi pr pd pn ps` | Octo: issues / PRs / discussions / notifications / search |
| `<leader>qq` `ql` `qs` | Session save / load / select |
| `<leader>uh` | Toggle hardtime trainer (OFF by default) |
| `<leader>ut` | Toggle treesitter-context |
| `<leader>xx` `cd` `cD` `cs` `cl` | Trouble: toggle diagnostics / buffer diag / workspace diag / symbols / LSP list |
| `zR` `zM` | Fold open all / close all (ufo) |

### Insert-mode completion (blink.cmp, preset=default)
`<C-y>` accept · `<C-n>/<C-p>` select · `<C-space>` docs · `<C-e>` hide ·
`<C-b>/<C-f>` scroll docs · `<Tab>/<S-Tab>` snippet jump · `Space` hides menu (custom)

---

## 3. tmux Layer (paired knowledge)

Config: `~/.config/tmux/tmux.conf`, prefix = **`C-a`** (double `C-a C-a` = last window).

### Copy/paste (fully wired, nothing to configure)
| Action | Keys |
|--------|------|
| Copy in nvim | just `y` → OSC52 → OS clipboard |
| Copy tmux scrollback/shell output | `C-a [` → move (`hjkl`) → `v` select → `y` copies+exits |
| Exit copy mode | `q` (status bar shows red `COPY` while in it) |
| Paste into shell/nvim | `C-a ]` (tmux buffer) or `Ctrl+Shift+V` (OS clipboard) |
| Mouse | drag-select releases straight to OS clipboard (OSC52) |

### Pane/window management
| Keys | Action |
|------|--------|
| `C-a v` / `C-a h` | Split vertical / horizontal (current path) |
| `C-a f` | Sessionizer popup (fzf over ~/Projects) |
| `C-a c` | New window (current path) |
| `C-a x` | Kill pane |
| `C-a \` | Toggle status bar |
| `C-a r` | Reload tmux.conf |
| `C-a I` | Install TPM plugins (first time only) |

**Why `<C-hjkl>` and `<M-hjkl>` just work:** tmux.conf checks `$is_vim` per pane and
forwards to nvim when focused; tmux.nvim mirrors the same keys back the other way.
Never remap one side without the other.

### Continuity
tmux-resurrect + continuum save every 10 min and restore panes on reboot;
nvim sessions (mini.sessions) layer on top, so `nvim <dir>` + tmux restore ≈ full resume.

---

## 4. Gotchas & Deliberate Quirks (encoded in comments — don't undo)

1. **`<Tab>` is NOT remapped** — terminals send Tab and `C-i` as the same byte;
   remapping kills jumplist-forward (`<C-i>`), partner of `<C-o>`.
2. **Flash `s` is live** — splits moved to `<leader>|`/`<leader>-`. Normal `S` still substitute-line;
   flash treesitter is on visual/operator `S` only.
3. **`K` is dual-purpose** — fold peek first, hover fallback (ufo.lua).
4. **`<leader>ca` is deleted on attach** when the LSP lacks codeAction support (lazy-init.lua LspAttach autocmd).
5. **`<space>` in insert closes the completion menu** — returns literal `' '` in the expr
   map (expr results are not termcode-expanded; `<Space>` would type the text "<Space>").
6. **Blink docs: `pumblend` doesn't apply** to blink's windows — winblend is set per-window in cmp.lua.
7. **gopls comes from mise, not mason** (mise overrides GOBIN; mason can't install it).
8. **tailwindcss LSP excludes markdown** (bundled config merges OVER user lsp/ files, so
   it's filtered via explicit `vim.lsp.config` in lspconfig.lua).
9. **`nvim-tree` opens on `nvim <dir>`** via a BufEnter autocmd (plugin is lazy).
10. **Session auto-save skips the fresh dashboard** (no named buffer + single window check in mini.lua).
11. **hardtime is disabled by default** — enable via `<leader>uh` only after native motions feel natural.
12. **tmux OSC fallback:** inside tmux, OSC palette queries are eaten, so terminal-colors.lua
    reads the terminal's config file directly (kitty/wezterm), detected via env vars that survive tmux.

---

## 5. Improvement Backlog (ranked — do these to get faster)

> Items #1–#7 were completed 2026-09-07. Kept below for history, marked ✅.
> Current open items: #8–#10 (low-effort wins).

### ✅ #1 Free `s` for Flash jump (biggest speed win) — DONE
`s` = flash jump (n/x/o), `S` = treesitter node (o/x), splits → `<leader>|`/`<leader>-`.

### ✅ #2 Rename `sh`/`sv` → mnemonic-correct — DONE
Replaced by `<leader>|` (vsplit) / `<leader>-` (split), LazyVim convention.

### ✅ #3 Terminal toggle — DONE
`<C-/>` (and `<C-_>` spelling) toggles snacks.terminal. `<leader>ft` (cwd) / `<leader>fT` (git root).
`<C-/>`/`<C-_>` are mapped in **n+t modes** — t-mode is required to close the terminal
from inside it (snacks installs no in-terminal keymaps of its own). `<leader>fT` outside
a git repo falls back to the shell default cwd (get_root returns nil, safe).

### ✅ #4 Quickfix/loclist navigation — DONE
`]q`/`[q` quickfix, `]l`/`[l` loclist in `lua/keymaps.lua`. **Wrap at list boundaries**
(stock `:cnext` errors E553 "No more items" at the ends; the maps catch it and jump to
the opposite end instead, so cycling never dead-ends). On an empty quickfix, `]q` shows
the stock E42 "No errors" error — that is expected/informative, not a bug.

### ✅ #5 Yanky ring cycling — DONE
`p`/`P`/`gp`/`gP` now use yanky put plugs. After a put, `]p`/`[p` cycles yank-ring entries.

### ✅ #6 VtsExec fix_all wiring — DONE
`yioneko/nvim-vtsls` plugin installed (it was missing — only the mason LSP binary existed,
which is why all 4 TS keymaps in `lsp/vtsls.lua` were dead). `<leader>cD` on TS buffers
is now `VtsExec fix_all` (buffer-local, shadows trouble's workspace diagnostics on TS only;
`<leader>cd` and `<leader>sD` remain global).
Note: the plugin has no `setup()`; wired via explicit `config = function() require('vtsls').config({...}) end`
in `lua/plugins/languages/typescript.lua` (lazy.nvim would otherwise try `require('vtsls').setup(opts)` and fail).

### ✅ #7 Trouble one-key access — DONE
`<leader>xx` = toggle workspace diagnostics (kept alongside `<leader>cD`).

### #8 Dashboard ↔ editor muscle-memory parity
Dashboard keys: `f` files, `g` grep, `s` session, `G` lazygit, `t` tests. In-editor those
are `<leader>ff`, `<leader>sg`, `<leader>qq`, `<leader>gg`, `<leader>t*`. Harmless, but if
you typo, remember the dashboard is a different mode with its own single-key map.

### ✅ #9 `flash` treesitter jump via `S` in visual — DONE
Verified 2026-09-07: visual `S` = "Flash: jump to treesitter node" (bound in n/x/o via
the keymap table). nvim-tree's window-scoped `s`/`S` (vsplit/split) still win inside the
tree buffer (maparg shows buffer-local callback taking precedence).

### #10 Low-effort wins
- ~~`<leader>gB` blame popup~~ ✅ DONE 2026-09-07 (`gitsigns.blame_line { full = true }`).
- ~~`<leader>bs` sort buffers by directory~~ ✅ DONE 2026-09-07 (toggle MRU ↔ directory;
  snapshot-based restore — `insert_after_current` "respects current order", so plain
  clear of `custom_sort` would NOT restore MRU; see bufferline.lua comment).
- Enable `hardtime` for 1 week once you stop reaching for arrows — locks in the speed gains.

---

## 6. How to Verify Keybinding Changes

```bash
# Full keymap dump (all modes, global + buffer-local) → ~/.cache/nvim/keymaps_dump.json
nvim --headless -u ~/.config/nvim/init.lua \
  -c "luafile ~/.config/nvim/scripts/keymaps-dump.lua" -c "qa!"

# Config health + LSP/tool check
nvim -c "checkhealth"

# Startup profile
nvim --startuptime /tmp/startup.log   # or <leader>l → Profile
```

Conflict check inside nvim: `<leader>sk` (snacks keymaps picker) → search the key.
Which-key pops up after `<leader>` with delay 0 (preset "helix"), so every binding
needs a `desc =` to be discoverable.

---

## 7. File Map (where bindings live)

| Want to change… | Edit… |
|---|---|
| Splits, buffer cycling, indent-keep, `<C-l>` skip | `lua/keymaps.lua` |
| Picker bindings (`<leader>f*`, `<leader>s*`) | `lua/plugins/editor/snacks.lua` |
| LSP nav (`gd` etc.) | `lua/plugins/editor/pickers.lua` |
| LSP actions/rename/inlay (`<leader>ca cr th`) | `lua/plugins/coding/lspconfig.lua`, `lsp/*.lua` (vtsls, ruff) |
| Git hunks | `lua/plugins/editor/gitsigns.lua` |
| Flash | `lua/plugins/editor/flash.lua` |
| Surround, move (H/J/K/L), file ring, sessions | `lua/plugins/editor/mini.lua` |
| DAP | `lua/plugins/dap/core.lua` |
| Tests | `lua/plugins/test/core.lua` |
| Trouble | `lua/plugins/coding/trouble.lua` |
| Tree | `lua/plugins/editor/file-tree.lua` |
| Overseer / Octo / grug-far / diffview / lazygit | same-named `lua/plugins/editor/*.lua` |
| Which-key groups + icons | `lua/plugins/editor/which-key.lua` |
| tmux counterpart keys | `~/.config/tmux/tmux.conf` |

---

*Last verified against the live config: 2026-09-07 — backlog #1–#7 + gB implemented (nvim 0.12.5, lazy-lock at commit blink.cmp#78336bc).*
