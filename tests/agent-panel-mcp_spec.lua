-- MCP status in the agent panel.
--
-- The point of this line is that a DEAD MCP server is visible. An agent that
-- cannot reach a tool looks exactly like an agent that chose not to use one,
-- so without this the failure is invisible until you notice the missing answer.
--
-- Both JSON bodies below are verbatim captures from `opencode serve` 1.18.32
-- (a live context7 server, and one pointed at a host that does not resolve).
-- The real failure status is the string "failed", and the server sends the
-- reason alongside it — that error is the only actionable part.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/agent-panel-mcp_spec.lua

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local panel = require('agent-panel')

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

-- --- none configured: must say so, not look broken -------------------------
panel.reset('/home/sahil/docs_dev/fixtures/opencode-harness')
check(panel.mcp_summary() == 'unknown', 'before any poll it should say unknown, not none: ' .. panel.mcp_summary())

panel.set_mcp('{}')
check(panel.mcp_summary() == 'none configured', 'an empty server list should read as none configured: ' .. panel.mcp_summary())

-- --- healthy ---------------------------------------------------------------
panel.set_mcp('{"ctx7":{"status":"connected"}}')
local ok = panel.mcp_summary()
check(ok == '1/1 connected · ctx7', 'a connected server should render cleanly: ' .. ok)

-- --- the case this feature exists for --------------------------------------
panel.set_mcp(
  '{"ctx7":{"status":"connected"},"dead":{"status":"failed","error":"SSE error: Was there a typo in the url or port?"}}'
)
local mixed = panel.mcp_summary()
check(mixed:find('1/2 connected', 1, true) ~= nil, 'mixed health should count: ' .. mixed)
check(mixed:find('ctx7', 1, true) ~= nil, 'the healthy server is not named: ' .. mixed)
check(mixed:find('dead', 1, true) ~= nil, 'the failed server is not named: ' .. mixed)
-- The reason, not just the word "failed": "1/2 connected" alone does not tell
-- you what to fix.
check(mixed:find('typo in the url', 1, true) ~= nil, 'the server-supplied error is dropped: ' .. mixed)

-- --- the rendered panel carries the line ------------------------------------
local text = table.concat(panel.render(), '\n')
check(text:find('MCP: 1/2 connected', 1, true) ~= nil, 'the MCP line is missing from the panel:\n' .. text)

-- --- all down ---------------------------------------------------------------
panel.set_mcp('{"dead":{"status":"failed","error":"connection refused"}}')
check(panel.mcp_summary():find('0/1 connected', 1, true) ~= nil, 'a total outage should read 0/1: ' .. panel.mcp_summary())

-- --- junk must not wipe a good reading -------------------------------------
panel.set_mcp('{"ctx7":{"status":"connected"}}')
panel.set_mcp('not json at all')
check(panel.mcp_summary() == '1/1 connected · ctx7',
  'a malformed body destroyed the last good reading: ' .. panel.mcp_summary())

-- --- order is stable (map iteration order is not) ---------------------------
panel.set_mcp('{"zeta":{"status":"connected"},"alpha":{"status":"connected"}}')
local ordered = panel.mcp_summary()
check(ordered:find('alpha', 1, true) < ordered:find('zeta', 1, true),
  'server order is not stable across reads: ' .. ordered)

print(string.format('agent-panel-mcp: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
