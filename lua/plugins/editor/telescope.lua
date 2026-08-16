local kind_filter = {
  default = {
    'Class',
    'Constructor',
    'Enum',
    'Field',
    'Function',
    'Interface',
    'Method',
    'Module',
    'Namespace',
    'Package',
    'Property',
    'Struct',
    'Trait',
  },
  markdown = false,
  help = false,
  lua = {
    'Class',
    'Constructor',
    'Enum',
    'Field',
    'Function',
    'Interface',
    'Method',
    'Module',
    'Namespace',
    -- "Package", -- remove package since luals uses it for control flow structures
    'Property',
    'Struct',
    'Trait',
  },
}

local get_kind_filter = function(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  local ft = vim.bo[buf].filetype

  if kind_filter[ft] == false then
    return
  end

  if type(kind_filter[ft]) == 'table' then
    return kind_filter[ft]
  end

  ---@diagnostic disable-next-line: return-type-mismatch
  return type(kind_filter) == 'table'
      and type(kind_filter.default) == 'table'
      and kind_filter.default
    or nil
end

-- telescope 0.1.5 (pinned tag) still calls the OLD nvim-treesitter API —
-- parsers.ft_to_lang / parsers.get_parser, configs.is_enabled / get_module,
-- locals.get_definitions. The `main`-branch nvim-treesitter (see
-- plugins/coding/treesitter.lua) rewrote all of that away, so those calls
-- crash the previewer with "attempt to call field 'ft_to_lang' (a nil value)".
-- Shim the old modules onto the native vim.treesitter API instead.
local function shim_old_nvim_treesitter_api()
  -- parsers.lua still exists in the rewrite but is a plain metadata table —
  -- patch the missing functions onto it (shared module table, so telescope
  -- sees them).
  local ok, parsers = pcall(require, 'nvim-treesitter.parsers')
  if ok and type(parsers) == 'table' then
    parsers.ft_to_lang = function(ft)
      return vim.treesitter.language.get_lang(ft)
    end
    parsers.get_parser = function(bufnr, lang)
      return vim.treesitter.get_parser(bufnr, lang)
    end
    parsers.has_parser = function(lang)
      return lang ~= nil and pcall(vim.treesitter.get_parser, 0, lang) or false
    end
    parsers.get_buf_lang = function(bufnr)
      return vim.treesitter.language.get_lang(vim.bo[bufnr].filetype)
    end
  end

  -- configs.lua and locals.lua were deleted entirely — provide them.
  package.loaded['nvim-treesitter.configs'] = {
    is_enabled = function(_, lang, bufnr)
      -- "highlight enabled" ≈ the language has a usable parser in this buffer
      return lang ~= nil and pcall(vim.treesitter.get_parser, bufnr, lang)
    end,
    get_module = function()
      -- telescope reads additional_vim_regex_highlighting; keep it off, the
      -- native highlighter already does the work
      return { additional_vim_regex_highlighting = false }
    end,
  }
  -- treesitter symbol picker (builtin.treesitter): no direct native
  -- equivalent — degrade to an empty result rather than crashing
  package.loaded['nvim-treesitter.locals'] = {
    get_definitions = function()
      return {}
    end,
    get_local_nodes = function()
      return {}
    end,
  }
end

return {
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'echasnovski/mini.icons',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
      },
    },
    config = function()
      shim_old_nvim_treesitter_api()
      local telescope = require 'telescope'
      local actions = require 'telescope.actions'

      telescope.setup {
        defaults = {
          mappings = {
            i = {
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
            },
          },
          file_ignore_patterns = { 'node_modules', '.git/' },
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--hidden',
          },
        },
        pickers = {
          find_files = {
            hidden = true,
            follow = true,
          },
          buffers = {
            sort_mru = true,
            sort_lastused = true,
          },
        },
      }

      -- Load fzf native extension for better performance
      telescope.load_extension 'fzf'
    end,
    keys = {
      -- Buffer switching
      {
        '<leader>,',
        '<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>',
        desc = 'Switch Buffer',
      },

      -- Find
      {
        '<leader>fb',
        '<cmd>Telescope buffers sort_mru=true sort_lastused=true<cr>',
        desc = 'Buffers',
      },
      { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Files' },
      {
        '<leader><space>',
        '<cmd>Telescope find_files<cr>',
        desc = 'Find Files',
      },
      { '<leader>fg', '<cmd>Telescope git_files<cr>', desc = 'Git-files' },

      -- Search
      { '<leader>s"', '<cmd>Telescope registers<cr>', desc = 'Registers' },
      {
        '<leader>sa',
        '<cmd>Telescope autocommands<cr>',
        desc = 'Auto Commands',
      },
      {
        '<leader>sb',
        '<cmd>Telescope current_buffer_fuzzy_find<cr>',
        desc = 'Buffer',
      },
      {
        '<leader>sc',
        '<cmd>Telescope command_history<cr>',
        desc = 'Command History',
      },
      { '<leader>sC', '<cmd>Telescope commands<cr>', desc = 'Commands' },
      {
        '<leader>sd',
        '<cmd>Telescope diagnostics bufnr=0<cr>',
        desc = 'Document Diagnostics',
      },
      {
        '<leader>sD',
        '<cmd>Telescope diagnostics<cr>',
        desc = 'Workspace Diagnostics',
      },
      { '<leader>sg', '<cmd>Telescope live_grep<cr>', desc = 'Grep' },
      { '<leader>sh', '<cmd>Telescope help_tags<cr>', desc = 'Help Pages' },
      {
        '<leader>sH',
        '<cmd>Telescope highlights<cr>',
        desc = 'Highlight Groups',
      },
      { '<leader>sj', '<cmd>Telescope jumplist<cr>', desc = 'Jumplist' },
      { '<leader>sk', '<cmd>Telescope keymaps<cr>', desc = 'Key Maps' },
      { '<leader>sl', '<cmd>Telescope loclist<cr>', desc = 'Location List' },
      { '<leader>sM', '<cmd>Telescope man_pages<cr>', desc = 'Man Pages' },
      { '<leader>sm', '<cmd>Telescope marks<cr>', desc = 'Jump to Mark' },
      { '<leader>sR', '<cmd>Telescope resume<cr>', desc = 'Resume' },
      { '<leader>sq', '<cmd>Telescope quickfix<cr>', desc = 'Quickfix List' },
      {
        '<leader>ss',
        function()
          local filters = get_kind_filter()
          if filters then
            require('telescope.builtin').lsp_document_symbols {
              symbols = filters,
            }
          else
            require('telescope.builtin').lsp_document_symbols()
          end
        end,
        desc = 'Symbol (Document)',
      },
      {
        '<leader>sS',
        function()
          local filters = get_kind_filter()
          if filters then
            require('telescope.builtin').lsp_workspace_symbols {
              symbols = filters,
            }
          else
            require('telescope.builtin').lsp_workspace_symbols()
          end
        end,
        desc = 'Symbol (Workspace)',
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    opts = function()
      vim.keymap.set('n', 'gd', function()
        require('telescope.builtin').lsp_definitions {
          reuse_win = true,
        }
      end, { desc = 'Goto Definition' })

      vim.keymap.set('n', 'gr', function()
        require('telescope.builtin').lsp_references {
          include_current_line = false,
        }
      end, { desc = 'References', nowait = true })

      vim.keymap.set('n', 'gI', function()
        require('telescope.builtin').lsp_implementations {
          reuse_win = true,
        }
      end, { desc = 'Goto Implementation' })

      vim.keymap.set('n', 'gy', function()
        require('telescope.builtin').lsp_type_definitions {
          reuse_win = true,
        }
      end, { desc = 'Goto Type Definitions' })
    end,
  },
}
