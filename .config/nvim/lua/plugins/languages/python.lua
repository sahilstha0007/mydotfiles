return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = { ensure_installed = { 'ninja', 'rst' } },
  },
  {
    'nvim-neotest/neotest',
    optional = true,
    dependencies = {
      'nvim-neotest/neotest-python',
    },
    -- NOTE: no `opts.adapters` entry here — neotest-python is already wired
    -- in plugins/test/core.lua; adding it again registered the adapter twice.
  },
  {
    'mfussenegger/nvim-dap',
    optional = true,
    dependencies = {
      'mfussenegger/nvim-dap-python',
      keys = {
        {
          '<leader>dPt',
          function()
            require('dap-python').test_method()
          end,
          desc = 'Debug Method',
          ft = 'python',
        },
        {
          '<leader>dPc',
          function()
            require('dap-python').test_class()
          end,
          desc = 'Debug Class',
          ft = 'python',
        },
      },
      config = function()
        if vim.fn.has 'win32' == 1 then
          require('dap-python').setup(
            vim.env.MASON
              .. '/packages/'
              .. 'debugpy'
              .. '/venv/Scripts/pythonw.exe'
          )
        else
          require('dap-python').setup(
            vim.env.MASON .. '/packages/' .. 'debugpy' .. '/venv/bin/python'
            -- NOTE: vim.env.MASON is set by mason.nvim at runtime, not by the shell.
            -- If it is nil here, the Python DAP adapter path will be wrong at debug time.
            -- Verify with `:lua =vim.env.MASON` after nvim starts.
          )
        end
      end,
    },
  },
  {
    'jay-babu/mason-nvim-dap.nvim',
    optional = true,
    opts = {
      handlers = {
        python = function() end,
      },
    },
  },
  {
    -- Upstream merged the `regexp` branch into `main` (2025-08-27). Pinning the
    -- old branch made every setup() pop an ERROR telling us to remove the pin,
    -- and the branch no longer gets fixes. Do not re-add `branch = 'regexp'`.
    'linux-cultist/venv-selector.nvim',
    -- Load on Python files, not only on the keymap: main auto-restores the venv
    -- cached for the project root on BufEnter/FileType, which cannot happen if
    -- the plugin is still unloaded. Picker stays explicit (telescope is gone).
    ft = 'python',
    dependencies = {
      'neovim/nvim-lspconfig',
      'mfussenegger/nvim-dap-python',
    },
    opts = {
      options = {
        -- deterministic UI: snacks.picker (telescope removed)
        picker = 'snacks',
        -- Auto-restore is silent by design: no popup when a cached venv is
        -- applied, and no error toast for a venv that moved away.
        notify_user_on_venv_activation = false,
        cached_venv_automatic_activation = true,
        search_timeout = 5,
      },
    },
    keys = {
      { '<leader>vs', '<cmd>VenvSelect<cr>', desc = 'Venv: select' },
      -- NOT :VenvSelectCached. main only registers that command when
      -- cached_venv_automatic_activation = false; with auto on (our case) the
      -- command does not exist and the key would throw E492. Call the same Lua
      -- entrypoint the autocmd uses, as a manual retry.
      {
        '<leader>vc',
        function()
          require('venv-selector.cached_venv').ensure_cached_venv_activated(
            vim.api.nvim_get_current_buf()
          )
        end,
        desc = 'Venv: re-apply cached',
      },
    },
  },
}
