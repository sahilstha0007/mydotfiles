-- The snacks modules that were already on disk but never switched on, in their
-- own spec file rather than in plugins/editor/snacks.lua. Same reason as
-- snacks-bufdelete.lua: the main spec is being edited concurrently, and
-- lazy.nvim MERGES specs naming the same plugin, so this composes with it
-- instead of conflicting.
--
-- Every entry point below was read out of the installed plugin rather than
-- assumed -- an earlier draft of this file called Snacks.image.image() and
-- Snacks.scope.select(), neither of which exists. The real functions are
-- image.hover() and scope.textobject().
--
-- Deliberately NOT wired, and why:
--   explorer     -- a second file tree alongside a working nvim-tree. No.
--   git          -- gitsigns already covers status/blame line.
--   toggle       -- the bufferline plugin has its own.
--   win          -- nvim's own window commands are fine.
--   notify       -- a backend for `notifier`, which is already enabled.
--   rename       -- plenary is already a dependency.
--
-- Key choice, after tests/git_keymap_conflicts_spec.lua rejected the first two
-- candidates: <leader>gg is lazygit.nvim's, and <leader>gG is gitbrowse (the
-- comment there claims that key is free -- it isn't any more, and the spec is
-- what says so). <leader>gh is used instead: the other gh* keys are all
-- gitsigns hunk actions, and plain gh was only a which-key group label, so
-- there is no behaviour behind it to shadow.

return {
  'folke/snacks.nvim',

  opts = {
    -- GitHub PR/issue review without leaving nvim. Requires the `gh` CLI
    -- authenticated (gh auth status); unauthenticated, the picker comes up
    -- empty rather than erroring.
    gh = { enabled = true },

    -- Full lazygit UI as a snacks terminal. The CLI is what does the work
    -- (lazygit --version is checked by snacks at setup).
    lazygit = { enabled = true },

    -- Inline preview of png/jpg/webp/gif in the picker, and Snacks.image.hover()
    -- over the buffer. Needs a Nerd Font glyph set, which the terminal already
    -- has (kitty/wezterm config both set one).
    image = { enabled = true },

    -- Filetype-aware scoping. textobject() is what makes `sic`/`sai` select
    -- inside a Lua function or a JSX element rather than the whole line.
    scope = { enabled = true },

    -- No keybindings, just available to call. layout picks a preset window
    -- arrangement; quickfile opens an MRU file picker.
    layout = { enabled = true },
    quickfile = { enabled = true },
  },

  keys = {
    {
      '<leader>gh',
      function()
        Snacks.gh.pr()
      end,
      desc = 'GitHub PRs',
    },
    {
      '<leader>Z',
      function()
        Snacks.lazygit.open()
      end,
      desc = 'Lazygit (snacks terminal)',
    },
    {
      '<leader>Qi',
      function()
        Snacks.image.hover()
      end,
      desc = 'Image Preview (hover)',
    },
    {
      -- Visual mode. textobject() ends by running `normal! v` over the scope it
      -- found, so from normal mode it would drop you into visual selection --
      -- a normal-mode binding for it would never do what its description says.
      -- edge = false selects the INSIDE of the scope (`sic`), which is the
      -- useful default; pass edge = true to include the surrounding block.
      '<leader>ss',
      function()
        Snacks.scope.textobject { edge = false }
      end,
      mode = 'v',
      desc = 'Scope Select (inner)',
    },
  },
}
