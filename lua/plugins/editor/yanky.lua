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
        -- YankyRingHistory renders through vim.ui.select — which snacks
        -- picker now owns (telescope removed)
        '<cmd>YankyRingHistory<cr>',
        desc = 'Yank History',
      },
      -- Put with yanky (enables post-put cycling through the yank ring)
      { 'p',  '<Plug>(YankyPutAfter)',  mode = { 'n', 'x' }, desc = 'Yanky Put After' },
      { 'P',  '<Plug>(YankyPutBefore)', mode = { 'n', 'x' }, desc = 'Yanky Put Before' },
      { 'gp', '<Plug>(YankyGPutAfter)', mode = { 'n', 'x' }, desc = 'Yanky GPut After' },
      { 'gP', '<Plug>(YankyGPutBefore)', mode = { 'n', 'x' }, desc = 'Yanky GPut Before' },
      -- Cycle the last put through yank-ring entries (like Emacs kill-ring)
      { ']p', '<Plug>(YankyCycleForward)', mode = { 'n', 'x' }, desc = 'Yanky Cycle Forward' },
      { '[p', '<Plug>(YankyCycleBackward)', mode = { 'n', 'x' }, desc = 'Yanky Cycle Backward' },
    },
    config = function(_, opts)
      require('yanky').setup(opts)
    end,
  },
}
