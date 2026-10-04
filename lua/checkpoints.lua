-- Checkpoints: snapshot the working tree, and jump back.
--
-- Module (pure functions + the picker UI). The lazy spec that registers
-- <leader>cc/<leader>cC lives in plugins/editor/checkpoints.lua.
--
-- Why not `git stash`: measured on this box, NO form of `git stash create`
-- captures an untracked file. Plain `create` drops it; `create -u` returns a
-- sha without it (`fatal: path 'newfile.txt' ... not in <sha>`); `add -N` then
-- `create` fails outright ("Entry not uptodate. Cannot merge."). An agent
-- creates new files constantly, so stash would silently miss exactly the work
-- most worth keeping.
--
-- The mechanism here is git plumbing:
--   cp .git/index <tmp>        snapshot the user's staging area
--   git add -A && git write-tree    capture edits AND new files as a tree
--   cp <tmp> .git/index        put the staging area back exactly as it was
-- A tree is a real restorable object (git show <tree>:path), needs no branch,
-- no commit, no stash entry, and does not move HEAD.
--
-- Snapshots are anchored to a ref (refs/checkpoints/<session>) so they are
-- reachable and prunable; without a ref git gc would eventually collect them.
--
-- Keymaps (global):
--   <leader>cc  checkpoint  snapshot now
--   <leader>cC  checkpoint list  jump back to a snapshot

local M = {}

local NS = vim.api.nvim_create_namespace 'checkpoints'
local REF_PREFIX = 'refs/checkpoints/'

local function git_dir(cwd)
  local out = vim
    .system({ 'git', '-C', cwd, 'rev-parse', '--absolute-git-dir' }, { text = true })
    :wait()
  if not out or out.code ~= 0 then
    return nil
  end
  return vim.trim(out.stdout or '')
end

---True when `cwd` is inside a git work tree.
function M.available(cwd)
  return git_dir(cwd or vim.fn.getcwd()) ~= nil
end

local function session_id()
  -- Per-buffer, so two buffers do not write into the same ref and clobber each
  -- other's history.
  --
  -- This used to prefer the opencode session id via `require('agent-panel')`.
  -- agent-panel.lua was deleted when the AI setup came out, so that lookup
  -- could never succeed again -- it pcall'd a missing file on every snapshot
  -- and silently fell through to the line below. The fallback was already the
  -- only path that ever ran; this just drops the dead half.
  return 'buf' .. vim.api.nvim_get_current_buf()
end

function M.ref(cwd)
  return REF_PREFIX .. session_id()
end

---Snapshot the working tree. Returns the tree sha, or nil + a reason.
---@return string|nil sha, string|nil err
function M.create(cwd)
  cwd = cwd or vim.fn.getcwd()
  local gd = git_dir(cwd)
  if not gd then
    return nil, 'not a git repository'
  end

  local idx = gd .. '/index'
  local backup = vim.fn.tempname() .. '.index'
  -- A repo can legitimately have no index yet (fresh `git init`, nothing ever
  -- added). Copying a non-existent file would abort the whole snapshot, so the
  -- absence is recorded and handled below.
  local had_index = vim.fn.filereadable(idx) == 1
  if had_index then
    local ok = vim.uv.fs_copyfile(idx, backup)
    if not ok then
      return nil, 'could not read the git index'
    end
  end

  local staged = vim
    .system({ 'git', '-C', cwd, 'add', '-A' }, { text = true })
    :wait()
  local tree
  if staged and staged.code == 0 then
    local w = vim
      .system({ 'git', '-C', cwd, 'write-tree' }, { text = true })
      :wait()
    if w and w.code == 0 then
      tree = vim.trim(w.stdout or '')
    end
  end

  -- Restore the user's staging area BEFORE anything else, including before
  -- reporting a failure. Leaving their index staged-with-everything is a
  -- silent, hard-to-notice corruption of their workflow.
  if had_index then
    vim.uv.fs_copyfile(backup, idx)
  elseif vim.fn.filereadable(idx) == 1 then
    vim.uv.fs_unlink(idx)
  end
  vim.fn.delete(backup)

  if not tree or tree == '' then
    return nil, 'git could not write a tree (is this a git repository?)'
  end

  -- Anchor the tree under a ref so it survives gc. Updating a ref never moves
  -- HEAD and creates no commit.
  local ref = M.ref(cwd)
  local upd = vim
    .system({ 'git', '-C', cwd, 'update-ref', ref, tree }, { text = true })
    :wait()
  if not upd or upd.code ~= 0 then
    return nil,
      'could not record the snapshot: ' .. vim.trim(
        (upd and upd.stderr) or 'unknown error'
      )
  end

  M.save_log(cwd, tree)
  return tree
end

-- --- history ---------------------------------------------------------------

function M.log_path(cwd)
  return (git_dir(cwd or vim.fn.getcwd()) or '') .. '/checkpoints.json'
end

function M.save_log(cwd, tree)
  local path = M.log_path(cwd)
  if path == '' then
    return
  end
  local entries = M.list(cwd, true)
  table.insert(entries, 1, { tree = tree, at = os.time() })
  -- ponytail: capped at 100; older snapshots stay as unreferenced objects and
  -- are collected by git gc. Raise if you ever want deeper history.
  while #entries > 100 do
    table.remove(entries)
  end
  local f = io.open(path, 'w')
  if not f then
    return
  end
  f:write(vim.json.encode(entries))
  f:close()
end

---Snapshot history, newest first.
---@param raw boolean return the stored table instead of a display list
function M.list(cwd, raw)
  local path = M.log_path(cwd)
  local out = {}
  if path == '' or vim.fn.filereadable(path) == 0 then
    return out
  end
  local f = io.open(path, 'r')
  if not f then
    return out
  end
  local body = f:read '*a'
  f:close()
  local ok, decoded = pcall(vim.json.decode, body)
  if ok and type(decoded) == 'table' then
    out = decoded
  end
  if raw then
    return out
  end
  local items = {}
  for i, e in ipairs(out) do
    table.insert(items, {
      index = i,
      tree = e.tree,
      label = string.format(
        '%s  %s',
        os.date('%H:%M:%S', e.at or 0),
        e.tree:sub(1, 8)
      ),
    })
  end
  return items
end

---Restore the working tree to a snapshot.
---
---Deliberately refuses to touch a dirty tree without asking. Overwriting
---uncommitted work to go "back to" a checkpoint is exactly the data loss this
---feature exists to prevent, so it is a decision the user makes, not one made
---for them.
---@return boolean ok, string message
function M.restore(cwd, tree, opts)
  cwd = cwd or vim.fn.getcwd()
  opts = opts or {}
  if not tree then
    return false, 'no snapshot given'
  end

  local st = vim
    .system({ 'git', '-C', cwd, 'status', '--porcelain' }, { text = true })
    :wait()
  local dirty = st and st.code == 0 and vim.trim(st.stdout or '') ~= ''
  if dirty and not opts.force then
    return false, 'working tree has uncommitted changes'
  end

  -- read-tree + checkout-index writes the work tree without touching HEAD,
  -- the index's staged state, or the stash list.
  local r = vim
    .system({ 'git', '-C', cwd, 'read-tree', '--reset', '-u', tree }, { text = true })
    :wait()
  if not r or r.code ~= 0 then
    return false,
      'restore failed: ' .. vim.trim((r and r.stderr) or 'unknown error')
  end
  return true, 'restored ' .. tree:sub(1, 8)
end

---Delete every recorded snapshot for this session.
function M.clear(cwd)
  cwd = cwd or vim.fn.getcwd()
  local ref = M.ref(cwd)
  vim
    .system({ 'git', '-C', cwd, 'update-ref', '-d', ref }, { text = true })
    :wait()
  local path = M.log_path(cwd)
  if path ~= '' and vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

-- --- ui --------------------------------------------------------------------

local function snapshot()
  if not M.available() then
    vim.notify('checkpoints: not a git repository', vim.log.levels.WARN)
    return
  end
  local tree, err = M.create()
  if not tree then
    vim.notify('checkpoint failed: ' .. tostring(err), vim.log.levels.ERROR)
    return
  end
  local n = #M.list()
  vim.notify(string.format('checkpoint %s  (%d saved)', tree:sub(1, 8), n))
end

local function browse()
  if not M.available() then
    vim.notify('checkpoints: not a git repository', vim.log.levels.WARN)
    return
  end
  local items = M.list()
  if #items == 0 then
    vim.notify(
      'no checkpoints yet — <leader>cc to make one',
      vim.log.levels.WARN
    )
    return
  end
  vim.ui.select(items, {
    prompt = string.format('Restore checkpoint (%d): ', #items),
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    local ok, msg = M.restore(nil, choice.tree)
    if not ok and msg == 'working tree has uncommitted changes' then
      vim.ui.select(
        { 'Cancel', 'Discard my changes and restore' },
        { prompt = 'Working tree is dirty. ' },
        function(pick)
          if pick == 'Discard my changes and restore' then
            local ok2, msg2 = M.restore(nil, choice.tree, { force = true })
            vim.notify(
              msg2,
              ok2 and vim.log.levels.INFO or vim.log.levels.ERROR
            )
          end
        end
      )
      return
    end
    vim.notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    -- The agent reloads buffers on its own (autoread), but a clean buffer only
    -- reloads if it is not the current one; :checktime covers the rest.
    vim.cmd 'checktime'
  end)
end

function M.setup()
  -- No `group` on the keymaps: that option belongs to which-key's keymap.set,
  -- not vim.keymap.set, which rejects it with `invalid key: group` and takes
  -- the whole opts table as the lhs. Every other keymap in this config is
  -- plain vim.keymap.set, so this stays plain.
  local group = vim.api.nvim_create_augroup('Checkpoints', { clear = true })
  vim.keymap.set(
    'n',
    '<leader>cc',
    snapshot,
    { desc = 'Checkpoint working tree' }
  )
  vim.keymap.set('n', '<leader>cC', browse, { desc = 'Restore checkpoint' })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      -- Nothing to persist: the tree is already a git object and the history
      -- file is written on every snapshot. Kept as the hook point for a future
      -- "auto-checkpoint before every agent ask" rule.
    end,
  })
  vim.g.checkpoints_ns = NS
end

return M
