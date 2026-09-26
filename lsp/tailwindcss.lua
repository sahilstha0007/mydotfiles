-- Tailwind CSS language server.
--
-- NOTE: the markdown filetypes exclusion lives in plugins/coding/lspconfig.lua
-- (explicit `vim.lsp.config` call). A `filetypes` array here would be
-- overridden by nvim-lspconfig's bundled config, which merges over user
-- `lsp/*.lua` files.
return {
  settings = {
    tailwindCSS = {
      includeLanguages = {
        elixir = 'html-eex',
        eelixir = 'html-eex',
        heex = 'html-eex',
      },
    },
  },
}