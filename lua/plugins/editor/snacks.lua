return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    -- modern & smooth: subtle animations for UI components
    animate = { enabled = true },
    -- dim unfocused windows
    dim = { enabled = true },
    -- thin indent guides
    indent = { enabled = true },
    -- fancy notifications (replaces vim.notify)
    notifier = { enabled = true },
    picker = { enabled = true },
    -- smooth scrolling
    scroll = { enabled = true },
    -- highlight the word under the cursor (LSP-aware fallback)
    words = { enabled = true },

    -- dashboard start screen
    dashboard = {
      enabled = true,
      width = 72,
      preset = {
        keys = {
          { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
          { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
          { icon = ' ', key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = '󰙨 ', key = 't', desc = 'Run Tests', action = ":lua require('neotest').run.run(vim.uv.cwd())" },
          { icon = '󰊢 ', key = 'G', desc = 'LazyGit', action = ':LazyGit' },
          { icon = '󰁯 ', key = 's', desc = 'Restore Session', section = 'session' },
          { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy' },
          { icon = '󰩭 ', key = 'a', desc = 'AI Agent', action = '<leader>a' },
          { icon = '󰥔 ', key = 'q', desc = 'Quit', action = ':qa' },
        },
        header = [[
███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝╚══════╝ ╚═════╝  ╚═══╝ ╚═╝╚═╝     ╚═╝]],
      },
      sections = {
        { section = 'header' },
        { section = 'keys', gap = 1, padding = 1 },
        { icon = ' ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 },
        { section = 'startup' },
        { section = 'lazy', gap = 1, padding = 1 },
      },
    },
  },
}
