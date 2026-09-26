return {
  {
    -- snacks.picker owns vim.ui.select for native LSP/plugin prompts;
    -- dressing fills the gap for vim.ui.input and small selects.
    'stevearc/dressing.nvim',
    event = 'VeryLazy',
    opts = {},
  },
}
