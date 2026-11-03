-- IDE Breadcrumbs in winbar using Treesitter & LSP
return {
  'Bekaboo/dropbar.nvim',
  event = { 'BufReadPost', 'BufWritePost', 'BufNewFile' },
  keys = {
    {
      '<leader>ub',
      function()
        require('dropbar.api').pick()
      end,
      desc = 'Dropbar: pick breadcrumbs',
    },
  },
  opts = {
    bar = {
      enable = function(buf, win)
        return vim.fn.buflisted(buf) == 1
          and vim.bo[buf].buftype == ''
          and not vim.wo[win].diff
      end,
    },
  },
}
