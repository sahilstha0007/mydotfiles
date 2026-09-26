-- Multi-agent: discovering opencode servers, and the guard that blocks them.
--
-- The count in M.servers() is load-bearing: at 2+ the plugin opens its server
-- picker, at 1 it silently picks, at 0 it starts one. If this miscounts, the
-- agent manager is either unreachable or never used.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/multi_agent_spec.lua

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

local ma = require('multi-agent')

-- --- no servers: an empty list, not an error, and not nil -------------------
-- The live box always has at least one (omniroute/other), so assert the shape
-- rather than an exact count -- this must hold with zero running too.
local found = ma.servers()
check(type(found) == 'table', 'servers() must return a table, got ' .. type(found))
for _, s in ipairs(found) do
  check(type(s.port) == 'string' and s.port:match('^%d+$') ~= nil, 'a port came back as ' .. tostring(s.port))
  check(s.cwd == nil or type(s.cwd) == 'string', 'cwd came back as ' .. type(s.cwd))
end

-- --- outside tmux, spawning is refused with a reason -------------------------
-- The guard matters because the alternative is a tmux error string with no
-- context, or a float that buries the editor. Asserting only `ok == false` is
-- not enough: without the guard the call still fails (tmux is not there) and
-- still returns false, so the boolean cannot tell the two apart. The message
-- is the part that carries the explanation, so that is what is pinned.
vim.env.TMUX_PANE = nil
local ok, msg = ma.spawn('/tmp', 'opencode')
check(ok == false, 'spawn must refuse outside tmux')
check(tostring(msg):find('not inside tmux', 1, true) ~= nil,
  'the refusal must explain itself, not relay a raw tmux error: ' .. tostring(msg))

-- --- the guard is opt-in, not deleted ---------------------------------------
-- Regression guard for the thing this feature changed: the single-instance
-- protection is still the default, one vim.g away from being off. If someone
-- "simplifies" the condition away, the segfault protection is gone silently.
local src = table.concat(vim.fn.readfile('/home/sahil/.config/nvim/lua/plugins/editor/opencode-agent.lua'), '\n')
-- strip Lua comments so a comment about the guard cannot satisfy the assertion
src = src:gsub('%-%-[^\n]*', '')
check(src:find('server_overlaps%(cwd%) and not vim%.g%.opencode_multi_server') ~= nil,
  'the single-instance guard must still be the default (g:opencode_multi_server opts out)')

print(string.format('multi_agent: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
