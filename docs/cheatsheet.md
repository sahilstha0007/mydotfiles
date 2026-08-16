# Cheat sheet

Printable one-page summary. Leader = `Space`. Full detail in [`keymaps.md`](keymaps.md).

## Modes

| Mode | Enter | Leave |
|------|-------|-------|
| NORMAL | — (home) | — |
| INSERT | `i` `a` `o` `I` `A` `O` `c{motion}` | `Esc` |
| VISUAL | `v` (char) `V` (line) `C-v` (block) | `Esc` |
| COMMAND | `:` or `/` | `Esc` |

## Movement & edit (NORMAL)

| Keys | What |
|------|------|
| `h j k l` | Move (relative numbers = count jumps) |
| `w b e` / `W B E` | Word jumps |
| `0 $ ^` / `gg G` | Line start/end · file top/bottom |
| `%` | Matching bracket |
| `f{x} t{x}` `;` `,` | Jump to/before char on line |
| `/pat` `n` `N` · `*` `#` | Search / word under cursor |
| `dd yy p P` | Delete/copy line, paste after/before |
| `d y c` + motion | Delete / yank / change |
| `u C-r` · `.` | Undo/redo · repeat last change |
| `ciw ci" ci( ci{` | Change inside word/quote/parens/braces |
| `gsa gsd gsr` | Surround add/delete/replace |

## Windows, tabs, buffers

| Keys | What |
|------|------|
| `sh` / `sv` | Vertical / horizontal split |
| `C-w h/j/k/l` · `C-w =` | Jump splits · equalize |
| `te` · `<Tab>` `<S-Tab>` | New tab · next/prev tab |
| `]b` `[b` (or `S-h` `S-l`) | Next/prev buffer |
| `Space ,` / `Space fb` | Switch buffer (MRU) |
| `Space bd` `Space bo` `Space bD` | Delete buffer / others / +window |

## Find (Telescope)

| Keys | What |
|------|------|
| `Space ff` `Space fg` | Files / git files |
| `Space sg` | Grep project |
| `Space sb` | Search current buffer |
| `Space sd` `Space sD` | Diagnostics file / workspace |
| `Space ss` `Space sS` | Symbols file / workspace |
| `Space sh` `Space sk` | Help / all keymaps |
| `Space e` | File tree toggle |

## LSP

| Keys | What |
|------|------|
| `gd gr gy gI` | Def / refs / type-def / impl |
| `K` | Hover docs |
| `Space cr` | Rename |
| `Space ca` | Code action |
| `Space th` | Toggle inlay hints |
| `]d` `[d` | Next/prev diagnostic |

## Git

| Keys | What |
|------|------|
| `]c` `[c` | Next/prev hunk |
| `Space ghs` `Space ghr` | Stage / reset hunk |
| `Space gbl` | Blame line |
| `Space gg` | LazyGit |

## Test / Debug / AI

| Keys | What |
|------|------|
| `Space tr` `Space tt` `Space tT` | Test: nearest / file / all |
| `Space db` `Space dc` `Space do` | Debug: breakpoint / run / step over |
| `Space du` | Debug UI toggle |
| `Space a` | AI agent (Claude Code / opencode) |

## Survive

`:w` `:q` `:wq` `:q!` · `:%s/old/new/g` · `:Lazy` · `:Mason` · `:checkhealth` · `:help`

## Key plugins

lazy.nvim · telescope · blink.cmp · nvim-treesitter · nvim-lspconfig · mason · conform · nvim-lint · neotest · nvim-dap · gitsigns · lazygit · nvim-tree · which-key · mini.surround/mini.ai/mini.move · ufo · overseer · trouble · ai-tools
