return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = {
      ensure_installed = {
        'php',
      },
    },
  },
  {
    'mfussenegger/nvim-dap',
    optional = true,
    opts = function()
      local dap = require 'dap'
      local mason_pkg = vim.fn.expand '$MASON/packages/php-debug-adapter'
      if mason_pkg == '$MASON/packages/php-debug-adapter' then
        vim.notify(
          'MASON env var not set — PHP DAP adapter path will be wrong',
          vim.log.levels.WARN
        )
      end
      dap.adapters.php = {
        type = 'executable',
        command = 'node',
        args = { mason_pkg .. '/extension/out/phpDebug.js' },
      }
    end,
  },
}
