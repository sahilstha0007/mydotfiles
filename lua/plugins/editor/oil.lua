-- oil.nvim — edit the filesystem like a buffer (S-tier per the 2026
-- community consensus: rename/move/create by editing text, :w applies).
-- Pairs with (does not replace) nvim-tree: <leader>e stays the tree,
-- `-` toggles oil for the current dir. Both live side by side in top
-- configs.
return {
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      default_file_explorer = false, -- nvim-tree keeps <leader>e
      columns = { 'icon', 'size', 'mtime' },
      keymaps = {
        ['<C-h>'] = false, -- keep tmux.nvim pane-left jump
        ['<C-l>'] = false, -- keep the insert-mode skip map (separate mode, but avoid surprise)
      },
      view_options = {
        show_hidden = true,
      },
      float = {
        padding = 4,
        max_width = math.floor(vim.o.columns * 0.7),
        max_height = math.floor(vim.o.lines * 0.85),
        border = 'rounded',
        win_options = {
          winblend = 25, -- matches the frosted-glass float style
        },
      },
    },
    keys = {
      { '-', '<cmd>Oil<cr>', desc = 'Open parent dir (oil)' },
      -- NOTE: float is on <leader>O (uppercase) — <leader>o is the Overseer
      -- Tasks prefix group (ot, or, ol, oq, oa…), so a direct <leader>o
      -- map would shadow the group in which-key.
      { '<leader>O', '<cmd>Oil --float<cr>', desc = 'Oil (float) — edit dir as buffer' },
    },
    cmd = 'Oil',
  },
}
