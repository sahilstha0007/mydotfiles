return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    opts = function()
      local opts = {
        formatters_by_ft = {
          lua = { 'stylua' },
          astro = { 'prettier', 'prettierd' },
          javascript = { 'biome' },
          javascriptreact = { 'biome' },
          typescript = { 'biome' },
          typescriptreact = { 'biome' },
          json = { 'biome' },
          jsonc = { 'biome' },
          css = { 'biome' },
          graphql = { 'prettier', 'prettierd' },
          html = { 'prettier', 'prettierd' },
          less = { 'prettier', 'prettierd' },
          scss = { 'prettier', 'prettierd' },
          vue = { 'prettier', 'prettierd' },
          yaml = { 'prettier', 'prettierd' },
          php = { 'pint' },
          blade = { 'blade-formatter' },
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

        -- Filetypes supported by both Biome and Prettier
        local biome_supported = {
          javascript = true,
          javascriptreact = true,
          typescript = true,
          typescriptreact = true,
          json = true,
          jsonc = true,
          css = true,
        }

        -- Filetypes only supported by Prettier
        local prettier_only = {
          graphql = true,
          handlebars = true,
          html = true,
          less = true,
          scss = true,
          vue = true,
          yaml = true,
        }

        -- Prioritize Biome if biome.json exists and filetype is supported
        if has_biome and biome_supported[filetype] then
          return {
            formatters = { 'biome' },
            timeout_ms = 2000,
          }
        end

        -- Fallback to Prettier for supported filetypes
        if biome_supported[filetype] or prettier_only[filetype] then
          return {
            formatters = { 'prettier', 'prettierd' },
            timeout_ms = 2000,
          }
        end

        return { lsp_format = 'fallback' }
      end

      return opts
    end,
  },
}
