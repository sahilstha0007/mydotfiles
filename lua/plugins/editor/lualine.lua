return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons', 'catppuccin/nvim' },
    config = function()
      -- Eviline config for lualine
      -- Author: shadmansaleh
      -- Credit: glepnir
      local lualine = require 'lualine'

      -- refresh() = build mode colors + apply Lualine* highlight groups
      require('plugins.editor.lualine-theme').refresh()

      -- Re-tint on palette changes: terminal-colors re-runs :colorscheme when
      -- the terminal theme changes, which fires ColorScheme; refresh() rebuilds
      -- the Lualine* groups and the mode→color map from the new palette.
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('lualine-palette', { clear = true }),
        callback = function()
          pcall(require('plugins.editor.lualine-theme').refresh)
        end,
      })

      -- Capture the mode→color map once; it's rebuilt in place by refresh()
      -- on ColorScheme, so lookups stay cheap and stay in sync with palette
      -- changes. (The mode color component runs on every cursor move / mode
      -- change, so anything computed inside it is a hot path.)
      local theme = require('plugins.editor.lualine-theme')
      local mode_color = theme.mode_colors

      local conditions = {
        buffer_not_empty = function()
          return vim.fn.empty(vim.fn.expand '%:t') ~= 1
        end,
        hide_in_width = function()
          return vim.fn.winwidth(0) > 80
        end,
      }

      -- Config
      local config = {
        options = {
          -- Disable sections and component separators
          component_separators = '',
          section_separators = '',
          theme = {
            -- We are going to use lualine_c an lualine_x as left and
            -- right section. Both are highlighted by c theme .  So we
            -- are just setting default looks o statusline
            normal = { c = 'LualineNormalC' },
            inactive = { c = 'LualineInactiveC' },
          },
        },
        sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          -- These will be filled later
          lualine_c = {},
          lualine_x = {},
        },
        inactive_sections = {
          -- these are to remove the defaults
          lualine_a = {},
          lualine_b = {},
          lualine_y = {},
          lualine_z = {},
          lualine_c = {},
          lualine_x = {},
        },
      }

      -- Inserts a component in lualine_c at left section
      local function ins_left(component)
        table.insert(config.sections.lualine_c, component)
      end

      -- Inserts a component in lualine_x at right section
      local function ins_right(component)
        table.insert(config.sections.lualine_x, component)
      end

      ins_left {
        -- mode component
        function()
          return ''
        end,
        color = function()
          -- Cheap per-redraw: a table lookup against the precomputed map.
          -- bg 'NONE' keeps the statusline transparent (see lualine-theme).
          -- theme.refresh() swaps mode_colors in place on ColorScheme, so the
          -- module-level table (captured above as mode_color) follows palette
          -- changes without any lookup cost here.
          return { bg = 'NONE', fg = mode_color[vim.fn.mode()] }
        end,
        padding = { right = 1 },
      }

      ins_left {
        'filename',
        cond = conditions.buffer_not_empty,
        color = 'LualineFilename',
      }

      ins_left {
        'diagnostics',
        sources = { 'nvim_diagnostic' },
        symbols = { error = ' ', warn = ' ', info = ' ' },
        diagnostics_color = {
          error = 'LualineDiagnosticsError',
          warn = 'LualineDiagnosticsWarn',
          info = 'LualineDiagnosticsInfo',
        },
      }

      -- Insert mid section. You can make any number of sections in neovim :)
      -- for lualine it's any number greater then 2
      ins_left {
        function()
          return '%='
        end,
      }

      ins_right {
        function()
          local msg = ''
          local buf_ft = vim.api.nvim_get_option_value('filetype', { buf = 0 })
          local clients = vim.lsp.get_clients()
          if next(clients) == nil then
            return msg
          end
          for _, client in ipairs(clients) do
            local filetypes = client.config.filetypes
            if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
              return client.name
            end
          end
          return msg
        end,
        icon = '󰧑',
        color = 'LualineLsp',
      }

      -- Add components to right sections
      ins_right {
        'branch',
        icon = '',
        color = 'LualineBranch',
      }

      ins_right {
        'diff',
        symbols = { added = ' ', modified = ' ', removed = ' ' },
        diff_color = {
          added = 'LualineDiffAdded',
          modified = 'LualineDiffModified',
          removed = 'LualineDiffRemoved',
        },
        cond = conditions.hide_in_width,
      }

      ins_right {
        function()
          return os.date '%H:%M'
        end,
        icon = '',
        color = 'LualineDiagnosticsWarn',
      }

      lualine.setup(config)
    end,
  },
}
