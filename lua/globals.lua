-- Leader key: space. Must be set before any keymap with <leader> is defined.
-- (Also set in init.lua; both must run before lazy/keymap loads.)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Prevent Netrw from showing up at beginning
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Diagnostics: sign-column icons + one clean inline line per problem.
-- The colored undercurl is what makes errors readable at a glance; tmux's
-- Smulx/Setulc overrides (tmux.conf) make it survive inside tmux.
local diagnostic_icons = {
  [vim.diagnostic.severity.ERROR] = '󰅚 ',
  [vim.diagnostic.severity.WARN] = '󰀪 ',
  [vim.diagnostic.severity.INFO] = '󰋽 ',
  [vim.diagnostic.severity.HINT] = '󰌵 ',
}

vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = ' ',
      [vim.diagnostic.severity.WARN] = ' ',
      [vim.diagnostic.severity.INFO] = '󰋼 ',
      [vim.diagnostic.severity.HINT] = ' ',
    },
  },
  virtual_text = {
    spacing = 2,
    prefix = function(diagnostic)
      return diagnostic_icons[diagnostic.severity] or ' '
    end,
    -- collapse multi-line messages into one clean line (LSPs love walls)
    format = function(diagnostic)
      return diagnostic.message
        :gsub('\n', ' ')
        :gsub('\t', ' ')
        :gsub('%s+', ' ')
        :gsub('^%s+', '')
        :gsub('%s+$', '')
    end,
  },
  underline = true,
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
}

-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH
