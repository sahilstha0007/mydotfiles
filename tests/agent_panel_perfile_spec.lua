-- Per-file accept/reject (`da`/`dr`) in the agent panel: the file -> pending
-- permission-id bookkeeping.
--
-- This map is the part that fails silently. A stale id replied to twice 404s;
-- a missing entry makes `da` report "no pending request" on a file the agent is
-- actively blocked on. Both bugs are invisible to the eye, so the spec drives
-- `panel.handle()` with the real event shapes and reads the result back out of
-- `panel.render()` -- the same observable the existing agent-panel_spec uses.
--
-- What is NOT asserted here, and why:
--   * the `da`/`dr`/`dp` keymaps -- this runs under minimal_init, which does
--     not load the real config, and the panel only creates buffer-local maps
--     when its window is first shown. Nothing exists to assert against. Same
--     reason as tests/agent_modes_spec.lua.
--   * that the reply reaches the server -- that needs a live `opencode serve`
--     and is covered end-to-end by docs_dev/scripts/golden-path-check.sh.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/agent_panel_perfile_spec.lua

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local panel = require('agent-panel')
local root = '/home/sahil/docs_dev/fixtures/opencode-harness'
-- Keys are ROOT-RELATIVE, because that is what `normalize()` (agent-panel.lua:75)
-- returns and what `rows` -- the map `path_under_cursor()` reads -- holds. The
-- change tree's paths come from GET /file/status, which is also root-relative.
-- Using absolute paths here asserts against a key nothing ever writes.
local alpha = 'src/alpha.txt'
local beta = 'src/beta.txt'

local function asked(id, file)
  panel.handle({
    type = 'permission.asked',
    properties = {
      id = id,
      permission = 'edit',
      patterns = { file },
      metadata = { filepath = file },
    },
  })
end

local function replied(id)
  panel.handle({ type = 'permission.replied', properties = { requestID = id } })
end

local function text()
  return table.concat(panel.render(), '\n')
end

local function eq(a, b, msg)
  assert(vim.deep_equal(a, b), ('%s\n  expected: %s\n  actual:   %s'):format(msg, vim.inspect(a), vim.inspect(b)))
end

-- ------------------------------------------------------- one edit, one file --

panel.reset(root)
asked(7, alpha)
local t = text()
assert(t:find('REVIEW', 1, true), 'a pending edit should put the panel in REVIEW: ' .. t)
assert(t:find('alpha.txt', 1, true), 'the reviewed file should be named: ' .. t)

-- ------------------------------------------------- two edits, one file ---
--
-- The case that makes or breaks per-file accept. A file can be edited more than
-- once in a turn, and `da` has to be able to clear the WHOLE file, so the
-- second request must queue behind the first instead of replacing it. If it
-- replaced, `da` would answer only the newest edit and the agent would
-- immediately re-ask for the rest.

panel.reset(root)
asked(7, alpha)
asked(8, alpha)
eq({ 7, 8 }, panel.pending_replies(alpha), 'both edits to one file stay queued, in order')

-- ------------------------------------------------------ two files, queued --

panel.reset(root)
asked(7, alpha)
asked(9, beta)
eq({ 7 }, panel.pending_replies(alpha), "accepting one file must not touch another's queue")
eq({ 9 }, panel.pending_replies(beta), 'each file keys its own queue')

-- --------------------------------------------- permission.replied prunes ---
--
-- The critical invariant: replying to id 7 must remove ONLY 7. If pruning
-- cleared the file entry wholesale, a second pending edit for the same file
-- would become unanswerable -- and the user would be stuck staring at a file
-- the agent is blocked on, with `da` reporting nothing pending.
--
-- This is the assertion that catches that bug. It is asserted against
-- pending_replies() rather than the rendered text because REVIEW is driven by
-- state.reviews (keyed by id), so it stays lit either way: a spec that watched
-- only the badge passed against deliberately broken pruning.

panel.reset(root)
asked(7, alpha)
asked(8, alpha)
replied(7)
eq({ 8 }, panel.pending_replies(alpha), 'replying to 7 prunes only 7, leaving 8 answerable')
assert(panel.pending_replies(alpha)[1] ~= 7, 'the answered id must not remain queued for a second 404')

-- Answering the last one clears the file entirely.
panel.reset(root)
asked(7, alpha)
replied(7)
eq({}, panel.pending_replies(alpha), 'the last reply empties the file queue')
t = text()
assert(not t:find('REVIEW', 1, true), 'no pending requests left means not REVIEW: ' .. t)

-- An unknown file is empty, not an error: `da` on a file nobody asked about
-- must fall through to its "no pending request" notice, not raise.
eq({}, panel.pending_replies(root .. '/src/never-asked.txt'), 'unknown file has no queue')
eq({}, panel.pending_replies(nil), 'nil file is handled')

-- ------------------------------------------------------------ reset() ---
--
-- A new session must not inherit the previous one's permission ids: the server
-- has no record of them and would reject every reply.

panel.reset(root)
asked(7, alpha)
panel.reset(root)
eq({}, panel.pending_replies(alpha), 'reset must drop pending permission ids')
t = text()
assert(not t:find('REVIEW', 1, true), 'reset must drop the reviewed file: ' .. t)
assert(not t:find('alpha.txt', 1, true), 'reset must drop the reviewed file: ' .. t)

-- --------------------------------------------------------------- report ---

print('agent_panel_perfile: all assertions passed')
