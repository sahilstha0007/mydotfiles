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
      [vim.diagnostic.severity.ERROR] = diagnostic_icons[vim.diagnostic.severity.ERROR],
      [vim.diagnostic.severity.WARN] = diagnostic_icons[vim.diagnostic.severity.WARN],
      [vim.diagnostic.severity.INFO] = diagnostic_icons[vim.diagnostic.severity.INFO],
      [vim.diagnostic.severity.HINT] = diagnostic_icons[vim.diagnostic.severity.HINT],
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
  float = { border = 'rounded', source = 'if_many', wrap = true },
}

-- Disable unused providers to accelerate startup and eliminate health warnings
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

-- Hover and signature help floating windows: wrap lines cleanly
local orig_hover = vim.lsp.handlers.hover
vim.lsp.handlers['textDocument/hover'] = function(err, result, ctx, config)
  return orig_hover(
    err,
    result,
    ctx,
    vim.tbl_extend('force', { border = 'rounded', wrap = true }, config or {})
  )
end

local orig_sig = vim.lsp.handlers.signature_help
vim.lsp.handlers['textDocument/signatureHelp'] = function(
  err,
  result,
  ctx,
  config
)
  return orig_sig(
    err,
    result,
    ctx,
    vim.tbl_extend('force', { border = 'rounded', wrap = true }, config or {})
  )
end

-- Prepend bun bin and mise shims to PATH
vim.env.PATH = vim.env.HOME
  .. '/.bun/bin:'
  .. vim.env.HOME
  .. '/.local/share/mise/shims:'
  .. vim.env.PATH

-- Node.js provider: use Bun's globally managed neovim-node-host when present
local bun_node_host = vim.env.HOME .. '/.bun/bin/neovim-node-host'
if vim.fn.executable(bun_node_host) == 1 then
  vim.g.node_host_prog = bun_node_host
end
