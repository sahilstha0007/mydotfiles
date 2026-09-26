local failures = {}

local function test(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    table.insert(failures, name .. ': ' .. tostring(err))
  end
end

local function check(value, message)
  if not value then
    error(message or 'check failed', 2)
  end
end

local root = '/home/sahil/.config/nvim'
vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend('/home/sahil/.local/share/nvim/lazy/opencode.nvim')

local ask_calls = {}
local notifications = {}
local terminal_opens = 0
package.loaded['agent-panel'] = {
  setup = function() end,
  toggle = function() end,
}
package.loaded['opencode'] = {
  ask = function(default)
    table.insert(ask_calls, default)
  end,
}
package.loaded['snacks.terminal'] = {
  open = function()
    terminal_opens = terminal_opens + 1
    return {}
  end,
  get = function()
    return nil
  end,
}

-- Stands in for the unsaved-changes prompt. `nil` models the user cancelling;
-- a table models a choice. Assigning a function counts invocations, which is
-- how the "unrelated modified buffer must not prompt" test observes it without
-- reaching into the harness.
local picker_result = { id = 'save', label = 'Save and ask' }
_G.__picker_result = function()
  return picker_result
end
package.loaded['Snacks'] = {
  picker = {
    select = function(_, _)
      return _G.__picker_result()
    end,
  },
}
_G.Snacks = package.loaded['Snacks']

local original_system = vim.system
local original_systemlist = vim.fn.systemlist
local original_notify = vim.notify
vim.system = function()
  return {
    wait = function()
      return { code = 1, stdout = '', stderr = '' }
    end,
  }
end
vim.fn.systemlist = function()
  return {}
end
vim.notify = function(message)
  table.insert(notifications, message)
end

local spec = dofile(root .. '/lua/plugins/editor/opencode-agent.lua')
spec.config()

local function restore()
  vim.system = original_system
  vim.fn.systemlist = original_systemlist
  vim.notify = original_notify
end

-- This test used to assert the OPPOSITE of what it should have: that
-- @buffers/@visible/@marks are ABSENT. They were absent, and that was the bug.
--
-- `require('opencode.config')` resolves its defaults once, then this config
-- ASSIGNED `opts.contexts = contexts` over them, which deleted every context
-- the plugin ships with -- including @this, the selection/cursor range. Asking
-- about a highlighted region silently sent the whole buffer instead, so the
-- agent answered a different question confidently. The assignment also made
-- every context listed in vim.g.opencode_opts dead code.
--
-- The correct invariant is: the plugin's builtins survive, ours are added on
-- top, and the builtins we do NOT auto-inject stay out of the ask prompt
-- (that is a separate, deliberate choice about token cost -- see below).
test('plugin contexts survive config; ours are added', function()
  local contexts = require('opencode.config').opts.contexts
  for _, name in ipairs {
    '@this',
    '@buffer',
    '@buffers',
    '@diagnostics',
    '@marks',
    '@quickfix',
    '@visible',
  } do
    check(type(contexts[name]) == 'function', 'plugin context ' .. name .. ' was lost')
  end
  check(type(contexts['@agents']) == 'function', 'our @agents context is missing')
  check(
    contexts['@agents']({ server = { cwd = '/home/sahil/docs_dev/fixtures/opencode-harness' }, format = function() return 'AGENTS.md' end }) == 'AGENTS.md',
    'root AGENTS.md context did not resolve'
  )
end)

test('double start opens one terminal', function()
  local start = require('opencode.config').opts.server.start
  start()
  start()
  check(terminal_opens == 1, 'expected one terminal open, got ' .. terminal_opens)
end)

-- Unsaved-buffer handling. The old behaviour was a hard refusal with a notify,
-- which was safe but useless: the buffer you most want to ask about is the one
-- mid-edit. autoread=1 means the agent's write would otherwise reload the
-- buffer and silently replace unsaved work, so the guard is still needed --
-- but the user chooses now.
test('unsaved buffer: cancel does not reach OpenCode', function()
  local path = vim.fn.tempname()
  vim.fn.writefile({ 'saved' }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })

  local before = #ask_calls
  picker_result = nil -- user cancelled
  require('plugins.editor.opencode-harness').ask()
  check(#ask_calls == before, 'cancelled prompt still reached OpenCode')
  check(vim.bo.modified, 'cancel left the buffer modified-but-handled')
end)

test('unsaved buffer: save-and-ask reaches OpenCode with the file written', function()
  local path = vim.fn.tempname()
  vim.fn.writefile({ 'saved' }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })

  local before = #ask_calls
  picker_result = { id = 'save', label = 'Save and ask' }
  require('plugins.editor.opencode-harness').ask()
  check(#ask_calls == before + 1, 'save-and-ask did not reach OpenCode')
  check(not vim.bo.modified, 'save-and-ask left the buffer modified')
  check(
    table.concat(vim.fn.readfile(path), '\n') == 'unsaved',
    'save-and-ask did not actually write the file to disk'
  )
end)

test('saved target reaches ask with curated default', function()
  local path = vim.fn.tempname()
  vim.fn.writefile({ 'saved' }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))

  local before = #ask_calls
  require('plugins.editor.opencode-harness').ask()
  check(#ask_calls == before + 1, 'saved target did not reach OpenCode')
  local prompt = ask_calls[#ask_calls]
  -- @this is the one that matters: it carries the selection/cursor range.
  for _, placeholder in ipairs { '@this', '@buffer', '@diagnostics', '@quickfix', '@agents' } do
    check(prompt:find(placeholder, 1, true), prompt .. ' omitted ' .. placeholder)
  end
  -- Available on `@` when wanted, but not auto-injected on every ask: both
  -- dump large amounts of text for a narrow question.
  for _, placeholder in ipairs { '@buffers', '@visible', '@marks' } do
    check(not prompt:find(placeholder, 1, true), prompt .. ' leaked ' .. placeholder)
  end
end)

test('modified unrelated buffer does not prompt', function()
  local modified = vim.fn.tempname()
  local saved = vim.fn.tempname()
  vim.fn.writefile({ 'one' }, modified)
  vim.fn.writefile({ 'two' }, saved)
  vim.cmd.edit(vim.fn.fnameescape(modified))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'unsaved' })
  vim.cmd.edit(vim.fn.fnameescape(saved))

  local before = #ask_calls
  local prompts = 0
  local real_picker = picker_result
  picker_result = function()
    prompts = prompts + 1
    return real_picker
  end
  require('plugins.editor.opencode-harness').ask()
  check(#ask_calls == before + 1, 'unrelated modified buffer blocked ask')
  check(prompts == 0, 'prompted about an unrelated buffer')
  picker_result = real_picker
end)

restore()

if #failures > 0 then
  error(table.concat(failures, '\n'), 0)
end
print('opencode_harness_spec: ok')
