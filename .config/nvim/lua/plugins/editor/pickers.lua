-- LSP navigation via snacks.picker — the single picker system (telescope was
-- removed). These handlers run lazily on first use.
return {
  {
    'neovim/nvim-lspconfig',
    opts = function()
      vim.keymap.set('n', 'gd', function()
        require('snacks.picker').lsp_definitions()
      end, { desc = 'Goto Definition' })

      vim.keymap.set('n', 'gD', function()
        require('snacks.picker').lsp_declarations()
      end, { desc = 'Goto Declaration' })

      vim.keymap.set('n', 'gr', function()
        require('snacks.picker').lsp_references { include_current_line = false }
      end, { desc = 'References', nowait = true })

      vim.keymap.set('n', 'gI', function()
        require('snacks.picker').lsp_implementations()
      end, { desc = 'Goto Implementation' })

      vim.keymap.set('n', 'gy', function()
        require('snacks.picker').lsp_type_definitions()
      end, { desc = 'Goto Type Definitions' })

      vim.keymap.set('n', '<leader>ci', function()
        require('snacks.picker').lsp_incoming_calls()
      end, { desc = 'Incoming Calls (LSP)' })

      vim.keymap.set('n', '<leader>cI', function()
        require('snacks.picker').lsp_outgoing_calls()
      end, { desc = 'Outgoing Calls (LSP)' })
    end,
  },
}
