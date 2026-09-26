-- Show context of the current function/class at the top of the window.
return {
  'nvim-treesitter/nvim-treesitter-context',
  event = { 'BufReadPost', 'BufWritePost', 'BufNewFile' },
  keys = {
    {
      '<leader>ut',
      function()
        require('treesitter-context').toggle()
      end,
      desc = 'Toggle Treesitter Context',
    },
  },
  opts = { mode = 'cursor', max_lines = 3 },
}
