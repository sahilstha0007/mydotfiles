---
name: add-plugin
description: Scaffold a new lazy.nvim plugin spec + wire its import into lazy-init.lua. Invoke with a plugin name and category.
---

# add-plugin

One-command repeatable way to add a plugin to this nvim dotfiles repo.

## Shortcuts
- `/add-plugin foo` → name `foo`, prompt for category
- `/add-plugin lsp tailwindcss` → name `tailwindcss`, category `lsp` (uses `lua/plugins/lsp/`)

## Steps

1. Arg 1 = plugin name (last path segment). Arg 2 = category; if missing, ask: coding, dap, editor, formatting, languages, linting, test, ui, util.
2. Read the existing spec template — copy the shape from an adjacent plugin file in that category (block-format, `{ import = ... }`, `config = function()` etc.).
3. Create `lua/plugins/<category>/<name>.lua` with the new plugin spec.
4. Append `{ import = 'plugins.<category>.<name>' }` to the imports table in `lua/lazy-init.lua`.
5. Tell the user to run `:Lazy` in nvim (or `:Lazy sync`) to install, and `:Lazy clean` if they ever remove a plugin.

## Removing a plugin

Delete `lua/plugins/<category>/<name>.lua` **and** its import line in `lua/lazy-init.lua`, then tell the user to run `:Lazy clean`.