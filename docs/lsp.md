# LSP Setup

How language servers are wired up, and what each one does.

## Layered setup

There are two layers:

1. **`lua/plugins/coding/lspconfig.lua`** — installs `nvim-lspconfig` and calls
   `lspconfig.<server>.setup(...)` for every server. This is the registration
   step.
2. **`lsp/<server>.lua`** — per-server overrides. Each file exports a table of
   settings (root detection, capabilities, on-attach hooks, init options).
   The plugin spec imports these and passes them as the `settings` argument to
   `lspconfig.<server>.setup`.

This split exists so per-server tuning lives in a small focused file rather
than a 400-line god-spec.

## Servers installed

| Server | Languages | Notes |
|--------|-----------|-------|
| `vtsls` | TypeScript, TSX, JavaScript | TS-language-service replacement; faster than `tsserver`. |
| `gopls` | Go | Default Go LSP. |
| `lua_ls` | Lua | LSP for editing nvim config itself. |
| `ruff` | Python | Replaces `pyright` + `flake8`. Lint + format. |
| `eslint` | JS/TS | Linting only; formatting goes through `prettier`. |
| `tailwindcss` | CSS, HTML, JSX, TSX, Astro, Vue | Tailwind class completions. |

## Install path

Servers are installed via **Mason** (`mason.nvim` is loaded by `lspconfig.lua`).
First nvim launch shows a Mason popup; once binaries are installed they live
under `~/.local/share/nvim/mason/`.

If a server fails to attach:

- `:Mason` — see what's installed, what's missing.
- `:LspInfo` — see which clients are attached to the current buffer.
- `:LspLog` — recent errors.
- `:checkhealth` — global sanity check.

## `lsp/<server>.lua` — file conventions

Each file returns a table the plugin spec consumes:

```lua
return {
  cmd = { 'ruff-lsp' },                    -- command to spawn
  filetypes = { 'python' },                -- when to attach
  root_dir = function(fname) ... end,      -- project-root detection
  settings = { ... },                      -- LSP-specific options
  on_attach = function(client, bufnr) ... end,
}
```

To add a new server:

1. Drop a new `<server>.lua` into `lsp/`.
2. Add `{ import = 'lsp.<server>' }` (or equivalent) in
   `lua/plugins/coding/lspconfig.lua`.
3. `:LspInfo` to confirm it attaches on the right filetypes.

## LspAttach autocmd

`lua/lazy-init.lua` (after the `require('lazy').setup` block) defines an
`LspAttach` autocmd that strips `<leader>ca` on buffers whose server doesn't
support `textDocument/codeAction`. This is the cheap way to silence
"keymap doesn't work" surprises without per-server fiddling.

If you find the same pattern duplicated inside an `lsp/<server>.lua`,
keep the centralized one — they do the same thing and the centralized one
covers every server.

## LSP keymaps (standard, from lspconfig.lua)

These are added on attach for every server:

- `gd` — go to definition
- `gD` — go to declaration
- `gr` — references
- `gI` — implementation
- `K` — hover docs
- `<leader>ca` — code action (when supported)
- `<leader>cr` — rename (from `lua/keymaps.lua`)