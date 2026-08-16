return {
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type flash.Config
    opts = {},
    keys = {
      -- NOTE: flash's stock `s` key is NOT used here — `sh`/`sv` are already
      -- taken by the split keymaps. Flash lives under the Find group instead.
      {
        '<leader>fj',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash: jump to any visible word',
      },
      {
        '<leader>ft',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').treesitter()
        end,
        desc = 'Flash: jump to treesitter node',
      },
      {
        'R',
        mode = { 'o', 'x' },
        function()
          require('flash').treesitter_search()
        end,
        desc = 'Flash: treesitter search',
      },
      {
        '<c-s>',
        mode = { 'c' },
        function()
          require('flash').toggle()
        end,
        desc = 'Flash: toggle search highlighting',
      },
    },
  },
}
