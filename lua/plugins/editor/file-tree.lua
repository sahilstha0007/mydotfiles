return {
  {
    'nvim-tree/nvim-tree.lua',
    version = '*',
    -- Lazy-loaded: pulled in on <leader>e, :NvimTree*, or opening a directory.
    cmd = { 'NvimTreeOpen', 'NvimTreeToggle', 'NvimTreeFocus', 'NvimTreeFindFile' },
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'nvim-lua/plenary.nvim',
      'MunifTanjim/nui.nvim',
    },
    keys = {
      { '<leader>e', '<cmd>NvimTreeToggle<cr>', desc = 'Open Explorer' },
    },
    init = function()
      -- `nvim <dir>` still opens the tree, even though the plugin is lazy.
      vim.api.nvim_create_autocmd('BufEnter', {
        group = vim.api.nvim_create_augroup('nvim-tree-dir-open', { clear = true }),
        callback = function()
          local file = vim.fn.expand '%:p'
          if vim.fn.isdirectory(file) == 1 then
            vim.cmd.cd(file)
            pcall(vim.cmd, 'NvimTreeOpen')
          end
        end,
      })
    end,
    opts = {
      reload_on_bufenter = true,
      hijack_cursor = true,
      -- nvim-tree clears netrw's FileExplorer augroup on setup
      -- (nvim-tree/config.lua:534-536, gated on `hijack_netrw`). This config
      -- disables netrwPlugin (lazy-init.lua:80), and netrwPlugin.vim is the
      -- ONLY thing that creates that group -- so the clear runs against a
      -- group that does not exist and startup dies with
      --   E216: No such group or event: FileExplorer *
      -- The `silent!` nvim-tree wraps it in does not help: that suppresses
      -- errors from *running* a command, not the E216 raised while *parsing*
      -- it. nvim-tree already owns the directory (hijack_directories, <leader>e),
      -- so the netrw hijack has nothing left to do -- turning it off is also
      -- the correct behaviour, not just a way to dodge the error.
      hijack_netrw = false,
      disable_netrw = true,
      sync_root_with_cwd = true,
      hijack_unnamed_buffer_when_opening = true,
      auto_reload_on_write = true,
      diagnostics = {
        enable = false,
      },
      hijack_directories = {
        enable = true,
        auto_open = true,
      },
      actions = {
        open_file = {
          quit_on_open = true,
          resize_window = true,
        },
      },
      update_focused_file = {
        enable = true,
      },
      view = {
        centralize_selection = true,
        adaptive_size = false,
        side = 'right',
        preserve_window_proportions = true,
        width = 40,
      },
      renderer = {
        full_name = false,
        indent_markers = {
          enable = false,
        },
        root_folder_label = ':t',
        -- Collapse single-child directory chains (lua/nvim-tree -> one node).
        -- Toggle at runtime with 'L'.
        group_empty = true,
        highlight_git = 'name', -- string form; boolean true here is deprecated
      },
      filters = {
        dotfiles = false,
        git_ignored = false,
        git_clean = false,
        no_buffer = false,
      },
      git = {
        enable = true,
        timeout = 1000,
      },
    },
    config = function(_, opts)
      local nvimtree = require 'nvim-tree'

      local function keybindings(bufnr)
        local api = require 'nvim-tree.api'

        local function ops(desc)
          return {
            desc = 'nvim-tree: ' .. desc,
            buffer = bufnr,
            noremap = true,
            silent = true,
            nowait = true,
          }
        end

        -- default mappings
        api.config.mappings.default_on_attach(bufnr)

        -- custom mappings
        vim.keymap.set('n', 'P', api.node.open.preview, ops 'Preview')
        -- api names are "vertical"/"horizontal" = the split line, so
        -- vertical = side-by-side windows, horizontal = stacked windows.
        vim.keymap.set(
          'n',
          's',
          api.node.open.vertical_no_picker,
          ops 'Open Side-by-side (vsplit)'
        )
        vim.keymap.set(
          'n',
          'S',
          api.node.open.horizontal_no_picker,
          ops 'Open Stacked (split)'
        )
      end

      opts.on_attach = keybindings

      nvimtree.setup(opts)
    end,
  },
  {
    'antosha417/nvim-lsp-file-operations',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    config = true,
  },
}
