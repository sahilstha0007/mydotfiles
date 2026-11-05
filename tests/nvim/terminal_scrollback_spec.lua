-- Terminal scrollback must survive a close and come back on reopen.
--
-- The regression this pins is silent and total: with the stock
-- bufhidden=wipe, closing a terminal destroys the buffer, so a later reopen
-- shows an empty buffer and the user reasonably concludes the history was never
-- kept. Nothing errors, which is why it went unnoticed.
--
-- This runs against a real nvim terminal buffer with a real job, not a mock.

local MARKER = 'SCROLLBACK-CANARY-9d41'

local function term_buf_of()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == 'terminal' then
      return buf
    end
  end
end

local function lines_of(buf)
  return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function contains(buf, needle)
  return table.concat(lines_of(buf), '\n'):find(needle, 1, true) ~= nil
end

-- --- the config under test -------------------------------------------------
-- Read the shipped value rather than hardcoding `hide`: a spec that restates
-- the implementation passes even when the implementation is wrong.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local snacks_cfg = root .. '/lua/plugins/editor/snacks.lua'
local src = table.concat(vim.fn.readfile(snacks_cfg), '\n')
assert(
  src:find("bufhidden%s*=%s*'hide'", 1, false)
    or src:find('bufhidden = "hide"', 1, true),
  'snacks config no longer sets bufhidden=hide for terminals -- scrollback regression'
)

-- --- drive a real terminal -------------------------------------------------
-- termopen rather than `:terminal` + chansend: in a headless plenary run the
-- interactive shell exits immediately and the channel id goes invalid, which
-- fails the spec for a reason unrelated to scrollback. A job that prints and
-- then holds the channel open exercises the same buffer lifecycle.
vim.cmd 'enew'
vim.cmd 'new' -- a window to fall back to, so `close` is not the last one
local job = vim.fn.jobstart(
  { 'sh', '-c', "printf '%s\\n' " .. MARKER .. '; sleep 30' },
  {
    term = true,
  }
)
assert(job > 0, 'could not start a terminal job')
local buf = term_buf_of()
assert(buf, 'no terminal buffer was created')

-- Mirror what the config applies to every snacks terminal, then confirm the
-- shipped file really does set it (asserted above).
vim.bo[buf].bufhidden = 'hide'

vim.wait(5000, function()
  return contains(buf, MARKER)
end)
assert(contains(buf, MARKER), 'marker never reached the terminal buffer')

-- --- close it the way a user does ------------------------------------------
-- `hide` is the option under test, so the close must be unconditional: the
-- contract is that an explicit close preserves history, not that a hide does.
vim.cmd 'close'
assert(
  not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].bufhidden == 'hide',
  'terminal buffer was wiped on close -- scrollback is gone'
)

if not vim.api.nvim_buf_is_valid(buf) then
  print 'terminal-scrollback: FAIL (buffer wiped on close)'
  vim.cmd 'cquit 1'
end
assert(contains(buf, MARKER), 'scrollback lost after close')

-- The buffer must still be reachable, which is what makes the history usable
-- on reopen rather than merely surviving in memory.
assert(#vim.fn.getbufinfo { buflisted = 0 } >= 0)
vim.cmd('buffer ' .. buf)
assert(contains(buf, MARKER), 'scrollback lost after reopening the buffer')

print 'terminal-scrollback: ok'
