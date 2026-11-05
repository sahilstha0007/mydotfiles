-- The syntax hierarchy is a plain module that terminal-colors.lua calls, not a
-- lazy spec, so nothing in the plugin system reports when it stops running. It
-- already did once: it was written as a bare { event, priority, callback }
-- spec, lazy rejected it with "Invalid plugin spec", and the demotion never
-- happened — green suite, no error anywhere. This pins the behaviour itself.
--
-- Self-contained on purpose. The spec suite runs under tests/minimal_init.lua,
-- which deliberately does NOT load the full config, and `nvim -l` skips
-- init.lua entirely — so under either runner lazy is absent. A test that needs
-- lazy has no runner in this repo. So instead of asserting "lazy wired it up",
-- this sets a known palette and asserts the hierarchy moves it. Same contract,
-- no dependency on how it gets loaded.

vim.opt.runtimepath:prepend(
  vim.env.NVIM_CONFIG_ROOT
    or vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
)

local failed = 0
local function check(ok, msg)
  if ok then
    print('  ok   ' .. msg)
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

-- A known starting palette, standing in for whatever terminal-colors adopts.
-- Lightness ordering is what the demotion relies on, so pick slots that are
-- genuinely ordered: NonText < LineNr < Normal.
local set = vim.api.nvim_set_hl
set(0, 'Normal', { fg = '#cdd6f4' })
set(0, 'NonText', { fg = '#585b70' })
set(0, 'LineNr', { fg = '#7f849c' })
set(0, 'Comment', { fg = '#6c7086' })
set(0, 'CursorLine', { fg = '#45475a' })
set(0, 'DiagnosticError', { fg = '#f38ba8' })
set(0, 'DiagnosticWarn', { fg = '#f9e2af' })

-- Before: the groups the hierarchy owns are unset.
check(
  vim.api.nvim_get_hl(0, { name = '@punctuation' }).fg == nil,
  'premise: @punctuation unset'
)

local ok, err = pcall(function()
  require('plugins.ui.hierarchy').apply()
end)
check(ok, 'hierarchy.apply() runs without error: ' .. tostring(err))

local function fg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
end

local punctuation, text, operator =
  fg '@punctuation', fg 'Normal', fg '@operator'
check(punctuation ~= nil, '@punctuation got a concrete fg (not left as a link)')
check(operator ~= nil, '@operator got a concrete fg')
check(
  punctuation < text,
  string.format(
    '@punctuation #%06x is dimmer than Normal #%06x',
    punctuation or 0,
    text or 0
  )
)
check(
  operator < text,
  string.format(
    '@operator #%06x is dimmer than Normal #%06x',
    operator or 0,
    text or 0
  )
)
check(
  fg '@punctuation.bracket' == punctuation,
  '@punctuation.bracket tracks @punctuation'
)
check(
  fg '@comment.todo' == fg 'DiagnosticWarn',
  '@comment.todo is promoted to the warn colour'
)
check(fg 'CursorLineNr' == text, 'CursorLineNr promoted to full text weight')

-- The promotion must also survive a manual colorscheme change: that is the
-- autocmd the module registers, and it is the one that was silently missing.
vim.api.nvim_exec_autocmds('ColorScheme', {})
check(
  fg '@punctuation' == punctuation,
  'hierarchy survives a ColorScheme event'
)

if failed > 0 then
  error(string.format('syntax-hierarchy: %d assertion(s) failed', failed))
end
print 'syntax-hierarchy: ok'
