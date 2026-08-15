local lsp = 'ruff'
local ruff = 'ruff'

return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = { ensure_installed = { 'ninja', 'rst' } },
  },
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        ruff = {
          cmd_env = { RUFF_TRACE = 'messages' },
          init_options = {
            settings = {
              logLevel = 'error',
            },
          },
          keys = {
            {
              '<leader>co',
              function()
                vim.lsp.buf.code_action({
                  apply = true,
                  context = {
                    only = { 'source.organizeImports' },
                    diagnostics = {},
                  },
                })
              end,
              desc = 'Organize Imports',
            },
          },
        },
        ruff_lsp = {
          keys = {
            {
              '<leader>co',
              function()
                vim.lsp.buf.code_action({
                  apply = true,
                  context = {
                    only = { 'source.organizeImports' },
                    diagnostics = {},
                  },
                })
              end,
              desc = 'Organize Imports',
            },
          },
        },
      },
      -- ruff is the single Python server (lint + type-checking + format).
      -- No setup needed — it replaces pyright entirely.
    },
  },
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      local servers =
        { 'pyright', 'basedpyright', 'ruff', 'ruff_lsp', ruff, lsp }
      for _, server in ipairs(servers) do
        opts.servers[server] = opts.servers[server] or {}
        opts.servers[server].enabled = server == lsp or server == ruff
      end
    end,
  },
  {
    'nvim-neotest/neotest',
    optional = true,
    dependencies = {
      'nvim-neotest/neotest-python',
    },
    opts = {
      adapters = {
        ['neotest-python'] = {},
      },
    },
  },
  {
    'hrsh7th/nvim-cmp',
    optional = true,
    opts = function(_, opts)
      opts.auto_brackets = opts.auto_brackets or {}
      table.insert(opts.auto_brackets, 'python')
    end,
  },
  {
    'mfussenegger/nvim-dap',
    optional = true,
    dependencies = {
      'mfussenegger/nvim-dap-python',
      keys = {
        { "<leader>dPt", function() require('dap-python').test_method() end, desc = "Debug Method", ft = "python" },
        { "<leader>dPc", function() require('dap-python').test_class() end, desc = "Debug Class", ft = "python" },
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
    'linux-cultist/venv-selector.nvim',
    branch = 'regexp',
    dependencies = {
      'neovim/nvim-lspconfig',
      'nvim-telescope/telescope.nvim',
      'mfussenegger/nvim-dap-python',
    },
    opts = {},
    keys = {
      { '<leader>vs', '<cmd>VenvSelect<cr>' },
      { '<leader>vc', '<cmd>VenvSelectCached<cr>' },
    },
  },
}
