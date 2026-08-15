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
    { import = 'plugins.editor.disable-neotree' },
    { import = 'plugins.editor.ai-tools' },
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
    { import = 'plugins.test.core' },
--  { import = 'plugins.ui.colorscheme' },
    { import = 'plugins.ui.matugen' },         
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
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- Prevent codeAction alerts on buffers backed by basic LSPs
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and not client.supports_method("textDocument/codeAction") then
      pcall(vim.keymap.del, "n", "<leader>ca", { buffer = ev.buf })
      pcall(vim.keymap.del, "v", "<leader>ca", { buffer = ev.buf })
    end
  end,
})
