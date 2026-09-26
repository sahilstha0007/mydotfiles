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
      --
      -- NOTE: this is the `main` branch, whose setup() only takes
      -- { move = { set_jumps = true } }. The old master-branch config keys
      -- (goto_next_start = { [']f'] = ... }) were silently ignored — the main
      -- branch README defines jumps with explicit vim.keymap.set calls.
      require('nvim-treesitter-textobjects').setup {
        move = {
          set_jumps = true,
        },
      }

      local move = require 'nvim-treesitter-textobjects.move'
      vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
        move.goto_next_start('@function.outer', 'textobjects')
      end, { desc = 'Next function start' })
      vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
        move.goto_previous_start('@function.outer', 'textobjects')
      end, { desc = 'Previous function start' })
    end,
  },
}
