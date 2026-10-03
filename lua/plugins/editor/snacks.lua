return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  keys = {
    {
      '<leader>l',
      function()
        -- Smart popup for lazy.nvim: pick an action instead of typing :Lazy
        -- subcommands. The dashboard's `l` key still opens the full Lazy UI.
        local actions = {
          { name = 'Sync',    desc = 'Install & update pinned plugins', cmd = ':Lazy sync' },
          { name = 'Install', desc = 'Install missing plugins',         cmd = ':Lazy install' },
          { name = 'Update',  desc = 'Update installed plugins',        cmd = ':Lazy update' },
          { name = 'Clean',   desc = 'Remove unused plugins',           cmd = ':Lazy clean' },
          { name = 'Check',   desc = 'Validate plugin specs',           cmd = ':Lazy check' },
          { name = 'Restore', desc = 'Restore plugins from lockfile',   cmd = ':Lazy restore' },
          { name = 'Profile', desc = 'Startup / load profiling',        cmd = ':Lazy profile' },
          { name = 'Health',  desc = 'Run :checkhealth for a plugin',   cmd = ':Lazy health' },
          { name = 'Log',     desc = 'Open the lazy.nvim log',          cmd = ':Lazy log' },
          { name = 'Debug',   desc = 'Debug lazy.nvim loading',         cmd = ':Lazy debug' },
          { name = 'Open UI', desc = 'Open the lazy.nvim dashboard',    cmd = ':Lazy' },
        }
        Snacks.picker.select(actions, {
          prompt = 'Lazy actions',
          format_item = function(action)
            return action.name .. '  ' .. action.desc
          end,
        }, function(action)
          if action then
            vim.cmd(action.cmd)
          end
        end)
      end,
      desc = 'Lazy actions (sync, update, clean, ...)',
    },
    -- ---- single picker system (telescope removed): find/search/symbol ----
    -- bindings open snacks.picker, which also owns vim.ui.select.
    { '<leader>,',   function() Snacks.picker.buffers() end, desc = 'Switch Buffer' },
    { '<leader>fb',  function() Snacks.picker.buffers() end, desc = 'Buffers' },
    { '<leader>ff',  function() Snacks.picker.files() end, desc = 'Files' },
    { '<leader><space>', function() Snacks.picker.files() end, desc = 'Find Files' },
    { '<leader>fg',  function() Snacks.picker.git_files() end, desc = 'Git-files' },
    -- Terminal toggle (snacks.terminal): <C-/> mirrors VSCode's terminal
    -- key. Terminals send C-/ as C-_, so map both spellings. Needs t-mode
    -- too: snacks installs no in-terminal keymaps of its own, and lazy's
    -- default key mode is n — without this the toggle can open a terminal
    -- but <C-/> inside it goes to the shell instead of closing it.
    -- <C-/> HIDES, never closes. A `:terminal` buffer defaults to
    -- bufhidden=wipe, so a close destroys the buffer and its scrollback, and
    -- the next <C-/> builds a fresh empty terminal -- which is why "something I
    -- ran yesterday" is unscrollable today. Hide keeps the buffer (and the
    -- running job) alive with no window; snacks reuses the same buffer on
    -- reopen because it keys on {cmd,cwd,env,count}, so you get the scrollback
    -- back rather than a rerun. The buffer is found by a jobs/command scan that
    -- also matches a `:term` opened outside snacks, so hiding is the safe
    -- direction: worst case you re-enter a terminal that is still there.
    --
    -- <C-_> stays a true toggle -- same as snacks' default -- so clearing is
    -- still one keystroke if you want the buffer gone.
    { '<C-/>',       function() Snacks.terminal.hide() end, mode = { 'n', 't' }, desc = 'Terminal (hide)' },
    { '<C-_>',       function() Snacks.terminal.toggle() end, mode = { 'n', 't' }, desc = 'Terminal (toggle)' },
    { '<leader>ft',  function() Snacks.terminal.toggle() end, desc = 'Terminal (toggle, cwd)' },
    { '<leader>fT',  function() Snacks.terminal.toggle(nil, { cwd = Snacks.git.get_root() }) end, desc = 'Terminal (toggle, git root)' },
    -- lazydocker float: the docker TUI over the editor, mirroring tmux's
    -- Prefix+d popup and lazygit.nvim's <leader>gg float. UPPERCASE D —
    -- lowercase <leader>d is the DAP debug group (dap/core.lua). toggle()
    -- re-press closes it; auto_close ends the float when lazydocker exits.
    { '<leader>D',   function() Snacks.terminal.toggle('lazydocker', { cwd = vim.fn.getcwd(), auto_close = true }) end, desc = 'LazyDocker (docker TUI float)' },
    -- zen mode: distraction-free zoom (toggles back on Esc or <leader>z)
    { '<leader>z',  function() Snacks.zen() end, desc = 'Zen Mode (toggle)' },
    { '<leader>Z',  function() Snacks.zen.zoom() end, desc = 'Zoom (window only)' },
    -- gitbrowse: open current file/line on GitHub (what's selected on remote).
    --
    -- This was <leader>gB, which gitsigns' on_attach also binds (buffer-local)
    -- to the full blame popup. gitsigns won every real buffer, so the binding
    -- below was unreachable dead code -- and AGENT.md:99, docs/keymaps.md:107
    -- and learn-nvim.html all documented <leader>gB as the blame popup.
    -- The blame mapping is the one four sources agree on, so it keeps the key
    -- and gitbrowse moves here. <leader>gG is free (nothing binds it) and sits
    -- next to <leader>gg lazygit, which is the "leave the editor" end of the
    -- group. tests/git_keymap_conflicts_spec.lua fails if this key is ever
    -- bound twice again.
    { '<leader>gG', function() Snacks.gitbrowse() end, desc = 'Open on GitHub (gitbrowse)' },
    { '<leader>s"',  function() Snacks.picker.registers() end, desc = 'Registers' },
    { '<leader>sa',  function() Snacks.picker.autocmds() end, desc = 'Auto Commands' },
    { '<leader>sb',  function() Snacks.picker.lines() end, desc = 'Buffer' },
    { '<leader>sc',  function() Snacks.picker.command_history() end, desc = 'Command History' },
    { '<leader>sC',  function() Snacks.picker.commands() end, desc = 'Commands' },
    { '<leader>sd',  function() Snacks.picker.diagnostics({ bufnum = 0 }) end, desc = 'Document Diagnostics' },
    { '<leader>sD',  function() Snacks.picker.diagnostics() end, desc = 'Workspace Diagnostics' },
    { '<leader>sg',  function() Snacks.picker.grep() end, desc = 'Grep' },
    { '<leader>sh',  function() Snacks.picker.help() end, desc = 'Help Pages' },
    { '<leader>sH',  function() Snacks.picker.highlights() end, desc = 'Highlight Groups' },
    { '<leader>sj',  function() Snacks.picker.jumps() end, desc = 'Jumplist' },
    { '<leader>sk',  function() Snacks.picker.keymaps() end, desc = 'Key Maps' },
    { '<leader>sl',  function() Snacks.picker.loclist() end, desc = 'Location List' },
    { '<leader>sM',  function() Snacks.picker.man() end, desc = 'Man Pages' },
    { '<leader>sm',  function() Snacks.picker.marks() end, desc = 'Jump to Mark' },
    { '<leader>sR',  function() Snacks.picker.resume() end, desc = 'Resume' },
    { '<leader>sq',  function() Snacks.picker.qflist() end, desc = 'Quickfix List' },
    { '<leader>ss',  function() Snacks.picker.lsp_symbols() end, desc = 'Symbol (Document)' },
    { '<leader>sS',  function() Snacks.picker.lsp_workspace_symbols() end, desc = 'Symbol (Workspace)' },
  },
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

    -- Terminal scrollback survives until you deliberately clear it.
    --
    -- `bufhidden=hide` is the whole fix. A `:terminal` buffer defaults to
    -- `wipe`, so the moment the last window showing a terminal goes away the
    -- buffer AND its scrollback are destroyed -- <C-_>, q, or any window close.
    -- `hide` keeps the buffer (and the running job) alive with no window, and
    -- reopening the same terminal (snacks keys on {cmd,cwd,env,count}) restores
    -- the scrollback instead of starting a fresh one. That is the difference
    -- between "I can scroll back to yesterday's output" and "it is gone and I
    -- have to rerun it".
    --
    -- Nothing auto-wipes: a hidden terminal is a real buffer that shows up in
    -- `:ls`, so clearing one is deliberate -- `bd!`, or Snacks.terminal.close()
    -- which is what <C-_> reaches.
    --
    -- ponytail: hidden terminals are never reclaimed, so a session that opens
    -- many distinct ones accumulates buffers. Add a cap if `:ls` ever gets
    -- long enough to be annoying.
    local TERMINAL_OPTS = { terminal = { bo = { bufhidden = 'hide' } } }

    -- -------------------------------------------------------------
    -- Gradient NEOVIM header
    -- -------------------------------------------------------------
    -- Each art row is painted with a hue from the LIVE catppuccin palette
    -- (the same palette terminal-colors overrides from the wallpaper/terminal
    -- OSC answers), so the header follows theme switches like every other
    -- highlight. Per-row highlight groups keep the gradient when the
    -- dashboard redraws, and a ColorScheme hook re-tints on the fly.
    local art = {
      '███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗',
      '████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║',
      '██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║',
      '██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║',
      '██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║',
      '╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝',
    }
    -- top → bottom; tweak the hues to taste (any catppuccin palette key)
    local hue_ramp = { 'mauve', 'blue', 'sapphire', 'sky', 'teal', 'green' }
    local function tint_header()
      local palette = require('utils.theme').palette()
      for i, hue in ipairs(hue_ramp) do
        vim.api.nvim_set_hl(0, 'DashboardHeader' .. i, { fg = palette[hue] })
      end
    end
    tint_header()
    vim.api.nvim_create_autocmd('ColorScheme', {
      group = vim.api.nvim_create_augroup('dashboard-header-tint', { clear = true }),
      callback = tint_header,
    })
    local header_rows = {}
    for i, line in ipairs(art) do
      header_rows[i] = { line, hl = 'DashboardHeader' .. i }
    end
    return {
      -- keep terminal scrollback: see TERMINAL_OPTS above for why
      terminal = TERMINAL_OPTS.terminal,
      -- modern & smooth: subtle animations for UI components
      animate = { enabled = true },
      -- dim unfocused windows
      dim = { enabled = true },
      -- thin indent guides
      indent = { enabled = true },
      -- big files: auto-disable treesitter/LSP/etc above ~1.5MB —
      -- opening a 100k-line lockfile or minified bundle stops choking
      bigfile = { enabled = true },
      -- fancy notifications (replaces vim.notify)
      notifier = { enabled = true },
      -- quick scope/func context via <leader>z — distraction-free coding
      -- (deactivates indent/dim temporarily; snacks handles restore)
      zen = { enabled = true },
      -- gitbrowse: open the file/line under cursor on GitHub (gh CLI era
      -- companion to octo) — <leader>gB picks remote, copies URL too
      gitbrowse = { enabled = true },
      -- statuscolumn: fold signs + git signs + diagnostic signs inline
      -- (pairs with ufo's foldtext; lualine stays the statusline)
      statuscolumn = { enabled = true },
      -- vim.ui.input via snacks (readline-style, snacks-styled); picks
      -- still go through snacks.picker. dressing stays for ui.select only.
      input = { enabled = true },
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
            { icon = ic(0xF0425), key = 'q', desc = 'Quit', action = ':qa' },                                      -- md-power
          },
          header = header_rows,
        },
        sections = {
          { section = 'header' },
          { section = 'keys', gap = 1, padding = 1 },
          {
            icon = ic(0xF024B), -- md-folder
            title = 'Projects',
            section = 'projects',
            indent = 2,
            padding = 1,
          },
          {
            section = 'terminal',
            cmd = "git rev-parse --git-dir >/dev/null 2>&1 && git status --short --branch || echo 'no git repo here'",
            height = 4,
            padding = 1,
            icon = ic(0xF018D), -- md-console
            title = 'Git Status',
            indent = 2,
          },
          { icon = ic(0xF02DA), title = 'Recent Files', section = 'recent_files', indent = 2, padding = 1 }, -- md-history
          -- startup renders the plugin-load stats (startuptime, loaded/count),
          -- which is what the old `lazy` section used to show
          { section = 'startup' },
        },
      },
    }
  end,
}
