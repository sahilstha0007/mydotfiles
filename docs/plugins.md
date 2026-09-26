# Plugins

Every plugin spec, what it does, and what it adds.

## Coding

### `lua/plugins/coding/autopairs.lua`
nvim-autopairs. Auto-closes brackets, quotes, and parens while typing.

### `lua/plugins/coding/cmp.lua`
nvim-cmp + sources. Tab-completion. Standard LSP + buffer + path + snippets.

### `lua/plugins/coding/lspconfig.lua`
Boots `nvim-lspconfig` and wires up all the language servers (see `lsp.md`).
Also installs `mason.nvim` for installing LSPs/binaries/linters/formatters.

### `lua/plugins/coding/todo-comments.lua`
Highlights TODO / FIXME / HACK / XXX in any buffer with `:TodoTrouble` / `:TodoQuickFix`.

### `lua/plugins/coding/textobjects.lua`
nvim-treesitter-textobjects. Adds treesitter motions only: `]f` / `[f` jump
to next / previous function. Selection textobjects (`af`, `if`, …) are
powered by mini.ai's native treesitter spec instead (see `mini.lua`).

### `lua/plugins/coding/treesitter.lua`
nvim-treesitter. Provides syntax highlighting, indentation, and incremental
parsing. Defines a list of `ensure_installed` languages — `:TSUpdate` installs
them. Note: this file has uncommitted edits; review before modifying.

### `lua/plugins/coding/trouble.lua`
trouble.nvim. Replaces the default quickfix/location list with a richer UI
that you can navigate like a file tree.

## DAP

### `lua/plugins/dap/core.lua`
nvim-dap. Debug adapter protocol. Configures `dap.ui.map` mappings and the
adapter entrypoints. Per-language adapter setup lives in `lsp/` style files
or directly inside this spec when added.

## Editor

### `lua/plugins/editor/bufferline.lua`
bufferline.nvim. Browser-style tab strip of open buffers on top. `<leader>bp`
picks a buffer from the strip; `<S-h>` / `<S-l>` cycle it.

### `lua/plugins/editor/file-tree.lua`
nvim-tree. The file explorer. Lazy-loaded — pulled in on `<leader>e`,
`:NvimTree*`, or opening a directory (`nvim .`).

### `lua/plugins/editor/disable-neotree.lua`
Strips neo-tree's default icon rendering and bloat. Loaded *after* `file-tree`
to override defaults.

### `lua/plugins/editor/diffview.lua`
diffview.nvim. Side-by-side branch / commit / PR diffs (lazygit is quick,
this is thorough). `<leader>gD` open, `<leader>gH` file history, `<leader>gq` close.

### `lua/plugins/editor/flash.lua`
flash.nvim. Jump to any visible word by typing 1–2 letters: `<leader>fj`
jump, `<leader>ft` treesitter node, `R` treesitter search. Deliberately NOT
bound to `s` — `sh`/`sv` already own that key for splits.

### `lua/plugins/editor/gitsigns.lua`
gitsigns.nvim. Inline git change markers in the sign column plus `:Gitsigns:*
` commands.

### `lua/plugins/editor/grug-far.lua`
grug-far.nvim. Project-wide search-and-replace UI. Good alternative to
`vim.lsp.buf.codeaction` refactor when there's no LSP support.

### `lua/plugins/editor/hardtime.lua`
hardtime.nvim. Prevents the kind of bad muscle-memory habits (`dd`, `x`,
`j` mash) that wear your hands and your wrists.

### `lua/plugins/editor/lazygit.lua`
lazygit.nvim. Opens lazygit in a floating terminal. Usually `<leader>gg`.

### `lua/plugins/editor/lualine.lua` + `lualine-theme.lua`
Statusline. Two files because the theme is split out for readability.



### `lua/plugins/editor/overseer.lua`
overseer.nvim. Run build / test tasks as Neovim jobs. Keymaps live in this
spec under `<leader>o*` (toggle, run, save bundle, etc.).

### `lua/plugins/editor/snacks.lua`
snacks.nvim. The modern-quality-of-life hub: **the single picker system**
(file/grep/help/buffers/diagnostics — telescope was fully removed), smooth
scrolling, thin indent guides, fancy notifications, word highlighting,
dimmed unfocused windows, subtle UI animations, **and the dashboard start
screen** (recent files + session restore + key hints). Bindings live in
this spec under `<leader>s*` / `<leader>ff` etc. LSP navigation (`gd`/`gr`/
`gI`/`gy`) is wired to snacks in `pickers.lua`.

### `lua/plugins/editor/tmux.lua`
tmux integration: `aserowy/tmux.nvim` for resize and `christoomey/vim-tmux-navigator`
for `<C-h/j/k/l>` seamless hopping between nvim and tmux panes.

### `lua/plugins/editor/ufo.lua`
ufo.nvim. Fold provider. Picks the best fold strategy per buffer
(treesitter when available, otherwise syntax-based).

### `lua/plugins/editor/which-key.lua`
which-key. Pops up a hint when you press `<leader>` and pause. Gives every
keymap a `desc = '…'` and it shows up here.

### `lua/plugins/editor/yanky.lua`
yanky.nvim. Clipboard history — every yank/delete is kept in a ring that
survives restarts. `<leader>sy` opens the history picker via `vim.ui.select`
(snacks).

### `lua/plugins/editor/mini.lua`
mini.nvim grab-bag: `mini.ai` (text objects — `af`/`if`/`ac`/`ic`/`ab`/`ib`/
`aa`/`ia` now resolve via **treesitter** through `gen_spec.treesitter()`),
`mini.surround` (`gs*`), `mini.move` (H/L/J/K), **`mini.visits`**
(harpoon-style quick file switching via `<leader>fr`), and **`mini.sessions`**
(session persistence — `<leader>qq`/`ql`/`qs`, auto-saved on exit, auto-restored
on `nvim <dir>` — also read by the snacks dashboard).

## Formatting

### `lua/plugins/formatting/conform.lua`
conform.nvim. Runs formatters on save. Per-filetype formatters configured here.

### `lua/plugins/formatting/prettier.lua`
Optional Prettier shim if conform doesn't pick up `prettier` automatically.
Loaded eagerly so other plugin specs can assume it's available.

## Languages

Per-language tweaks. Most just register extra LSP root patterns, formatters,
or filetypes that the LSP config doesn't catch by default.

- `astro.lua` — Astro (`.astro`) — registered filetype + Tailwind integration
- `docker.lua` — Dockerfile filetype + LSP
- `go.lua` — gofmt, gopls
- `php.lua` — Intelephense + prettier-php
- `python.lua` — ruff (lint + format)
- `tailwind.lua` — tailwindcss-language-server
- `typescript.lua` — vtsls + ts paths

> `laravel.lua` is intentionally commented out — only enable if you actively
> work in a Laravel project.

## Linting

### `lua/plugins/linting/core.lua`
nvim-lint setup. Linters per filetype. Runs on save via the `LspAttach` or
explicit trigger.

### `lua/plugins/linting/phpstan.lua`
phpstan integration. PHP static analysis.

## Test

### `lua/plugins/test/core.lua`
Neotest / test runner setup. Auto-detects most language test frameworks.

## UI

### `lua/plugins/ui/terminal-colors.lua`
Terminal-adopting colorscheme. Queries the host terminal's palette via OSC 4
(ANSI colors) / OSC 10-11 (fg/bg) and maps it onto catppuccin's semantic
slots through `color_overrides`, so nvim matches whatever theme the terminal
is running — and re-tints live when the terminal colorscheme changes (kitty
and wezterm both push palette updates).

Fallback: inside tmux the OSC queries are eaten (tmux doesn't answer them),
so the palette is also read directly from the ACTIVE terminal's config file
— kitty's `~/.config/kitty/colors-matugen.conf` or wezterm's
`~/.config/wezterm/colors/custom.lua` (ml4w writes both on theme switch).
The terminal is detected from env vars that survive into tmux
(`WEZTERM_PANE` / `KITTY_WINDOW_ID`), and the file is polled so theme
switches re-tint live. If no palette source answers, stock catppuccin mocha
is used.

### `lua/plugins/ui/transparency.lua`
Enables background transparency in supported terminals.

### `lua/plugins/ui/dressing.lua`
dressing.nvim. Better `vim.ui.select` and `vim.ui.input` rendering.

### `lua/plugins/ui/treesitter-context.lua`
Pins the current function/class at the top of the window while scrolling.

## Util

### `lua/plugins/util/mini-hipatterns.lua`
mini.hipatterns. Highlights things like hex colors (`#aabbcc`), TODO
keywords, etc. in the buffer without LSP help.
