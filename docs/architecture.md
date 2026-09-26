# Architecture

How this Neovim config is wired together.

## Boot order

`init.lua` is the only file Neovim auto-sources. It does four things, in order:

1. Sets `vim.g.mapleader` and `vim.g.maplocalleader` to space.
2. Sets `vim.g.have_nerd_font = true` so `lazy.nvim` uses Nerd Font icons.
3. `require 'globals'` — netrw disable, diagnostic sign glyphs, PATH prepend for mise.
4. `require 'options'` — every `vim.opt.*` setting.
5. `require 'keymaps'` — all custom keymaps.
6. `require 'lazy-init'` — bootstraps `lazy.nvim` and tells it to load every plugin spec.

**Why the order matters:** `mapleader` MUST be set before any `<leader>` keymap is
parsed, otherwise the bindings get bound to the default `\`. Setting it in both
`init.lua` (top of file, runs before anything else) and `globals.lua` (defensive
duplicate) means it never gets missed, even if someone reorders later.

## File layout

```
~/config/nvim/
├── init.lua                  # entry point
├── lazy-lock.json            # pinned plugin versions
├── lazyvim.json              # lazy.nvim settings
├── stylua.toml               # Lua formatting config
├── docs/                     # you are here
├── lsp/                      # per-language-server configs
│   ├── eslint.lua
│   ├── gopls.lua
│   ├── lua_ls.lua
│   ├── ruff.lua
│   ├── tailwindcss.lua
│   └── vtsls.lua
├── lua/
│   ├── globals.lua           # vim.g settings + mise PATH + diagnostics
│   ├── options.lua           # vim.opt.* core options
│   ├── keymaps.lua           # custom keymaps
│   ├── health.lua            # :checkhealth implementation
│   ├── lazy-init.lua         # bootstrap lazy.nvim + plugin import list
│   └── plugins/
│       ├── coding/           # LSP config, completion, treesitter, AI
│       ├── dap/              # debug adapter
│       ├── editor/           # nav, UI helpers, git, keymap helpers
│       ├── formatting/       # conform + prettier
│       ├── languages/        # per-language plugin tweaks
│       ├── linting/          # nvim-lint + phpstan
│       ├── test/             # test runner
│       ├── ui/               # colorscheme, dressing, transparency
│       └── util/             # mini-hipatterns
└── lazy/                     # lazy.nvim's installed-plugin cache (gitignored)
```

## Plugin management

### Adding a plugin

1. Create `lua/plugins/<category>/<name>.lua`.
   The spec returns a `lazy.nvim` spec table (see `plugins.md` for examples).
2. Add `{ import = 'plugins.<category>.<name>' }` to the `spec` table in
   `lua/lazy-init.lua`. Keep them grouped by category, in alphabetical order
   inside that category.
3. Restart Neovim. `:Lazy` opens the UI and installs on first launch.

### Removing a plugin

1. Delete the spec file.
2. Remove its `{ import = … }` line from `lazy-init.lua`.
3. Inside nvim, run `:Lazy clean` to actually uninstall.

### Disabling without removing

Comment out the `{ import = … }` line in `lazy-init.lua` with `--`.
The spec file stays in the repo but lazy won't load it. Use this when
debugging ("is this plugin causing the bug?").

## LSP

LSPs are split into two layers:

- **`lua/plugins/coding/lspconfig.lua`** — pulls in `nvim-lspconfig` and calls
  `lspconfig.<server>.setup(...)` for every server.
- **`lsp/<server>.lua`** — per-server overrides (root patterns, settings, capabilities).

The full architecture and the per-server reasoning is in [`lsp.md`](lsp.md).

## Keymaps

Every keymap is defined either in `lua/keymaps.lua` (custom bindings not
belonging to a specific plugin) or inline in a plugin spec (bindings that
should only be active when that plugin is loaded — `which-key`, snacks,
overseer, etc.).

See [`keymaps.md`](keymaps.md) for the full list grouped by purpose.

## What's intentionally NOT here

- **No LazyVim.** This is a Kickstart-style layout: each plugin gets its own
  small spec. Bigger than LazyVim to maintain, smaller and easier to reason
  about at 3am. The trade is documented.
