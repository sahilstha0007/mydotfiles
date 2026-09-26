# Neovim Config — Documentation

This folder is the reference for the Neovim config living at `~/config/nvim`.
If you're editing a file and don't remember what it's for, start here.

## What's where

| Doc | Read this when… |
|-----|-----------------|
| [`architecture.md`](architecture.md) | …you want to understand how nvim boots, where plugins come from, or how the file layout is organized. |
| [`plugins.md`](plugins.md) | …you want to know what each plugin spec does, or you're adding/removing a plugin. |
| [`lsp.md`](lsp.md) | …an LSP isn't attaching, you want to add a new language server, or you want to know what `lsp/*.lua` controls. |
| [`keymaps.md`](keymaps.md) | …you forget a keybinding. Lists every custom `<leader>` / normal / visual keymap. |
| [`cheatsheet.md`](cheatsheet.md) | …you want a printable one-page summary of the keymaps and plugins. |
| [`changelog.md`](changelog.md) | …you want to know what changed in the most recent edit session. |

## At a glance

- **Editor:** Neovim (kickstart-style layout, **not** LazyVim).
- **Plugin manager:** `lazy.nvim`, bootstrapped in `lua/lazy-init.lua`.
- **Leader key:** `<space>` (set in `init.lua` and reaffirmed in `globals.lua`).
- **Colors:** Adopts the terminal's own palette live (OSC color queries via `lua/plugins/ui/terminal-colors.lua`).
- **LSPs:** vtsls, gopls, lua_ls, ruff, eslint, tailwindcss.
