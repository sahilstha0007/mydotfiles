local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

vim.g.lazyvim_check_order = false

require('lazy').setup({
  spec = {
    'tpope/vim-sleuth',
    { import = 'plugins.coding.autopairs' },
    { import = 'plugins.coding.cmp' },
    { import = 'plugins.coding.lspconfig' },
    { import = 'plugins.coding.todo-comments' },
    { import = 'plugins.coding.textobjects' },
    { import = 'plugins.coding.treesitter' },
    { import = 'plugins.coding.trouble' },
    { import = 'plugins.dap.core' },
    -- { import = 'plugins.editor.fzf' },
    { import = 'plugins.editor.gitsigns' },
    { import = 'plugins.editor.grug-far' },
    { import = 'plugins.editor.hardtime' },
    { import = 'plugins.editor.lazygit' },
    { import = 'plugins.editor.lualine' },
    { import = 'plugins.editor.mini' },
    { import = 'plugins.editor.file-tree' },
    { import = 'plugins.editor.flash' },
    { import = 'plugins.editor.disable-neotree' },
    { import = 'plugins.editor.ai-tools' },
    { import = 'plugins.editor.bufferline' },
    { import = 'plugins.editor.diffview' },
    { import = 'plugins.editor.overseer' },
    { import = 'plugins.editor.snacks' },
    { import = 'plugins.editor.telescope' },
    { import = 'plugins.editor.tmux' },
    { import = 'plugins.editor.ufo' },
    { import = 'plugins.editor.which-key' },
    { import = 'plugins.editor.yanky' },
    { import = 'plugins.formatting.conform' },
    { import = 'plugins.languages.astro' },
    { import = 'plugins.languages.docker' },
    { import = 'plugins.languages.go' },
    -- { import = 'plugins.languages.laravel' },
    { import = 'plugins.languages.php' },
    { import = 'plugins.languages.python' },
    { import = 'plugins.languages.tailwind' },
    { import = 'plugins.languages.typescript' },
    { import = 'plugins.linting.core' },
    -- note: plugins/linting/phpstan.lua is NOT a plugin spec — it's a
    -- nvim-lint linter definition loaded via require() from linting/core.lua
    { import = 'plugins.test.core' },
    { import = 'plugins.ui.terminal-colors' },
    { import = 'plugins.ui.transparency' },
    { import = 'plugins.ui.dressing' },
    { import = 'plugins.ui.treesitter-context' },
    { import = 'plugins.util.mini-hipatterns' },
  },
  defaults = {},
  performance = {
    rtp = {
      disabled_plugins = {
        'gzip',
        'tarPlugin',
        'zipPlugin',
        'netrwPlugin',
        'spellfile',
      },
    },
  },
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    -- Fallback only used when have_nerd_font is false; glyphs are verified
    -- Nerd Fonts 3.5 codepoints (no emoji — emoji aren't in the font and
    -- would render as boxes if this table ever became active).
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = vim.fn.nr2char(0xF0493), -- md-cog
      event = vim.fn.nr2char(0xF00ED), -- md-calendar
      ft = vim.fn.nr2char(0xF024B),    -- md-folder
      init = vim.fn.nr2char(0xF040A),  -- md-play
      keys = vim.fn.nr2char(0xF030C),  -- md-keyboard
      plugin = vim.fn.nr2char(0xF0431), -- md-puzzle
      runtime = vim.fn.nr2char(0xF018D), -- md-console
      require = vim.fn.nr2char(0xF01DA), -- md-download
      source = vim.fn.nr2char(0xF0214), -- md-file
      start = vim.fn.nr2char(0xF040A), -- md-play
      task = vim.fn.nr2char(0xF012C),  -- md-check
      lazy = vim.fn.nr2char(0xF04B2) .. ' ', -- md-sleep
    },
  },
})

-- Prevent codeAction alerts on buffers backed by basic LSPs
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and not client:supports_method("textDocument/codeAction") then
      pcall(vim.keymap.del, "n", "<leader>ca", { buffer = ev.buf })
      pcall(vim.keymap.del, "v", "<leader>ca", { buffer = ev.buf })
    end
  end,
})
