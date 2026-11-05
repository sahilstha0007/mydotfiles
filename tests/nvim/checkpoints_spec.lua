-- Checkpoints: the whole point is not losing work, so the spec is about the
-- two ways this could destroy something:
--   1. the user's staging area must come back EXACTLY as it was (the snapshot
--      does `git add -A` to see untracked files; if the index is not restored,
--      every snapshot silently stages the user's whole working tree)
--   2. a restore must bring back a file the agent DELETED, and must refuse to
--      clobber uncommitted work without an explicit force
--
-- Everything runs against a real throwaway git repo in a temp dir. A mocked
-- git would only prove the mock matches.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/checkpoints_spec.lua

-- Derive from this file's own location, matching tests/minimal_init.lua, so a
-- copied or cloned tree tests itself instead of the live config.
local _src = debug.getinfo(1, 'S').source:sub(2)
local _cand = vim.fn.fnamemodify(_src, ':p:h:h')
local ROOT = vim.env.NVIM_CONFIG_ROOT or (vim.fn.isdirectory(_cand .. '/lua') == 1 and _cand or (vim.fn.fnamemodify(_cand, ':h') .. '/.config/nvim'))
vim.opt.runtimepath:prepend(ROOT)

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local REPO = vim.fn.tempname()
vim.fn.mkdir(REPO, 'p')

local function git(...)
  local args = { 'git', '-C', REPO }
  for _, a in ipairs { ... } do
    table.insert(args, a)
  end
  local out = vim.system(args, { text = true }):wait()
  return vim.trim((out.stdout or '') .. (out.stderr or ''))
end

local function read(p)
  local f = io.open(REPO .. '/' .. p, 'r')
  if not f then
    return nil
  end
  local s = f:read '*a'
  f:close()
  return s
end

local function write(p, body)
  local f = assert(io.open(REPO .. '/' .. p, 'w'))
  f:write(body)
  f:close()
end

git('init', '-q', '.')
git('config', 'user.email', 't@t')
git('config', 'user.name', 't')
write('tracked.txt', 'original\n')
git('add', '-A')
git('commit', '-qm', 'init')

-- The agent's work: one edit, one brand-new file, one deletion.
write('tracked.txt', 'agent edited this\n')
write('created_by_agent.txt', 'new file the agent made\n')
vim.fn.delete(REPO .. '/does_not_exist.txt')

-- Plain module: the lazy spec that wires the keymaps is a thin wrapper.
local cp = dofile(ROOT .. '/lua/checkpoints.lua')

-- --- availability ----------------------------------------------------------
check(cp.available(REPO), 'a real git repo should report available')
check(not cp.available '/tmp', 'a non-repo should report unavailable')

-- --- the staging area is the user's, and must survive ----------------------
--
-- Pre-stage something so the index is NOT empty going in. If the snapshot
-- leaks its `git add -A`, this staged state is what gets clobbered.
git('add', 'tracked.txt')
local staged_before = git('diff', '--cached', '--name-only')

local tree, err = cp.create(REPO)
check(tree ~= nil, 'create failed: ' .. tostring(err))

local staged_after = git('diff', '--cached', '--name-only')
check(
  staged_before == staged_after,
  ('the staging area changed: before [%s] after [%s]'):format(
    staged_before,
    staged_after
  )
)
check(
  staged_after == 'tracked.txt',
  'the snapshot left extra things staged: ' .. staged_after
)

-- HEAD and the stash list must be untouched by a snapshot.
check(
  git('log', '--oneline'):match 'init' ~= nil,
  'HEAD moved during a snapshot'
)
check(
  git('stash', 'list') == '',
  'a snapshot created a stash entry: ' .. git('stash', 'list')
)

-- --- the snapshot must contain BOTH the edit and the new file -------------
local ls = git('ls-tree', '--name-only', tree)
check(
  ls:find('created_by_agent.txt', 1, true) ~= nil,
  'the new file the agent created is not in the snapshot:\n' .. ls
)
check(
  ls:find('tracked.txt', 1, true) ~= nil,
  'the edited file is not in the snapshot:\n' .. ls
)
check(
  git('show', tree .. ':tracked.txt') == 'agent edited this',
  'the edit was not captured'
)

-- --- the snapshot is restorable, including a deleted file ------------------
-- Deleting tracked.txt is the case stash-style snapshots lose entirely.
-- Removed from the filesystem, NOT with `git rm`: `git rm` stages the removal,
-- which changes the index out from under the restore and tests a situation a
-- real agent edit never creates (an agent deletes the file on disk).
vim.fn.delete(REPO .. '/tracked.txt')

local ok, msg = cp.restore(REPO, tree, { force = true })
check(ok, 'restore failed: ' .. tostring(msg))
check(
  read 'tracked.txt' == 'agent edited this\n',
  'restore did not bring the file back'
)
check(
  read 'created_by_agent.txt' == 'new file the agent made\n',
  'restore lost the created file'
)
check(git('log', '--oneline'):match 'init' ~= nil, 'restore moved HEAD')
check(git('stash', 'list') == '', 'restore created a stash entry')

-- --- a dirty tree is never clobbered without saying so --------------------
write('tracked.txt', 'MY UNSAVED WORK\n')
local ok2, msg2 = cp.restore(REPO, tree)
check(not ok2, 'a dirty working tree was overwritten without force')
check(
  read 'tracked.txt' == 'MY UNSAVED WORK\n',
  'the unsaved work was destroyed anyway'
)
check(
  msg2 == 'working tree has uncommitted changes',
  'unhelpful refusal message: ' .. tostring(msg2)
)

-- with force it goes through, and the message says so
local ok3, msg3 = cp.restore(REPO, tree, { force = true })
check(ok3, 'a forced restore failed: ' .. tostring(msg3))
check(
  read 'tracked.txt' == 'agent edited this\n',
  'a forced restore did not apply'
)

-- --- history ---------------------------------------------------------------
local log = cp.list(REPO, true)
check(#log >= 1, 'no snapshot was recorded in the history')
check(
  log[1].tree == tree,
  'the newest history entry is not the snapshot just taken'
)

local shown = cp.list(REPO)
check(
  shown[1].label:find(tree:sub(1, 8), 1, true) ~= nil,
  'the display label lost the tree sha: ' .. shown[1].label
)

-- clearing removes the ref and the log, and is not destructive to the work
cp.clear(REPO)
check(#cp.list(REPO, true) == 0, 'clear left history behind')
check(
  read 'tracked.txt' == 'agent edited this\n',
  'clear destroyed the working tree'
)

vim.fn.delete(REPO, 'rf')
print(string.format('checkpoints: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd 'cq'
else
  vim.cmd 'qa!'
end
