return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = function()
    -- Icons: every codepoint verified against the installed Nerd Fonts 3.5.0
    -- (JetBrainsMono NFM). The old "fa-/oct-" codepoints this dashboard used
    -- either don't exist in v3.5 or render as unrelated glyphs (the Quit icon
    -- was a clock, Lazy was a "zzz"). nr2char keeps the file free of literal
    -- surrogate-pair characters.
    local function ic(cp)
      return vim.fn.nr2char(cp) .. ' '
    end
    return {
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
            { icon = ic(0xF002), key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },  -- fa-search
            { icon = ic(0xF15B), key = 'n', desc = 'New File', action = ':ene | startinsert' },                     -- fa-file
            { icon = ic(0xF0349), key = 'g', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" }, -- md-magnify
            { icon = ic(0xF0093), key = 't', desc = 'Run Tests', action = ":lua require('neotest').run.run(vim.uv.cwd())" }, -- md-flask
            { icon = ic(0xF02A2), key = 'G', desc = 'LazyGit', action = ':LazyGit' },                              -- md-git
            { icon = ic(0xF02DA), key = 's', desc = 'Restore Session', section = 'session' },                       -- md-history
            { icon = ic(0xF03D3), key = 'l', desc = 'Lazy', action = ':Lazy' },                                    -- md-package
            { icon = ic(0xF06A9), key = 'a', desc = 'AI Agent', action = '<leader>a' },                            -- md-robot
            { icon = ic(0xF0425), key = 'q', desc = 'Quit', action = ':qa' },                                      -- md-power
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
          {
            section = 'terminal',
            cmd = "git rev-parse --git-dir >/dev/null 2>&1 && git status --short --branch || echo 'no git repo here'",
            height = 6,
            padding = 1,
            icon = ic(0xF018D), -- md-console
            title = 'Git Status',
            indent = 2,
          },
          { icon = ic(0xF02DA), title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 }, -- md-history
          { section = 'startup' },
          { section = 'lazy', gap = 1, padding = 1 },
        },
      },
    }
  end,
}
