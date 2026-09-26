-- Agent/session picker: reachability + the agent-list filter.
--
-- The lesson from the insert-<Tab> work: reading the spec file proves config
-- is WRITTEN, not REACHABLE. Every keymap assertion here probes live `maparg`,
-- and the filter assertions run the real function on the real server payload
-- captured from GET /agent on opencode 1.18.32.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/agent_modes_spec.lua

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local function eq(a, b, msg)
  if vim.deep_equal(a, b) then
    passed = passed + 1
  else
    failed = failed + 1
    print(('FAIL: %s\n  expected: %s\n  actual:   %s'):format(msg, vim.inspect(a), vim.inspect(b)))
  end
end

local M = require('agent-modes')

-- -------------------------------------------------------------- keymaps ---
--
-- Deliberately NOT asserted here. This spec runs under minimal_init, which by
-- design does not load the real config, so NONE of the <leader>a* keymaps
-- exist in this process -- `maparg` returns nil for all of them, including
-- the ten this file must not clobber. Proving reachability in an environment
-- that does not load the config proves nothing (the insert-<Tab> lesson).
-- Keymap reachability is asserted against the live config instead; see
-- docs_dev/progress.md, session 6.

-- ---------------------------------------------------------------- filter ---

-- Payload captured live from GET /agent (opencode 1.18.32). Note `hidden` on
-- compaction/summary/title: those are internal, not modes a person picks.
local live = {
  { name = 'build', description = 'The default agent.', mode = 'primary' },
  { name = 'compaction', description = '', mode = 'primary', hidden = true },
  { name = 'explore', description = 'explores', mode = 'subagent' },
  { name = 'general', description = 'general', mode = 'subagent' },
  { name = 'plan', description = 'researches first', mode = 'primary' },
  { name = 'summary', description = '', mode = 'primary', hidden = true },
  { name = 'title', description = '', mode = 'primary', hidden = true },
}

eq({ 'build', 'plan' }, vim.tbl_map(function(a)
  return a.name
end, M._pickable(live)), 'pickable keeps only build + plan')

for _, a in ipairs(M._pickable(live)) do
  check(not a.hidden, a.name .. ' is hidden but survived the filter')
  check(a.mode == 'primary', a.name .. ' is a subagent but survived the filter')
end

eq({}, M._pickable({}), 'empty list is handled')
eq({}, M._pickable(nil), 'nil list is handled')
eq(7, #live, 'the caller list was mutated by _pickable')

-- A custom agent the user defines (opencode.json agent block) is primary and
-- not hidden, so it must appear -- the picker is not hardcoded to two.
local custom = { name = 'reviewer', description = 'reads diffs', mode = 'primary' }
eq({ 'reviewer' }, vim.tbl_map(function(a)
  return a.name
end, M._pickable({ custom })), 'a custom primary agent appears')

-- --------------------------------------------------------------- report ---

print(('\nagent_modes: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  vim.cmd('cq')
end
