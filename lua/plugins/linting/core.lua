return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'

      lint.linters = lint.linters or {}
      lint.linters.phpstan = require 'plugins.linting.phpstan'

      lint.linters_by_ft = lint.linters_by_ft or {}
      lint.linters_by_ft['php'] = { 'phpstan' }

      -- No JS linters configured - using ESLint LSP instead

      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd(
        { 'BufEnter', 'BufWritePost', 'InsertLeave' },
        {
          group = lint_augroup,
          callback = function()
            if not vim.opt_local.modifiable:get() then
              return
            end

            lint.try_lint(nil, { ignore_errors = true })
          end,
        }
      )
    end,
  },
}
