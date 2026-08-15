return {
  {
    -- fzf-lua is disabled (telescope is the picker), so dressing handles
    -- both vim.ui.select and vim.ui.input with its own defaults.
    'stevearc/dressing.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
