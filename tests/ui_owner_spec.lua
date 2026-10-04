-- Who owns vim.ui.select and vim.ui.input.
--
-- The bug: dressing and snacks both claim those two. dressing/patch.lua wraps
-- them at REQUIRE time and captures whatever was there then. checkhealth
-- reported the consequence for weeks:
--   ERROR `vim.ui.select` is not set to `Snacks.picker.select`
--   ERROR `vim.ui.input`  is not set to `Snacks.input`
-- ...while the comment in plugins/ui/dressing.lua claimed the opposite. So
-- native LSP and plugin prompts were going to nvim's built-in inputlist()
-- instead of the snacks picker.
--
-- Note the health check itself is not a usable assertion: dressing's wrapper
-- keeps `vim.ui.select` pointing at patch.lua forever, so snacks can never be
-- "the" owner by identity, and snacks' own health check reports the error even
-- when routing is correct. The real assertion is the forwarding target.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/ui_owner_spec.lua
--
-- This spec is the exception to minimal_init.lua's "load nothing" rule: the
-- thing under test is a conflict BETWEEN two loaded plugins, so both have to
-- be loaded exactly as the user loads them. minimal_init puts the config on the
-- runtimepath but NOT lazy's plugin directory, so `require('dressing')` does not
-- resolve and the spec throws at the first require -- which scripts/test.sh
-- reads as a failure with no FAIL line (see the channel-2 note there).
-- So the two plugin dirs this spec needs are prepended explicitly.

local passed, failed = 0, 0
local LAZY = vim.fn.expand '$HOME' .. '/.local/share/nvim/lazy'
vim.opt.runtimepath:prepend(LAZY .. '/dressing.nvim')
vim.opt.runtimepath:prepend(LAZY .. '/snacks.nvim')

-- Put the plugins in the state the USER'S config puts them in, by running the
-- real opts from the real spec file. Requiring the plugins is not enough: with
-- bare `require`, dressing's own defaults apply (select/input both enabled) and
-- every check below fails for a reason that has nothing to do with the user's
-- config. That is the spec testing the plugin instead of the setup, which is
-- the mistake the harness note in undo_isolation_spec warns about in reverse.
--
-- The spec is `return { { name, ... , opts = {...} } }` -- a list of specs -- so
-- take the one that names dressing and apply its opts through the plugin itself.
-- Same tree-relative resolution as the rest of the suite. Expanding $HOME here
-- read the LIVE dressing spec even inside a copy, so the plugin was set up from
-- a different tree's opts than the assertions below were written against.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local real_spec = dofile(root .. '/lua/plugins/ui/dressing.lua')
local entry = real_spec[1]
require('dressing').setup(entry.opts)
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local patch = require 'dressing.patch'
local snacks = require 'snacks'
-- and the config() half, which re-points the capture at snacks
if entry.config then
  entry.config('dressing.nvim', entry.opts)
end

-- --- dressing must not answer prompts -----------------------------------------
-- If either is enabled, dressing's wrapper services the call and the snacks
-- picker never sees it. This is the whole bug in one boolean.
check(
  not patch.is_enabled 'select',
  'dressing.select is enabled, so it swallows every vim.ui.select'
)
check(
  not patch.is_enabled 'input',
  'dressing.input is enabled, so it swallows every vim.ui.input'
)

-- --- and the wrapper must forward to snacks, not to nvim's builtin ------------
-- This is the subtle half. Disabling dressing is NOT enough: patch.lua
-- captured `original_mods` at require time from whatever vim.ui held then,
-- which was /usr/share/nvim/runtime/lua/vim/ui.lua. With the modules merely
-- disabled, every prompt forwards to nvim's inputlist() -- the plain dialog,
-- not a picker. So the capture has to be re-pointed at snacks.
check(
  patch.original_mods.select == snacks.picker.select,
  "dressing forwards vim.ui.select to nvim's builtin, not to Snacks.picker.select"
)
check(
  patch.original_mods.input == snacks.input,
  "dressing forwards vim.ui.input to nvim's builtin, not to Snacks.input"
)

-- --- the end-to-end check: does a real call arrive in snacks? ----------------
-- Every check above inspects state. This one makes an actual vim.ui.select()
-- call and confirms snacks is entered, which is the only thing a user notices.
--
-- The stub goes on `patch.original_mods`, NOT on `snacks.picker.select`. The
-- wrapper captured that reference when dressing loaded, so replacing the
-- snacks field afterwards leaves the wrapper calling the old function and the
-- flag never flips -- which is exactly the false negative this first
-- asserted. Instrument the thing the wrapper actually dereferences.
local hit = false
local real = patch.original_mods.select
patch.original_mods.select = function(...)
  hit = true
  return real(...)
end
local ok = pcall(vim.ui.select, { 'a', 'b' }, {}, function() end)
patch.original_mods.select = real
check(ok, 'vim.ui.select() threw')
check(hit, 'a real vim.ui.select() call did not reach Snacks.picker.select')

-- --- the config that produces this is still there ----------------------------
-- Both halves are load-bearing. Someone tidying away either the `enabled =
-- false` opts or the config() re-point silently restores the bug, and neither
-- shows up as an error at boot.
local src = table
  .concat(vim.fn.readfile(root .. '/lua/plugins/ui/dressing.lua'), '\n')
  :gsub('%-%-[^\n]*', '')

check(
  src:find('enabled = false', 1, true) ~= nil,
  'dressing.lua no longer disables its select/input modules'
)
check(
  src:find('original_mods', 1, true) ~= nil,
  'dressing.lua no longer re-points original_mods at snacks'
)

print(string.format('ui_owner: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd 'cq'
else
  vim.cmd 'qa!'
end
