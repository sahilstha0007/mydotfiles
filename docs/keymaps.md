# Keymaps

Every custom keybinding in this config, grouped by purpose. Leader = `Space`.

## Core (from `lua/keymaps.lua`)

| Keys | Mode | Action |
|------|------|--------|
| `<Esc>` | n | Clear search highlight |
| `sh` | n | Vertical split (`:vsplit`) |
| `sv` | n | Horizontal split (`:split`) |
| `te` | n | New tab (`:tabedit`) |
| `<Tab>` / `<S-Tab>` | n | Next / previous tab |
| `<leader><tab>d` | n | Close tab |
| `<leader>cr` | n | LSP rename |
| `<S-h>` / `<S-l>` | n | Previous / next buffer |
| `[b` / `]b` | n | Previous / next buffer |
| `<leader>bd` | n | Delete buffer |
| `<leader>bo` | n | Delete other buffers |
| `<leader>bD` | n | Delete buffer + its window |
| `<` / `>` | v | Indent / outdent, keep selection |
| `<C-l>` | i | Skip past closing bracket / quote / comma |

## Leader groups (which-key)

| Prefix | Group |
|--------|-------|
| `<leader>b` | Buffers |
| `<leader>c` | Code |
| `<leader>f` | Find |
| `<leader>g` | Git |
| `<leader>s` | Search |
| `<leader>t` | Test |
| `<leader>q` | Session |
| `gz` | Surround |

> The `<leader>q` group backs `mini.sessions` — see the Editor section below.

| Keys | Action |
|------|--------|
| `<leader>ff` / `<leader><space>` | Find files (hidden included) |
| `<leader>fg` | Git-tracked files |
| `<leader>fb` / `<leader>,` | Switch buffer (MRU first) |
| `<leader>s"` | Registers |
| `<leader>sa` | Autocommands |
| `<leader>sb` | Fuzzy search current buffer |
| `<leader>sc` / `<leader>sC` | Command history / commands |
| `<leader>sd` / `<leader>sD` | Diagnostics: this file / workspace |
| `<leader>sg` | Live grep (ripgrep) |
| `<leader>sh` | Help tags |
| `<leader>sH` | Highlight groups |
| `<leader>sj` | Jumplist |
| `<leader>sk` | All keymaps |
| `<leader>sl` | Location list |
| `<leader>sM` | Man pages |
| `<leader>sm` | Marks |
| `<leader>sR` | Resume last picker |
| `<leader>sq` | Quickfix list |
| `<leader>ss` / `<leader>sS` | Symbols: document / workspace |
| `<leader>sy` | Yank history (clipboard ring) |
| `<leader>sr` | grug-far: replace across project |
| `<leader>fj` / `<leader>ft` | Flash: jump to any visible word / treesitter node |
| `R` (op/visual) | Flash: treesitter search |
| `<C-s>` (cmdline) | Flash: toggle search highlighting |

## Code / LSP

Bound buffer-local on `LspAttach` (`lua/plugins/coding/lspconfig.lua`) unless noted.

| Keys | Action |
|------|--------|
| `gd` / `gr` / `gI` / `gy` | Definition / references / impl / type def (telescope, global) |
| `K` | Hover (nvim 0.11 default) |
| `grn` / `gra` | Rename / code action (nvim 0.11 default) |
| `grr` / `gri` / `gO` | References / impl / outline (nvim 0.11 default) |
| `[d` / `]d` | Previous / next diagnostic (nvim 0.11 default) |
| `<leader>ca` | Code action |
| `<leader>cr` | Rename |
| `<leader>th` | Toggle inlay hints |
| `<leader>cd` / `<leader>cD` | Buffer / workspace diagnostics (trouble) |
| `<leader>cs` | Document symbols (trouble) |
| `<leader>cl` | LSP refs/defs list (trouble) |
| `<leader>cL` / `<leader>cQ` | Location list / quickfix (trouble) |
| `<leader>co` | Organize imports (ruff / vtsls) |
| `<leader>cM` / `<leader>cu` | Add missing / remove unused imports (vtsls) |
| `<leader>cV` | Select TS workspace version (vtsls) |
| `gD` / `gR` | TS source def / file references (vtsls) |
| `<leader>vs` / `<leader>vc` | Select venv / cached venv (python) |

> On TypeScript buffers, `<leader>cD` is `VtsExec fix_all` (buffer-local wins over trouble's global binding).

## Git (gitsigns + lazygit)

| Keys | Action |
|------|--------|
| `]c` / `[c` | Next / previous hunk |
| `<leader>ghs` / `<leader>ghr` | Stage / reset hunk (normal + visual) |
| `<leader>ghu` | Undo stage |
| `<leader>ghp` | Preview hunk |
| `<leader>gbs` / `<leader>gbr` | Stage / reset buffer |
| `<leader>gbl` | Toggle blame on current line |
| `<leader>gdi` / `<leader>gdc` | Diff vs index / vs commit |
| `<leader>gds` | Toggle deleted lines |
| `<leader>l` | Lazy actions picker (sync / update / clean / …) |
| `<leader>gg` | LazyGit |
| `<leader>gD` / `<leader>gH` | Diffview: open diff / file history |
| `<leader>gq` | Diffview: close |

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

## Editor

| Keys | Action | Source |
|------|--------|--------|
| `<leader>e` | Toggle file tree (nvim-tree) | file-tree.lua |
| `P` / `s` / `S` | Tree: preview / vertical / horizontal open | file-tree.lua |
| `<leader>ot` / `or` / `ol` | Overseer: toggle list / run / run command | overseer.lua |
| `<leader>oq` / `oa` | Overseer: quick action / task action | overseer.lua |
| `gsa` / `gsd` / `gsr` / `gsf` | Surround: add / delete / replace / find | mini.lua |
| `af` / `if` / `ac` / `ic` / `ab` / `ib` / `aa` / `ia` | Treesitter textobjects: function / class / block / parameter | mini.lua |
| `]f` / `[f` | Next / previous function (treesitter) | textobjects.lua |
| `H` / `L` / `J` / `K` (visual) | Move selection block | mini.lua |
| `<leader>fr` | File ring (harpoon-style recent files) | mini.lua |
| `<leader>qq` / `ql` / `qs` | Session: save / load last / select | mini.lua |
| (auto) | Session saved on exit; `nvim <dir>` restores the last one | mini.lua |
| `<leader>bp` | Pick buffer from the tab strip (bufferline) | bufferline.lua |
| `zR` / `zM` / `K` | Fold: open all / close all / peek | ufo.lua |
| `<leader>ut` | Toggle treesitter-context | treesitter-context.lua |
| `<C-h>` / `<C-j>` / `<C-k>` / `<C-l>` | tmux pane navigation | tmux.lua |
| `<C-\>` | tmux previous pane | tmux.lua |
