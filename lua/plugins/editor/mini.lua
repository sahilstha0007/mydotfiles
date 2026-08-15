return {
  {
    'echasnovski/mini.nvim',
    event = 'VeryLazy',
    config = function()
      require('mini.ai').setup { n_lines = 500 }

      require('mini.surround').setup {
        mappings = {
          add = 'gsa',
          delete = 'gsd',
          find = 'gsf',
          find_left = 'gsF',
          highlight = 'gsh',
          replace = 'gsr',
          update_n_lines = 'gsn',
        },
      }

      require('mini.move').setup {
        mappings = {
          left = 'H',
          right = 'L',
          down = 'J',
          up = 'K',
          line_left = '',
          line_right = '',
          line_down = '',
          line_up = '',
        },
      }

      -- Harpoon-style quick file switching: Space-f-r opens a ring of
      -- recently visited files (used by snacks dashboard's session section too).
      require('mini.visited-file-ring').setup {}
      vim.keymap.set('n', '<leader>fr', function()
        require('mini.visited-file-ring').open()
      end, { desc = 'File Ring' })

      -- Session persistence: <leader>qq saves, <leader>ql loads last.
      -- snacks.dashboard's session section also reads these.
      require('mini.sessions').setup {
        -- one file per session, kept under stdpath('data')/sessions
        directory = vim.fn.stdpath 'data' .. '/sessions',
      }
      -- write('last') needs an explicit name: a bare write() only saves an
      -- already-active session (v:this_session), so it'd no-op on a fresh launch.
      vim.keymap.set('n', '<leader>qq', '<cmd>lua MiniSessions.write("last")<CR>', { desc = 'Save Session' })
      vim.keymap.set('n', '<leader>ql', '<cmd>lua MiniSessions.read()<CR>', { desc = 'Load Last Session' })
      vim.keymap.set('n', '<leader>qs', '<cmd>lua MiniSessions.select()<CR>', { desc = 'Select Session' })
    end,
  },
}
