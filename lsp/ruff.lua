-- Ruff (Python linter/formatter LSP). Hover is disabled so pyright owns it.
return {
  cmd_env = { RUFF_TRACE = 'messages' },
  init_options = {
    settings = {
      logLevel = 'error',
    },
  },
  on_attach = function(client, bufnr)
    client.server_capabilities.hoverProvider = false

    -- Organize imports (was stuck inside a dead opts.servers block in
    -- plugins/languages/python.lua).
    vim.keymap.set('n', '<leader>co', function()
      vim.lsp.buf.code_action {
        apply = true,
        context = {
          only = { 'source.organizeImports' },
          diagnostics = {},
        },
      }
    end, { buffer = bufnr, desc = 'ruff: Organize Imports' })
  end,
}
