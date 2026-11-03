return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = function()
      -- Check if bun has native `bun fmt` support (bun >= 1.4.4)
      local has_bun_fmt = nil
      local function is_bun_fmt_available()
        if has_bun_fmt ~= nil then
          return has_bun_fmt
        end
        if vim.fn.executable 'bun' == 0 then
          has_bun_fmt = false
          return false
        end
        local out = vim.fn.system { 'bun', '--version' }
        local v = out:match '(%d+%.%d+%.%d+)'
        has_bun_fmt = (v and vim.version.ge(v, '1.4.4')) and true or false
        return has_bun_fmt
      end

      local opts = {
        formatters_by_ft = {
          lua = { 'stylua' },
          astro = { 'prettier', 'prettierd', stop_after_first = true },
          javascript = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          javascriptreact = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          typescript = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          typescriptreact = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          json = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          jsonc = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          css = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          scss = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          less = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          html = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          vue = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          yaml = { 'bun_fmt', 'prettier', 'prettierd', stop_after_first = true },
          graphql = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          markdown = {
            'bun_fmt',
            'prettier',
            'prettierd',
            stop_after_first = true,
          },
          php = { 'pint' },
          blade = { 'blade-formatter' },
          python = { 'ruff_format' },
        },
        formatters = {
          bun_fmt = {
            command = 'bun',
            args = { 'fmt', '--stdin-filepath', '$FILENAME' },
            stdin = true,
            condition = function()
              return is_bun_fmt_available()
            end,
          },
        },
      }

      opts.format_after_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end

        local filetype = vim.bo[bufnr].filetype

        -- Check if biome.json exists in the project root
        local has_biome = vim.fn.filereadable(vim.fn.getcwd() .. '/biome.json')
            == 1
          or vim.fn.filereadable(vim.fn.getcwd() .. '/biome.jsonc') == 1

        -- Filetypes supported by Biome
        local biome_supported = {
          javascript = true,
          javascriptreact = true,
          typescript = true,
          typescriptreact = true,
          json = true,
          jsonc = true,
          css = true,
        }

        -- Filetypes supported by Bun and Prettier
        local bun_prettier_supported = {
          javascript = true,
          javascriptreact = true,
          typescript = true,
          typescriptreact = true,
          json = true,
          jsonc = true,
          css = true,
          graphql = true,
          handlebars = true,
          html = true,
          less = true,
          markdown = true,
          scss = true,
          vue = true,
          yaml = true,
        }

        -- Prioritize Biome only if biome.json exists and filetype is supported
        if has_biome and biome_supported[filetype] then
          return {
            formatters = { 'biome' },
            timeout_ms = 2000,
          }
        end

        -- Primary: bun fmt, then fallback to Prettier
        if bun_prettier_supported[filetype] then
          return {
            formatters = { 'bun_fmt', 'prettier', 'prettierd' },
            stop_after_first = true,
            timeout_ms = 2000,
          }
        end

        if filetype == 'astro' then
          return {
            formatters = { 'prettier', 'prettierd' },
            stop_after_first = true,
            timeout_ms = 2000,
          }
        end

        return { lsp_format = 'fallback' }
      end

      return opts
    end,
  },
}
