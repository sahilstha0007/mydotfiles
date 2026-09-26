-- Live turn timeline: the panel must show what the agent is DOING, not only
-- which files it changed at the end.
--
-- The event shapes here are transcribed from a real SSE capture against
-- opencode 1.18.32 (see docs_dev/progress.md), not invented: `message.part.
-- updated` carries properties.part, whose type is one of text/reasoning/tool/
-- agent, and tool state is pending -> running -> completed|error with its own
-- time block. `time` is a Lua keyword, which is why the module reads it with
-- bracket access -- a regression there would be a parse error, not a bug.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/agent-panel-timeline_spec.lua

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local panel = require('agent-panel')
local root = '/home/sahil/docs_dev/fixtures/opencode-harness'

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local function part(id, p)
  panel.handle({
    type = 'message.part.updated',
    properties = { sessionID = 'ses_test', part = vim.tbl_extend('force', { id = id, sessionID = 'ses_test' }, p) },
  })
end

-- --- a full turn -----------------------------------------------------------

panel.reset(root)
panel.handle({ type = 'session.status', properties = { status = { type = 'busy' } } })
panel.handle({ type = 'message.updated', properties = { info = { id = 'msg_1', role = 'user' } } })

-- Synthetic context echoes must not flood the timeline.
part('prt_ctx', { type = 'text', synthetic = true, text = '@this @buffers' })
part('prt_think', { type = 'reasoning', text = 'I should read the config first', ['time'] = { start = 1000, ['end'] = 2400 } })
part('prt_read', {
  type = 'tool',
  tool = 'read',
  state = { status = 'pending', ['time'] = { start = 2500 } },
})
part('prt_say', { type = 'text', text = 'I found two candidates', ['time'] = { start = 3000, ['end'] = 3100 } })
part('prt_sub', { type = 'agent', name = 'reviewer' })

local text = table.concat(panel.render(), '\n')
check(text:find('RUNNING', 1, true), 'status should be RUNNING:\n' .. text)
check(text:find('thinking', 1, true), 'reasoning part missing:\n' .. text)
check(text:find('read', 1, true), 'tool part missing:\n' .. text)
check(text:find('subagent: reviewer', 1, true), 'agent part missing:\n' .. text)
check(not text:find('@this', 1, true), 'synthetic context echo leaked into the timeline:\n' .. text)
check(text:find('Elapsed:', 1, true), 'elapsed clock not shown while running:\n' .. text)
check(text:find('1.4s', 1, true), 'reasoning duration not rendered:\n' .. text)

-- --- a streaming part must update in place, not append --------------------
--
-- This is the failure that matters: reasoning arrives token by token, each with
-- the SAME part id. Without the id index the panel grows a line per token and
-- becomes unreadable within seconds.
part('prt_think', { type = 'reasoning', text = 'I should read the config first, then patch it', ['time'] = { start = 1000, ['end'] = 2900 } })
local after = table.concat(panel.render(), '\n')
local _, n = after:gsub('thinking', '')
check(n == 1, 'a re-sent part id appended instead of updating in place (thinking x' .. n .. '):\n' .. after)
check(after:find('then patch it', 1, true), 'the updated text was not rendered:\n' .. after)

-- --- tool state transitions collapse to one line --------------------------
part('prt_read', {
  type = 'tool',
  tool = 'read',
  state = { status = 'running', title = 'Read src/alpha.txt', ['time'] = { start = 2500 } },
})
part('prt_read', {
  type = 'tool',
  tool = 'read',
  state = { status = 'completed', title = 'Read src/alpha.txt', output = 'ok', ['time'] = { start = 2500, ['end'] = 4200 } },
})
local done = table.concat(panel.render(), '\n')
local _, reads = done:gsub('Read src/alpha%.txt', '')
check(reads == 1, 'tool lifecycle rendered ' .. reads .. ' lines for one call:\n' .. done)
check(done:find('✓', 1, true), 'completed tool has no tick mark:\n' .. done)
check(done:find('1.7s', 1, true), 'tool duration not rendered:\n' .. done)

-- --- a new turn resets the timeline, not idle -----------------------------
--
-- Event order measured on 1.18.32 is busy -> user message -> parts. If the
-- reset hung off idle it would either wipe the clock (busy already fired) or
-- interleave two turns, because the previous turn's parts keep arriving for a
-- moment after the next prompt lands.
part('prt_late', { type = 'text', text = 'trailing text from the old turn' })
panel.handle({ type = 'message.updated', properties = { info = { id = 'msg_2', role = 'user' } } })
part('prt_new', { type = 'text', text = 'second turn answer' })
local second = table.concat(panel.render(), '\n')
check(not second:find('trailing text', 1, true), 'the old turn was not cleared:\n' .. second)
check(second:find('second turn answer', 1, true), 'the new turn is missing:\n' .. second)

-- --- failure is reported, not swallowed -----------------------------------
panel.handle({
  type = 'session.error',
  properties = { error = { name = 'UnknownError', data = { message = 'Model not found: localstub/stub.' } } },
})
local err = table.concat(panel.render(), '\n')
check(err:find('FAILED', 1, true), 'session.error did not fail the badge:\n' .. err)
check(err:find('Model not found', 1, true), 'the error message is not shown:\n' .. err)
check(not err:find('Elapsed:', 1, true), 'the clock kept running after failure:\n' .. err)

-- --- unknown part types are ignored, not rendered -------------------------
panel.reset(root)
panel.handle({ type = 'message.status', properties = { status = { type = 'busy' } } })
part('prt_snapshot', { type = 'snapshot', snapshot = 'abc123' })
part('prt_patch', { type = 'patch', files = 3 })
local quiet = table.concat(panel.render(), '\n')
check(quiet:find('(nothing yet)', 1, true), 'an unknown part type leaked into the panel:\n' .. quiet)

print(string.format('agent-panel-timeline: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
