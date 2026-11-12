return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>cf',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = { 'n', 'v' },
        desc = 'Format buffer / selection',
      },
      {
        '<leader>ua',
        function()
          vim.g.disable_autoformat = not vim.g.disable_autoformat
          vim.notify(
            'Autoformat (global): '
              .. (vim.g.disable_autoformat and 'OFF' or 'ON'),
            vim.log.levels.INFO
          )
        end,
        desc = 'Toggle Autoformat (global)',
      },
      {
        '<leader>uA',
        function()
          vim.b.disable_autoformat = not vim.b.disable_autoformat
          vim.notify(
            'Autoformat (buffer): '
              .. (vim.b.disable_autoformat and 'OFF' or 'ON'),
            vim.log.levels.INFO
          )
        end,
        desc = 'Toggle Autoformat (buffer)',
      },
    },
    init = function()
      vim.api.nvim_create_user_command('FormatToggle', function(args)
        if args.bang then
          vim.b.disable_autoformat = not vim.b.disable_autoformat
        else
          vim.g.disable_autoformat = not vim.g.disable_autoformat
        end
      end, { bang = true, desc = 'Toggle autoformat on save (! = buffer)' })
    end,
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

      -- Check upward from the buffer's directory so subprojects / monorepos
      -- opened from ~ still detect biome.json(c) reliably.
      local function has_biome_config(bufnr)
        local name = vim.api.nvim_buf_get_name(bufnr)
        local path = name ~= '' and vim.fs.dirname(name) or vim.fn.getcwd()
        return vim.fs.find(
          { 'biome.json', 'biome.jsonc' },
          { path = path, upward = true }
        )[1] ~= nil
      end

      local function web_formatters(bufnr)
        if has_biome_config(bufnr) then
          return { 'biome' }
        end
        return { 'bun_fmt', 'prettierd', 'prettier', stop_after_first = true }
      end

      local prettier_or_bun = {
        'bun_fmt',
        'prettierd',
        'prettier',
        stop_after_first = true,
      }

      local opts = {
        notify_on_error = false,
        formatters_by_ft = {
          lua = { 'stylua' },
          astro = { 'prettierd', 'prettier', stop_after_first = true },
          javascript = web_formatters,
          javascriptreact = web_formatters,
          typescript = web_formatters,
          typescriptreact = web_formatters,
          json = web_formatters,
          jsonc = web_formatters,
          css = web_formatters,
          scss = prettier_or_bun,
          less = prettier_or_bun,
          html = prettier_or_bun,
          vue = prettier_or_bun,
          yaml = prettier_or_bun,
          graphql = prettier_or_bun,
          handlebars = prettier_or_bun,
          markdown = prettier_or_bun,
          php = { 'pint' },
          blade = { 'blade-formatter' },
          python = { 'ruff_organize_imports', 'ruff_format' },
          go = { 'gofumpt' },
          sh = { 'shfmt' },
          bash = { 'shfmt' },
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
        format_on_save = function(bufnr)
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
            return
          end
          return {
            timeout_ms = 2000,
            lsp_format = 'fallback',
          }
        end,
      }

      return opts
    end,
  },
}
