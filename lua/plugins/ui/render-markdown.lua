-- render-markdown: pretty Markdown rendering (headings in theme colors,
-- code blocks with the palette, checkboxes/tables styled) — lazy, only for
-- markdown buffers, no keymaps added.
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {},
  },
}
