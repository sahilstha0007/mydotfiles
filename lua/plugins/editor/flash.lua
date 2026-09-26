return {
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    ---@type flash.Config
    opts = {},
    keys = {
      -- `s` is the stock flash jump (1 key, n/x/o). Freed by moving the old
      -- sh/sv splits to <leader>| / <leader>- (see lua/keymaps.lua).
      {
        's',
        mode = { 'n', 'x', 'o' },
        function()
          require('flash').jump()
        end,
        desc = 'Flash: jump to any visible word',
      },
      -- Visual/operator `S`: treesitter search — type to select nodes,
      -- replaces within selection. (Normal `S` = substitute-line is kept;
      -- use `cc` if you ever need line-substitute.)
      {
        'S',
        mode = { 'o', 'x' },
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
