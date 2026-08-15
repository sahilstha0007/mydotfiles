-- Leader key: space. Must be set before any keymap with <leader> is defined.
-- (Also set in init.lua; both must run before lazy/keymap loads.)
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Prevent Netrw from showing up at beginning
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.diagnostic.config {
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = ' ',
      [vim.diagnostic.severity.WARN] = ' ',
      [vim.diagnostic.severity.INFO] = '󰋼 ',
      [vim.diagnostic.severity.HINT] = ' ',
    },
  },
  severity_sort = true,
}

-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH
