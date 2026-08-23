# Neovim Config (dotfiles)

This repository is Sahil's Neovim configuration. You are editing an editor config —
every change here affects their daily editing session. Keep edits boring, scoped,
and easy to reason about at 3am.

## Plugin manager & structure

- Uses `lazy.nvim` (bootstrapped in `lua/lazy-init.lua`).
- Structure: each plugin gets its own spec file; `lazy-init.lua` imports them by
  category. There is **no** LazyVim base — it's a Kickstart/NvChad-flavored layout
  under `lua/plugins/`.
- **To add a plugin:** create `lua/plugins/<category>/<name>.lua` and add an
  `{ import = 'plugins.<category>.<name>' }` line to `lua/lazy-init.lua`.
- **To remove a plugin:** delete the spec file **and** its import line. Run
  `:Lazy clean` in nvim afterwards to purge the installed plugin.

## Layout

| Path | What it is |
|------|------------|
| `init.lua` | Entry point |
| `lua/lazy-init.lua` | lazy.nvim bootstrap + plugin import list |
| `lua/globals.lua` | Global settings: netrw disabled, diagnostic signs, **mise shims prepended to PATH** |
| `lua/options.lua` | Core options (`cmdheight=0`, relative numbers, `clipboard=unnamedplus`, wrap on, splitright/below) |
| `lua/keymaps.lua` | Custom keymaps — see below |
| `lua/health.lua` | nvim health checks |
| `lua/plugins/<cat>/<name>.lua` | One plugin spec per file |
| `lsp/<name>.lua` | Standalone LSP server setups |

## Notable setup — don't break these

- **LSPs:** vtsls (TS), gopls (Go), lua_ls, ruff + eslint (Python/JS lint&fmt),
  tailwindcss. Per-server configs in `lsp/`.
- **File tree:** `file-tree` (neo-tree) via `lua/plugins/editor/file-tree.lua`; the
  NeoTree icon-bloat is disabled in `disable-neotree.lua`.
- **Colorscheme:** Terminal-adopting — `lua/plugins/ui/terminal-colors.lua` queries the
  terminal's palette (OSC 4/10/11) and maps it onto catppuccin, re-tinting live when the
  terminal theme changes. Falls back to stock catppuccin mocha outside a capable terminal.
- **Formatting:** `conform` (format-on-save, Prettier for PHP).
- **Linting:** `linting/core` + `phpstan`.
- **Test runner:** `plugins/test/core`.
- **Treesitter:** `lua/plugins/coding/treesitter.lua` — has uncommitted changes at
  the moment; read before editing.
- **dup .bak files:** `lua/lazy-init.lua.bak`, `lua/lazy-init.lua.bak_notify`,
  `lua/plugins/coding/treesitter.lua.bak` are intentional backups. Leave alone.

## Keymaps worth knowing (from `lua/keymaps.lua`)

- `sh` / `sv` — vsplit / hsplit
- `te` — tabedit; `<tab>` / `<s-tab>` — next/prev tab; `<leader><tab>d` — close tab
- `<leader>cr` — LSP rename
- `[b` / `]b` or `<S-h>` / `<S-l>` — prev/next buffer
- `<leader>bd` / `<leader>bo` / `<leader>bD` — delete buffer / delete others / delete buffer+window
- `<C-l>` (insert) — skip past closing brackets/quotes/commas
- **No AI tooling by design:** all AI features were removed at the user's request
  (2026-08: ai-tools.lua launcher, copilot spec, avante earlier — see git history).
  No chat, no completion-assist beyond stock LSP. Do not re-add AI plugins.
</content>
</invoke>