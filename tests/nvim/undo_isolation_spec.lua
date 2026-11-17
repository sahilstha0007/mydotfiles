-- Undo isolation across an agent write.
--
-- The behaviour under test is native Vim (':earlier 1f'): when an agent writes
-- to disk behind an autoread buffer, only ':earlier 1f' reaches my last save.
-- The keymap that exposed it (<leader>uf/uF) lived in the now-deleted undotree
-- plugin, so this spec pins only the measurement -- if it ever stops being true
-- we find out why rather than discovering it at 2am with an agent mid-run.

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

-- Derive the config root from this file's own location. Hardcoding it made
-- this spec read the LIVE tree even when run against a copy, so it passed on
-- a clone that had none of the code under test. Same pattern as
-- tests/minimal_init.lua.
-- --- 1. the mechanism, measured -------------------------------------------

-- Returns the buffer's first line, after setting up: two of my own saved
-- states, then N agent writes to disk, each followed by the reload that
-- autoread performs.
local function agent_wrote(nwrites)
  local path = vim.fn.tempname() .. '.txt'
  vim.fn.writefile({ 'v1' }, path)
  vim.cmd 'silent enew!'
  vim.cmd.edit(vim.fn.fnameescape(path))
  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'MINE-1' })
  vim.cmd 'silent write'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'MINE-2' })
  vim.cmd 'silent write' -- my last save

  for i = 1, nwrites do
    vim.fn.writefile({ 'AGENT-' .. i }, path)
    -- `checktime` is what autoread runs. The buffer is clean here, which is
    -- the case that actually reloads: a MODIFIED buffer is left alone (it
    -- raises FileChangedShell instead), so the hazard is specifically
    -- "clean buffer, agent writes, silent reload, no warning".
    pcall(vim.cmd, 'silent checktime')
  end
  return buf, path
end

local function line_of(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1]
end

test('agent write lands in the buffer silently (the hazard is real)', function()
  local buf = agent_wrote(2)
  check(
    line_of(buf) == 'AGENT-2',
    'agent text did not land; got ' .. tostring(line_of(buf))
  )
  check(
    not vim.bo[buf].modified,
    'buffer unexpectedly modified after clean reload'
  )
end)

test('earlier 1f reaches my last write in ONE keystroke', function()
  for _, n in ipairs { 1, 3, 5 } do
    local buf = agent_wrote(n)
    pcall(vim.cmd, 'silent earlier 1f')
    check(
      line_of(buf) == 'MINE-2',
      n .. ' agent write(s): earlier 1f gave ' .. tostring(line_of(buf))
    )
  end
end)

test('later 1f puts the agent changes back', function()
  local buf = agent_wrote(3)
  pcall(vim.cmd, 'silent earlier 1f')
  check(line_of(buf) == 'MINE-2', 'setup failed')
  pcall(vim.cmd, 'silent later 1f')
  check(line_of(buf) == 'AGENT-3', 'later 1f gave ' .. tostring(line_of(buf)))
end)

-- The reason `u` alone is not enough -- and it is worse than "too many
-- presses". Measured, not assumed: my first draft of this test asserted that
-- `u` after `earlier 1f` lands on MINE-1, and it FAILED, with v1.
--
-- vim.fn.undotree() shows why. After two of my writes and two agent reloads
-- the tree is only three entries deep, and the save marker sits on the first:
--     seq=1 save=2 | seq=2 | seq=3
-- The MINE-1 state is not in the tree at all. Vim folds the buffer back to the
-- last write, so `u` from your last save goes straight past MINE-1 to the
-- pre-edit file content. There is no count of presses that recovers it, and no
-- warning. Only `earlier 1f` lands on MINE-2, because only that is anchored to
-- the write rather than to the (now-absent) intermediate blocks.
test(
  'plain `u` skips my own intermediate state -- which is the whole problem',
  function()
    local buf = agent_wrote(2)
    pcall(vim.cmd, 'silent earlier 1f')
    check(line_of(buf) == 'MINE-2', 'setup failed')
    pcall(vim.cmd, 'silent undo')
    -- NOT MINE-1. Asserted explicitly so the skip is a known, watched property:
    -- if a future nvim starts preserving intermediate states this goes red, and
    -- the right response is to relax the test, not to ship the change unexamined.
    check(
      line_of(buf) == 'v1',
      'expected the measured MINE-2->v1 skip, got ' .. tostring(line_of(buf))
    )
  end
)

if #failures > 0 then
  error(table.concat(failures, '\n'), 0)
end
print 'undo_isolation_spec: ok'
