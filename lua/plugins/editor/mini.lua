return {
  {
    'echasnovski/mini.nvim',
    event = 'VeryLazy',
    config = function()
      local MiniAi = require 'mini.ai'

      MiniAi.setup {
        n_lines = 500,
        -- Treesitter-powered textobjects layered over the pattern-based
        -- builtins: `af`/`if` (function), `ac`/`ic` (class), `ab`/`ib`
        -- (block), `aa`/`ia` (parameter) now resolve against the real
        -- syntax tree instead of regex guesswork.
        custom_textobjects = {
          a = MiniAi.gen_spec.treesitter({ a = '@parameter.outer', i = '@parameter.inner' }),
          b = MiniAi.gen_spec.treesitter({ a = '@block.outer', i = '@block.inner' }),
          c = MiniAi.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }),
          f = MiniAi.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }),
        },
      }

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

      -- Harpoon-style quick file switching: Space-f-r picks from recently
      -- visited files (mini.visits — the old 'mini.visited-file-ring' name
      -- was dropped in mini.nvim v0.11.0).
      require('mini.visits').setup {}
      vim.keymap.set('n', '<leader>fr', function()
        require('mini.visits').select_path()
      end, { desc = 'File Ring' })

      -- Session persistence: <leader>qq saves, <leader>ql loads last.
      -- snacks.dashboard's session section also reads these.
      require('mini.sessions').setup {
        -- one file per session, kept under stdpath('data')/sessions
        directory = vim.fn.stdpath 'data' .. '/sessions',
      }

      local session_group = vim.api.nvim_create_augroup('mini-sessions', { clear = true })

      -- Auto-save: persist the workspace on exit (skips the fresh-launch
      -- dashboard-only state, which has no real workspace to save).
      vim.api.nvim_create_autocmd('VimLeavePre', {
        group = session_group,
        callback = function()
          local bufname = vim.api.nvim_buf_get_name(0)
          if #vim.api.nvim_list_wins() > 1 or bufname ~= '' then
            MiniSessions.write('last')
          end
        end,
      })

      -- Auto-restore: `nvim <dir>` resumes your last session; bare `nvim`
      -- still shows the dashboard (its Restore Session key reads the same file).
      vim.api.nvim_create_autocmd('VimEnter', {
        group = session_group,
        callback = function()
          if vim.fn.isdirectory(vim.fn.argv(0)) == 1 then
            vim.schedule(function()
              pcall(MiniSessions.read, 'last')
            end)
          end
        end,
      })

      -- write('last') needs an explicit name: a bare write() only saves an
      -- already-active session (v:this_session), so it'd no-op on a fresh launch.
      vim.keymap.set('n', '<leader>qq', '<cmd>lua MiniSessions.write("last")<CR>', { desc = 'Save Session' })
      vim.keymap.set('n', '<leader>ql', '<cmd>lua MiniSessions.read()<CR>', { desc = 'Load Last Session' })
      vim.keymap.set('n', '<leader>qs', '<cmd>lua MiniSessions.select()<CR>', { desc = 'Select Session' })
    end,
  },
}
