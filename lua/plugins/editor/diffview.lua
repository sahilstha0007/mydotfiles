return {
  {
    'sindrets/diffview.nvim',
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewToggleFiles', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gD', '<cmd>DiffviewOpen<CR>', desc = 'Diffview: open diff' },
      { '<leader>gH', '<cmd>DiffviewFileHistory<CR>', desc = 'Diffview: file history' },
      { '<leader>gq', '<cmd>DiffviewClose<CR>', desc = 'Diffview: close' },
    },
    config = function()
      require('diffview').setup {
        view = {
          default = { layout = 'diff2_horizontal' },
        },
        file_panel = {
          width = 35,
          win_config = { winopts = { number = false } },
        },
      }
    end,
  },
}
