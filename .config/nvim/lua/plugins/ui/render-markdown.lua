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
    opts = {
      heading = {
        sign = true,
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
        position = 'overlay',
      },
      code = {
        sign = false,
        width = 'block',
        left_pad = 2,
        right_pad = 2,
        min_width = 45,
        border = 'thin',
      },
      pipe_table = {
        preset = 'round',
        cell = 'padded',
        padding = 1,
      },
      bullet = {
        icons = { '●', '○', '◆', '◇' },
      },
      checkbox = {
        enabled = true,
      },
    },
  },
}
