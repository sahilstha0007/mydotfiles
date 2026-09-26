-- LSP navigation via snacks.picker — the single picker system (telescope was
-- removed). These handlers run lazily on first use.
return {
  {
    'neovim/nvim-lspconfig',
    opts = function()
      vim.keymap.set('n', 'gd', function()
        require('snacks.picker').lsp_definitions()
      end, { desc = 'Goto Definition' })

      vim.keymap.set('n', 'gr', function()
        require('snacks.picker').lsp_references({ include_current_line = false })
      end, { desc = 'References', nowait = true })

      vim.keymap.set('n', 'gI', function()
        require('snacks.picker').lsp_implementations()
      end, { desc = 'Goto Implementation' })

      vim.keymap.set('n', 'gy', function()
        require('snacks.picker').lsp_type_definitions()
      end, { desc = 'Goto Type Definitions' })
    end,
  },
}
