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
      'mfussenegger/nvim-dap-python',
    },
    opts = {
      options = {
        -- deterministic UI: snacks.picker (telescope removed)
        picker = 'snacks',
      },
    },
    keys = {
      { '<leader>vs', '<cmd>VenvSelect<cr>' },
      { '<leader>vc', '<cmd>VenvSelectCached<cr>' },
    },
  },
}