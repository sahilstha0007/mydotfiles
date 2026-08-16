return {
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main', -- new API; matches nvim-treesitter's main branch
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    event = 'VeryLazy',
    config = function()
      -- Selection textobjects (af/if, ac/ic, ab/ib, aa/ia) are powered by
      -- mini.ai's treesitter spec (see mini.lua), so this plugin only adds the
      -- "jump to next/previous function" motions. `]c`/`[c` are intentionally
      -- skipped — gitsigns already owns those for hunk navigation.
      require('nvim-treesitter-textobjects').setup {
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            [']f'] = '@function.outer',
          },
          goto_previous_start = {
            ['[f'] = '@function.outer',
          },
        },
      }
    end,
  },
}
