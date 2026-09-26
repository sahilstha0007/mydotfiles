return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = { ensure_installed = { 'go', 'gomod', 'gowork', 'gosum' } },
  },
  {
    'fredrikaverpil/neotest-golang',
  },
  {
    -- Go DAP: launch config for the delve adapter (installed via mason-nvim-dap
    -- in plugins/dap/core.lua). `Space d c` on a Go file now just works.
    'mfussenegger/nvim-dap',
    optional = true,
    opts = function()
      local dap = require 'dap'
      dap.configurations.go = dap.configurations.go or {}
      table.insert(dap.configurations.go, {
        type = 'delve',
        request = 'launch',
        name = 'Debug (dlv)',
        program = '${file}',
        cwd = '${workspaceFolder}',
      })
    end,
  },
}