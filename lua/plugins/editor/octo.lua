-- Octo: GitHub issues, PRs, and discussions from inside nvim (gh CLI
-- backend). Picker backend is snacks (telescope was removed), so every
-- list/search renders in the same glass UI as the rest of the editor.
return {
  {
    'pwntester/octo.nvim',
    cmd = { 'Octo' },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'folke/snacks.nvim',
    },
    opts = {
      -- snacks is the single picker (telescope/fzf removed from the stack)
      picker = 'snacks',
      -- bare `Octo` opens a picker of all subcommands (issue/pr/discussion...)
      enable_builtin = true,
      -- resolve repos via the remote actually present in the project
      default_remote = { 'origin', 'upstream' },
      -- squash by default (matches the team's history style)
      default_merge_method = 'squash',
      -- reviews: show the diff on the right like diffview
      reviews = { focus = 'right', show_virtual_text = true },
      ui = { use_statuscolumn = true, use_signcolumn = false },
    },
    keys = {
      { '<leader>pi', '<cmd>Octo issue list<CR>', desc = 'Issues' },
      { '<leader>pr', '<cmd>Octo pr list<CR>', desc = 'Pull Requests' },
      { '<leader>pd', '<cmd>Octo discussion list<CR>', desc = 'Discussions' },
      {
        '<leader>pn',
        '<cmd>Octo notification list<CR>',
        desc = 'Notifications',
      },
      {
        '<leader>ps',
        function()
          require('octo.utils').create_base_search_command {
            include_current_repo = true,
          }
        end,
        desc = 'Search GitHub',
      },
    },
    config = function(_, opts)
      -- Octo needs `gh` authenticated. If not, all Octo commands fail silently.
      -- Check at setup so the user knows why rather than wondering later.
      local gh_ok, gh = pcall(require, 'os.execute')
      local gh_auth = vim.fn.system 'gh auth status 2>&1'
      if vim.v.shell_error ~= 0 then
        vim.notify(
          'octo: `gh` CLI not authenticated. Run `gh auth login` to enable GitHub integration.',
          vim.log.levels.WARN,
          { title = 'octo.nvim' }
        )
      end
      require('octo').setup(opts)
      -- Octo defines its own stock Octo* highlight groups at setup, which
      -- clobber the wallpaper-themed ones from terminal-colors.lua. Re-assert
      -- the current palette so catppuccin's highlight_overrides (including
      -- the Octo section) re-apply over them.
      --
      -- This must go through terminal-colors.reassert(), NOT a bare
      -- `colorscheme catppuccin`: that rebuilds from whichever
      -- color_overrides were set last, so if a wallpaper change has landed
      -- since, it would silently revert the palette to a stale one.
      local ok, tc = pcall(require, 'plugins.ui.terminal-colors')
      if ok and type(tc.reassert) == 'function' then
        tc.reassert()
      end
    end,
  },
}
