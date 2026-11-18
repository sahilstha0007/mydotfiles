# Keymaps

Every custom keybinding in this config, grouped by purpose. Leader = `Space`.

Generated against the live editor (`nvim 0.12.6`) with `make keymaps` → `~/.cache/nvim/keymaps_dump.json`.
Live counts at the time of writing: **394** global normal maps, **157** of them leader maps,
**28** buffer-local normal maps, **174** global visual maps.

> Re-verify any row: `Space sk` (all keymaps picker) or `:map <Space>r`.

## Core (from `lua/keymaps.lua`)

| Keys | Mode | Action |
|------|------|--------|
| `<Esc>` | n | Clear search highlight, dismiss lingering floats |
| `<leader>\|` | n | Vertical split, side-by-side (`:vsplit`) — key matches the split line. Native `<C-w>v` also works |
| `<leader>-` | n | Horizontal split, stacked (`:split`). Native `<C-w>s` also works |
| `]q` / `[q` | n | Quickfix next / previous (wraps at list ends) |
| `]l` / `[l` | n | Loclist next / previous (wraps at list ends) |
| `gt` / `gT` | n | Next / previous tab (native; `<Tab>` deliberately unmapped — it is `<C-i>` jumplist-forward) |
| `<leader><tab>d` | n | Close tab (`:tabclose`) |
| `<leader>cr` | n | LSP rename |
| `<S-h>` / `<S-l>` | n | Previous / next buffer |
| `[b` / `]b` | n | Previous / next buffer |
| `<leader>bd` | n | Delete buffer |
| `<leader>bo` | n | Delete other buffers |
| `<leader>bD` | n | Wipe buffer (stronger delete) |
| `<` / `>` | v | Indent / outdent, keep selection |
| `<C-l>` | i | Skip past closing bracket / quote / comma |

## Leader groups (which-key)

| Prefix | Group | | Prefix | Group |
|--------|-------|-|--------|-------|
| `<leader>b` | Buffers | | `<leader>s` | Search |
| `<leader>c` | Code | | `<leader>t` | Test |
| `<leader>f` | Find | | `<leader>n` | Notes |
| `<leader>g` | Git | | `<leader>q` | Session |
| `<leader>d` | Debug | | `<leader>u` | UI toggles |
| `<leader>r` | Run / REPL | | `<leader>w` | Windows |
| `<leader>o` | Overseer | | `<leader>P` | Project tasks |
| `gz` | Surround | | | |

`<leader>q` backs `mini.sessions`; `<leader>P` shells out to `project-task`.

### Find — `<leader>f`

| Keys | Action |
|------|--------|
| `<leader>ff` / `<leader><space>` | Find files (hidden included) |
| `<leader>fg` | Git-tracked files |
| `<leader>fb` / `<leader>,` | Switch buffer (MRU first) |
| `<leader>fr` / `<leader>fR` | File ring (recent) / Recent-files picker |
| `<leader>fp` | Projects |
| `<leader>ft` / `<leader>fT` | Toggle terminal: cwd / git root |

### Search — `<leader>s`

| Keys | Action |
|------|--------|
| `<leader>sg` | Live grep (ripgrep) |
| `<leader>sw` | Grep word / selection |
| `<leader>su` | Grep the **selection** across the project |
| `<leader>sr` | grug-far: replace across project |
| `<leader>sb` | Fuzzy search current buffer |
| `<leader>sd` / `<leader>sD` | Diagnostics: this file / workspace |
| `<leader>ss` / `<leader>sS` | Symbols: document / workspace |
| `<leader>sh` | Help tags |
| `<leader>sH` | Highlight groups |
| `<leader>sj` | Jumplist |
| `<leader>sk` | All keymaps |
| `<leader>sl` / `<leader>sq` | Location list / quickfix list |
| `<leader>sM` | Man pages |
| `<leader>sm` | Marks |
| `<leader>sn` | Notification history |
| `<leader>st` / `<leader>sT` | Todo comments / Todo-Fix-Fixme picker |
| `<leader>sU` | Undo history |
| `<leader>sa` | Autocommands |
| `<leader>sC` | Commands |
| `<leader>s"` | Registers |
| `<leader>sy` | Yank history (clipboard ring) |
| `<leader>sc` | Command history |
| `<leader>sR` | Resume last picker |
| `s` (n/x/o) | **Flash: jump to any visible word** (1 key) |
| `S` (o/x) | Flash: treesitter node jump (visual/operator) |
| `R` (op/visual) | Flash: treesitter search |
| `<C-s>` (cmdline) | Flash: toggle search highlighting |
| `]p` / `[p` | Cycle last put through yank ring — use right after `p` |
| `<C-/>` or `<C-_>` | n, t | Toggle terminal (snacks.terminal) |
| `<leader>nn` | Today's Atlas daily note, frontmatter pre-filled |
| `<leader>nN` | Scratch buffer — saved to `stdpath('data')/scratch`, never lands in the vault |

## Code / LSP

Bound buffer-local on `LspAttach` (`lua/plugins/coding/lspconfig.lua`) unless noted.

| Keys | Action |
|------|--------|
| `gd` / `gr` / `gI` / `gy` | Definition / references / impl / type def (snacks, global) |
| `K` | Hover (nvim 0.11 default) |
| `grn` / `gra` | Rename / code action (nvim 0.11 default) |
| `grr` / `gri` / `gO` | References / impl / outline (nvim 0.11 default) |
| `[d` / `]d` | Previous / next diagnostic |
| `<leader>ca` | Code action |
| `<leader>cr` | Rename |
| `<leader>cf` | Format buffer / selection (conform) |
| `<leader>cy` | Yank line diagnostic to clipboard |
| `<leader>th` | Toggle inlay hints (`<leader>uh` is the group form) |
| `<leader>xx` / `<leader>cd` / `<leader>cD` | Trouble: toggle diagnostics (workspace) / buffer / workspace |
| `<leader>cs` | Document symbols (trouble) |
| `<leader>cl` | LSP refs/defs list (trouble) |
| `<leader>cL` / `<leader>cQ` | Location list / quickfix (trouble) |
| `<leader>ci` / `<leader>cI` | Incoming / outgoing calls (LSP) |
| `<leader>cc` / `<leader>cC` | Checkpoint working tree / restore checkpoint |
| `<leader>co` | Organize imports (ruff / vtsls) |
| `<leader>cM` / `<leader>cu` | Add missing / remove unused imports (vtsls) |
| `<leader>cV` | Select TS workspace version (vtsls) |
| `gD` / `gR` | TS source def / file references (vtsls) |
| `<leader>vs` / `<leader>vc` | Select venv / cached venv (python) |

> On TypeScript buffers, `<leader>cD` is `VtsExec fix_all` (buffer-local wins over trouble's global binding).

## Run / REPL — `<leader>r`

Runner lives in `lua/utils/runner.lua`; it opens an adjacent tmux split and shares the register.

| Keys | Action |
|------|--------|
| `<leader>rc` / `<leader>rf` | Run current file |
| `<leader>rl` | Run current line |
| `<leader>rs` / `<leader>r` (visual) | Run selection |
| `<leader>rt` | Toggle / start REPL |
| `<leader>rp` / `<leader>rk` | Focus runner pane / kill-clear runner |

## Windows, zoom, UI

| Keys | Action |
|------|--------|
| `<leader>wd` | Delete window |
| `<leader>wm` / `<leader>Z` | Toggle zoom (window only) |
| `<leader>wz` | **Synchronized zoom** — zoom the nvim window *and* the outer tmux pane |
| `<leader>ut` | Toggle treesitter-context |
| `<leader>uu` / `<leader>uf` / `<leader>uF` | Undo tree / undo to your last write / redo to next write |
| `<leader>uw` / `<leader>ul` | Toggle line wrap / line numbers |
| `<leader>ud` / `<leader>uc` / `<leader>uh` / `<leader>us` | Toggle diagnostics / conceal / inlay hints / spell |
| `<leader>ua` / `<leader>uA` | Toggle autoformat (global / buffer) |
| `<leader>un` | Dismiss notifications |
| `<leader>z` | Zen mode |

## Project tasks — `<leader>P`

| Keys | Action |
|------|--------|
| `<leader>P` | Interactive menu (`project-task`) |
| `<leader>Pr` / `Pt` / `Pl` / `Pf` | Run / test / lint / format |

## Git (gitsigns + lazygit + diffview + Octo)

| Keys | Action |
|------|--------|
| `]c` / `[c` | Next / previous hunk |
| `<leader>ghs` / `<leader>ghr` | Stage / reset hunk (normal + visual) |
| `<leader>ghu` | Undo stage |
| `<leader>ghp` | Preview hunk |
| `<leader>gbs` / `<leader>gbr` | Stage / reset buffer |
| `<leader>gbl` | Toggle blame on current line |
| `<leader>gB` | Blame line popup: full commit info |
| `<leader>gG` | Open the current file/line on GitHub (gitbrowse) |
| `<leader>gdi` / `<leader>gdc` | Diff vs index / vs commit |
| `<leader>gds` | Toggle deleted lines |
| `<leader>gg` / `<leader>gZ` | LazyGit (float) / LazyGit (snacks terminal) |
| `<leader>gl` / `<leader>gL` / `<leader>gs` | Git log picker / log for current file / status picker |
| `<leader>gP` / `<leader>gh` | GitHub dash (PRs & issues) / GitHub PRs |
| `<leader>gpr` `gpi` `gpd` `gpn` `gps` | Octo: PRs / issues / discussions / notifications / search |
| `<leader>gco` `gct` `gcb` `gc0` | Conflict: ours / theirs / both / none |
| `<leader>gD` / `<leader>gH` / `<leader>gq` | Diffview: open diff / file history / close |
| `<leader>l` | Lazy actions picker (sync / update / clean / …) |

## Debug (nvim-dap)

| Keys | Action |
|------|--------|
| `<leader>da` | Run with args |
| `<leader>db` / `<leader>dB` | Toggle / conditional breakpoint |
| `<leader>dC` | Run to cursor |
| `<leader>dc` | Continue |
| `<leader>de` | Evaluate (normal + visual) |
| `<leader>dg` | Go to line (no execute) |
| `<leader>di` / `<leader>do` / `<leader>dO` | Step into / over / out |
| `<leader>dj` / `<leader>dk` | Down / up the stack |
| `<leader>dl` | Run last |
| `<leader>dP` | Pause |
| `<leader>dr` | Toggle REPL |
| `<leader>ds` | Session |
| `<leader>dt` | Terminate |
| `<leader>du` | Toggle DAP UI |
| `<leader>dw` | Widgets hover |
| `<leader>dPt` / `<leader>dPc` | Debug python test method / class |

## Tests (neotest)

| Keys | Action |
|------|--------|
| `<leader>tt` / `<leader>tr` / `<leader>tT` | Run file / nearest / all |
| `<leader>tl` | Run last |
| `<leader>ts` | Toggle summary |
| `<leader>to` / `<leader>tO` | Show output / toggle output panel |
| `<leader>tw` | Toggle watch |
| `<leader>tS` | Stop |

## Editor / floats

| Keys | Action | Source |
|------|--------|--------|
| `<leader>e` | Toggle file tree (nvim-tree) | file-tree.lua |
| `P` / `s` / `S` | Tree: preview / vertical / horizontal open | file-tree.lua |
| `-` | Oil: open parent directory as a buffer | oil.lua |
| `<leader>O` / `<leader>Qi` | Oil float / image preview (hover) | oil.lua / snacks |
| `<leader>D` | LazyDocker (docker TUI float) | — |
| `<leader>ot` / `or` / `ol` | Overseer: toggle list / run / run command | overseer.lua |
| `<leader>oq` / `oa` / `ob` / `os` / `oc` | Overseer: quick action / select+act / load bundle / save bundle / clear cache | overseer.lua |
| `gsa` / `gsd` / `gsr` / `gsf` / `gsn` | Surround: add / delete / replace / find / set N lines | mini.lua |
| `af` / `if` / `ac` / `ic` / `ab` / `ib` / `aa` / `ia` | Treesitter textobjects: function / class / block / parameter | mini.lua |
| `]f` / `[f` | Next / previous function (treesitter) | textobjects.lua |
| `H` / `L` / `J` / `K` (visual) | Move selection block | mini.lua |
| `<leader>qq` / `ql` / `qs` | Session: save / load last / select | mini.lua |
| `<leader>bp` / `<leader>bs` | Pick buffer from tab strip / toggle buffer sort | bufferline.lua |
| `zR` / `zM` / `K` | Fold: open all / close all / peek | ufo.lua |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | tmux pane navigation | tmux.lua |
| `<M-h>` / `<M-j>` / `<M-k>` / `<M-l>` | Resize pane (tmux.nvim) | tmux.lua |
| `<M-C-h>` / `<M-C-j>` / `<M-C-k>` / `<M-C-l>` | Swap pane with neighbor (tmux.nvim) | tmux.lua |
