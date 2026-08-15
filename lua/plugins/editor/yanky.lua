return {
  {
    'gbprod/yanky.nvim',
    event = 'VeryLazy',
    opts = {
      ring = {
        storage = 'shada', -- survives restarts (shada is enabled)
      },
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 150,
      },
    },
    keys = {
      {
        '<leader>sy',
        function()
          -- load telescope + the yank_history extension lazily on first use
          require('telescope').load_extension('yank_history')
          require('telescope').extensions.yank_history.yank_history()
        end,
        desc = 'Yank History',
      },
    },
    config = function(_, opts)
      require('yanky').setup(opts)
    end,
  },
}
