-- Live change explorer for the opencode harness.
--
-- What this shows, top to bottom:
--   - a status line: connected? working? how many edits pending review
--   - a FILE TREE of everything the agent has changed, grouped by directory,
--     with +added / -removed per file, refreshed live from the server
--   - a short activity log of the last few events
--
-- The tree is the point. It is driven by `GET /file/status?directory=<cwd>`,
-- which reports the whole project's change set (path/added/removed/status) --
-- not just files that happened to fire an event, so an edit made three steps
-- ago is still listed, with its counts, until it is reverted.
--
-- Keymaps (buffer-local):
--   <CR>  open the file under the cursor
--   d     show the raw patch the agent proposed for that file
--   r     force a refresh now
--   q     close

local M = {}

local state = {
  root = vim.fn.getcwd(),
  status = 'DISCONNECTED',
  detail = 'No active server',
  file = nil,
  review = nil,
  reviews = {},
  -- file -> pending permission id, for per-file accept/reject (`da`/`dr`).
  -- `reviews` above is keyed by id only, which is enough to know *whether*
  -- something is pending but not *which file* it is for -- and the change tree
  -- is file-shaped, so the key the user acts on has to be the file.
  -- One file can have several pending requests (one per edit), so this holds a
  -- queue per file and replies to them in order.
  review_files = {},
  recent = {},
  error = nil,
  changes = {},
  session = nil,
  -- nil = not polled yet (renders "unknown"), {} = none configured. Kept
  -- distinct from an empty list so a dead server cannot look like "no MCP".
  mcp = nil,
  -- Live turn timeline. `by_id` is the index: opencode streams
  -- `message.part.updated` repeatedly for the SAME part id as it fills in, so
  -- without it every token of reasoning would append a new line. Render reads
  -- `turn` (ordered) and never `by_id`.
  turn = {},
  by_id = {},
  -- Last user message id, so a new prompt is what resets the turn (see
  -- message.updated below) rather than idle, which arrives late and interleaves.
  user_msg = nil,
  -- Set on session.execution.started, cleared on idle/error. Drives the elapsed
  -- counter, so it has to survive the "busy" -> work -> "idle" transitions
  -- without being reset by unrelated events.
  started_at = nil,
}
local win
local tree_win
local augroup
local activity_ns
local poll_timer

-- line number (1-indexed) -> absolute path, rebuilt on every render so <CR>
-- and `d` resolve a path by position instead of re-parsing the display line.
local rows = {}

-- Forward declarations. `refresh()` below calls update(), and Lua resolves a
-- call to a local only if the local is already in lexical scope -- without
-- this, `update()` compiles to a global lookup and dies with
-- "attempt to call global 'update' (a nil value)".
-- `secs` is the same trap in render(), which is defined above it.
local update
local secs

local function normalize(path)
  if type(path) ~= 'string' or path == '' then
    return nil
  end
  path = vim.fs.normalize(path)
  if not vim.startswith(path, '/') then
    path = vim.fs.joinpath(state.root, path)
  end
  local prefix = state.root .. '/'
  return vim.startswith(path, prefix) and path:sub(#prefix + 1) or path
end

local function fullpath(path)
  if not path then
    return nil
  end
  path = vim.fs.normalize(path)
  if vim.startswith(path, state.root .. '/') or path == state.root then
    return path
  end
  return vim.fs.normalize(vim.fs.joinpath(state.root, path))
end

local function add_recent(path, state_label)
  if not path then
    return
  end
  path = normalize(path)
  table.insert(state.recent, 1, { path = path, status = state_label })
  if #state.recent > 8 then
    table.remove(state.recent)
  end
end

-- --- server access ---------------------------------------------------------
-- The plugin keeps the live handle at `require('opencode.server').connected`;
-- borrow its URL rather than re-running discovery (which is a pgrep+lsof round
-- trip and can race). `Server:curl` already attaches the configured
-- credentials, so nothing here touches auth.

local function server()
  -- pcall: the panel is loaded by the config, so it can render before (or
  -- without) opencode.nvim ever being loaded. No server handle simply means
  -- "no changes to show yet", not an error.
  local ok, mod = pcall(require, 'opencode.server')
  return ok and mod.connected or nil
end

local function encode_dir(dir)
  return vim.uri_encode(dir)
end

---One line describing the server's MCP connections.
---@return string
local function mcp_summary()
  local servers = state.mcp
  if servers == nil then
    return 'unknown'
  end
  if #servers == 0 then
    return 'none configured'
  end
  local live, names = 0, {}
  for _, s in ipairs(servers) do
    if s.status == 'connected' then
      live = live + 1
      table.insert(names, s.name)
    else
      -- A bare "failed" tells you nothing to act on; the server sends the
      -- reason (measured: "SSE error: Was there a typo in the url or port?").
      table.insert(names, s.name .. ' ✗ ' .. (s.error or tostring(s.status)))
    end
  end
  table.sort(names)
  return string.format('%d/%d connected · %s', live, #servers, table.concat(names, ', '))
end

---Refresh the change tree from the server.
function M.refresh()
  local srv = server()
  if not srv then
    state.changes = {}
    update()
    return
  end
  -- /vcs/status, NOT /file/status. Both are documented as "git status of all
  -- files", and both appear in the OpenAPI spec with the same shape -- but
  -- /file/status returns [] against a genuinely dirty repo (verified live,
  -- 2026-09-25: 2 modified + 1 untracked file, both with and without ?directory).
  -- /vcs/status returns all three. The spec alone is not evidence; this was
  -- measured. Field names differ too: file/additions/deletions, not
  -- path/added/removed.
  srv:curl(
    '/vcs/status?directory=' .. encode_dir(state.root),
    'GET',
    nil,
    function(body)
      -- body is a JSON string; the plugin decodes in the other helpers but
      -- curl hands us raw output here.
      local ok, decoded = pcall(vim.json.decode, body)
      if not ok or type(decoded) ~= 'table' then
        return
      end
      local out = {}
      for _, entry in ipairs(decoded) do
        local path = normalize(entry.file or entry.path)
        if path then
          table.insert(out, {
            path = path,
            added = entry.additions or entry.added or 0,
            removed = entry.deletions or entry.removed or 0,
            status = entry.status or 'modified',
          })
        end
      end
      table.sort(out, function(a, b)
        return a.path < b.path
      end)
      state.changes = out
      update()
    end,
    function()
      -- A failed poll is not worth a notification: the next tick retries, and
      -- the tree simply keeps its last good contents.
    end
  )

  -- MCP lives on its own poll rather than riding along above: a slow or dead
  -- server should not be able to delay the change tree, and the two failures
  -- are unrelated. Same cadence, same silence-on-error rule.
  srv:curl('/mcp', 'GET', nil, function(body)
    M.set_mcp(body)
    update()
  end, function() end)
end

-- --- render ----------------------------------------------------------------

local GLYPH = { added = '+', deleted = '~', modified = '●' }

---Group a flat path list into ordered directory nodes + file leaves.
local function build_tree()
  local dirs, files = {}, {}
  for _, change in ipairs(state.changes) do
    local dir = vim.fn.fnamemodify(change.path, ':h')
    if dir == '.' then
      table.insert(files, { change = change, depth = 0 })
    else
      dirs[dir] = true
      table.insert(files, { change = change, depth = 1, dir = dir })
    end
  end
  local out = {}
  local dir_list = vim.tbl_keys(dirs)
  table.sort(dir_list)
  for _, dir in ipairs(dir_list) do
    table.insert(out, { kind = 'dir', label = dir })
  end
  -- Directories first (as headers), then each file indented under its dir.
  for _, item in ipairs(files) do
    table.insert(out, { kind = 'file', label = item.change.path, change = item.change, depth = item.depth })
  end
  return out
end

local function render()
  rows = {}
  local lines = {}
  local pending = vim.tbl_count(state.reviews)

  local function put(text, kind, path)
    table.insert(lines, text)
    if kind == 'file' and path then
      rows[#lines] = path
    end
  end

  put(' Agent ', 'plain')
  local badge = state.status == 'RUNNING' and '● RUNNING'
    or state.status == 'REVIEW' and '◆ REVIEW'
    or state.status == 'FAILED' and '✗ FAILED'
    or '○ ' .. state.status
  put(' ' .. badge, 'plain')
  -- Elapsed only while working: a stuck-at-zero counter on a finished turn
  -- reads as "it froze", which is the opposite of the truth.
  if state.started_at and state.status == 'RUNNING' then
    put('Elapsed: ' .. secs(state.started_at) .. ' · ' .. #state.turn .. ' steps', 'plain')
  else
    put('Steps: ' .. #state.turn, 'plain')
  end
  put('Working: ' .. (state.file or 'Waiting for OpenCode'), 'plain')
  -- Always shown, like the Changes count below: a live panel has to be able to
  -- say "queue is clear" out loud. Hiding the line at zero makes "all reviewed"
  -- indistinguishable from "nothing was ever proposed".
  put('Review: ' .. pending .. ' pending', 'plain')
  -- MCP: a panel that can tell you "3 servers, 1 disconnected" is how a dead
  -- tool gets noticed at all. An agent that silently cannot reach a server
  -- looks exactly like an agent that decided not to use it.
  put('MCP: ' .. mcp_summary(), 'plain')
  if state.review and state.review.file then
    put('Reviewing: ' .. state.review.file, 'plain')
  end
  if state.error then
    put('Error: ' .. state.error, 'plain')
  end

  put('', 'plain')
  put(' Changes ' .. (#state.changes > 0 and ('(' .. #state.changes .. ')') or ''), 'plain')
  if #state.changes == 0 then
    put('  (no changes yet)', 'plain')
  else
    for _, node in ipairs(build_tree()) do
      if node.kind == 'dir' then
        put('  ' .. node.label .. '/', 'plain')
      else
        local c = node.change
        local g = GLYPH[c.status] or '●'
        -- Indent by depth, not a fixed 4: directory headers are all emitted
        -- before any file, so a root file at the same indent would read as
        -- though it lived under the last header printed.
        put(
          string.format(
            '%s%s %s  +%d -%d',
            string.rep('  ', node.depth + 1),
            g,
            vim.fn.fnamemodify(c.path, ':t'),
            c.added,
            c.removed
          ),
          'file',
          fullpath(c.path)
        )
      end
    end
  end

  put('', 'plain')
  put(' Turn ', 'plain')
  if #state.turn == 0 then
    put('  (nothing yet)', 'plain')
  else
    -- Last 12, oldest first. The point is "what is it doing right now", and a
    -- 40-line scrollback in a narrow tree window buries the status lines that
    -- matter most.
    for i = math.max(1, #state.turn - 11), #state.turn do
      local e = state.turn[i]
      local text = string.format('  %s %s', e.mark, e.name)
      if e.detail ~= '' then
        text = text .. '  ' .. e.detail
      end
      if e.ms ~= '' then
        text = text .. '  ' .. e.ms
      end
      put(text, 'plain')
    end
  end

  put('', 'plain')
  put(' Activity ', 'plain')
  if #state.recent == 0 then
    put('  Waiting for file.edited', 'plain')
  else
    for _, item in ipairs(state.recent) do
      put('  ' .. item.status .. ' ' .. item.path, 'plain')
    end
  end

  put('', 'plain')
  put('<CR> open · d patch · r refresh · q close', 'plain')

  return lines
end

function update()
  if win and win:valid() then
    vim.bo[win.buf].modifiable = true
    vim.api.nvim_buf_set_lines(win.buf, 0, -1, false, render())
    vim.bo[win.buf].modifiable = false
    return
  end
  win = nil
end

local function close()
  if win and win:valid() then
    win:hide()
  end
  win = nil
end

-- --- actions ---------------------------------------------------------------

local function path_under_cursor()
  local line = vim.api.nvim_get_current_line()
  if not rows[vim.fn.line('.')] then
    return nil
  end
  return rows[vim.fn.line('.')]
end

local function open_file()
  local target = path_under_cursor()
  if not target then
    return
  end
  if vim.fn.filereadable(target) == 0 then
    vim.notify('Changed file is unavailable: ' .. target, vim.log.levels.WARN)
    return
  end
  vim.cmd('tabedit ' .. vim.fn.fnameescape(target))
end

---Reply to the pending permission for the file under the cursor.
---`reply` is the server's own vocabulary: once | always | reject.
---
---The plugin already prompts per edit (opencode/events/permissions/init.lua
---auto-selects Once/Always/Reject), but that is modal and one request at a
---time. This is the file-shaped pass over the same requests: stand on a row in
---the change tree, decide the whole file.
---
---A file can hold several queued requests (one per edit). Replaying the same
---reply for each is what "accept this file" has to mean -- stopping after the
---first would leave the rest of the file hanging and the agent would re-ask.
---`always` is deliberately NOT offered here: it is a session-wide grant and
---belongs to a decision about the run, not about a row in a list.
local function reply_file(reply)
  local target = path_under_cursor()
  local srv = server()
  if not target or not srv then
    return
  end
  local queue = state.review_files[target]
  if not queue or #queue == 0 then
    vim.notify('No pending request for ' .. vim.fn.fnamemodify(target, ':t'), vim.log.levels.WARN)
    return
  end
  -- Snapshot and clear: the `permission.replied` events that come back also
  -- prune this table, and replying to an id twice returns 404.
  local ids = state.review_files[target]
  state.review_files[target] = nil
  for _, id in ipairs(ids) do
    srv:permit(id, reply)
  end
  add_recent(target, reply == 'reject' and '✗' or '✓')
end

---Move to the next changed file in the tree, wrapping.
---This is the "track what the agent is editing" half: with a changeset of any
---size, walking rows by hand means re-reading the same list after every reply.
local function next_changed()
  -- rows is rebuilt on every render and holds the subset of lines that map to a
  -- path, so the ordered key list IS the tree in display order.
  local lines = vim.tbl_keys(rows)
  if #lines == 0 then
    return
  end
  table.sort(lines)
  local cur = vim.fn.line('.')
  local next_line
  for _, line in ipairs(lines) do
    if line > cur then
      next_line = line
      break
    end
  end
  vim.api.nvim_win_set_cursor(0, { next_line or lines[1], 0 })
end

---Open the patch the agent proposed for the file under the cursor.
local function show_patch()
  local target = path_under_cursor()
  local srv = server()
  if not target or not srv then
    return
  end
  if not state.session then
    vim.notify('No session id yet — ask the agent something first', vim.log.levels.WARN)
    return
  end
  local name = vim.fn.fnamemodify(target, ':t')
  srv:curl(
    '/session/' .. state.session .. '/diff?directory=' .. encode_dir(state.root),
    'GET',
    nil,
    function(body)
      local ok, decoded = pcall(vim.json.decode, body)
      if not ok or type(decoded) ~= 'table' then
        vim.notify('Could not decode the session diff', vim.log.levels.ERROR)
        return
      end
      for _, d in ipairs(decoded) do
        if vim.fs.normalize(d.file or '') == vim.fs.normalize(target) then
          vim.cmd('split ' .. vim.fn.fnameescape(target))
          vim.cmd('new')
          vim.bo.buftype = 'nofile'
          vim.bo.swapfile = false
          vim.bo.filetype = 'diff'
          vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(d.patch or '(empty patch)', '\n'))
          vim.bo.modifiable = false
          vim.cmd('file [patch] ' .. name)
          return
        end
      end
      vim.notify('No patch recorded for ' .. name, vim.log.levels.WARN)
    end,
    function()
      vim.notify('Could not fetch the session diff', vim.log.levels.ERROR)
    end
  )
end

-- --- window ----------------------------------------------------------------

local function ensure_tree()
  local api = require('nvim-tree.api')
  api.tree.open { focus = false }
  tree_win = api.tree.winid()
  if not tree_win then
    error('Could not locate the NvimTree window')
  end
end

local function show()
  if not win or not win:valid() then
    ensure_tree()
    win = require('snacks.win') {
      relative = 'win',
      win = tree_win,
      position = 'bottom',
      height = 0.4,
      border = 'none',
      enter = false,
      focusable = true,
      bo = { filetype = 'agent_panel', buftype = 'nofile', bufhidden = 'wipe', swapfile = false },
      wo = { winfixwidth = true, winfixheight = true, wrap = false, cursorline = true, number = false, signcolumn = 'no' },
      keys = {
        q = 'hide',
        r = function()
          M.refresh()
        end,
        ['<CR>'] = function(self)
          open_file()
          self:hide()
        end,
      },
      footer = '<CR> open · d patch · da accept · dr reject · dp next · r refresh · q close',
    }
    win:set_title('Agent', 'left')
    vim.api.nvim_buf_set_extmark(win.buf, activity_ns, 0, 0, { virt_lines = { { { ' Agent ', 'Title' } } } })
    vim.keymap.set('n', 'd', show_patch, { buffer = win.buf, nowait = true, desc = 'Show proposed patch' })
    vim.keymap.set('n', 'da', function()
      reply_file('once')
    end, { buffer = win.buf, nowait = true, desc = 'Accept the file under the cursor' })
    vim.keymap.set('n', 'dr', function()
      reply_file('reject')
    end, { buffer = win.buf, nowait = true, desc = 'Reject the file under the cursor' })
    vim.keymap.set('n', 'dp', next_changed, { buffer = win.buf, nowait = true, desc = 'Next changed file' })
    vim.api.nvim_create_autocmd('CursorMoved', {
      group = augroup,
      buffer = win.buf,
      callback = function()
        vim.diagnostic_hl(win.win, 0, 0, vim.fn.line('.') - 1, 0)
      end,
    })
    update()
    M.refresh()
  end
  return win
end

local function toggle()
  if win and win:valid() then
    close()
  else
    show()
  end
end

-- --- live turn timeline ----------------------------------------------------

-- Shapes verified against the server's own SSE on opencode 1.18.32 (2026-09-25)
-- and the @opencode-ai/sdk Part union, NOT guessed from a schema:
--   tool     -> part.tool, part.state.status in {pending,running,completed,error},
--               part.state.time.start/.end
--   reasoning-> part.text (streams), part.time.start/.end
--   text     -> part.text (streams), part.time.start/.end
--   agent    -> part.name
-- Anything else is kept out of the panel: a timeline that renders every new
-- part type the server invents next release is a timeline nobody can read.

local TOOL_MARK = {
  pending = '·',
  running = '●',
  completed = '✓',
  error = '✗',
}

local function truncate(s, n)
  s = (s or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
  if #s > n then
    return s:sub(1, n) .. '…'
  end
  return s
end

secs = function(from_ms, to_ms)
  if not from_ms then
    return ''
  end
  return string.format('%.1fs', ((to_ms or (vim.uv.now() * 1000)) - from_ms) / 1000)
end

---Fold one `message.part.updated` into the timeline.
local function record_part(part)
  if type(part) ~= 'table' or type(part.type) ~= 'string' then
    return
  end
  local t = part.state or {}
  -- `time` is a Lua keyword, so these have to go through bracket access. The
  -- server sends the field as "time" (verified in the SDK's ToolState and
  -- TextPart types), it just cannot be written as t.time in source.
  local tm = t['time'] or part['time'] or {}

  local entry
  if part.type == 'tool' then
    entry = {
      kind = 'tool',
      mark = TOOL_MARK[t.status] or '·',
      name = part.tool or 'tool',
      -- `title` is the server's one-line human summary ("Read src/foo.ts"), and
      -- is far more useful than dumping the raw tool input JSON.
      detail = truncate(t.title or t.output or '', 46),
      ms = secs(tm.start, tm['end']),
    }
  elseif part.type == 'reasoning' then
    entry = { kind = 'think', mark = '∴', name = 'thinking', detail = truncate(part.text, 46), ms = secs(tm.start, tm['end']) }
  elseif part.type == 'text' then
    -- Synthetic parts are context echoes (@this, @buffers) -- they are the
    -- prompt, not the answer, and they dominate the timeline if shown.
    if part.synthetic then
      return
    end
    entry = { kind = 'say', mark = '»', name = 'answer', detail = truncate(part.text, 46), ms = secs(tm.start, tm['end']) }
  elseif part.type == 'agent' then
    entry = { kind = 'agent', mark = '⚑', name = 'subagent: ' .. (part.name or '?'), detail = '', ms = '' }
  else
    return
  end

  -- Same part id -> replace in place. opencode re-sends a part every time it
  -- changes (a tool's pending -> running -> completed, reasoning growing token
  -- by token), so this is what keeps the panel from becoming a duplicate log.
  local at = state.by_id[part.id]
  if at then
    state.turn[at] = entry
    return
  end
  table.insert(state.turn, entry)
  state.by_id[part.id] = #state.turn
  -- ponytail: bounded to 40; a long session's history is in the terminal, and
  -- the panel's job is "what is the agent doing right now".
  if #state.turn > 40 then
    table.remove(state.turn, 1)
    for id, i in pairs(state.by_id) do
      if i == 1 then
        state.by_id[id] = nil
      elseif i > 1 then
        state.by_id[id] = i - 1
      end
    end
  end
end

---Reset the timeline for a new turn.
---
---Deliberately does NOT clear `started_at`. Measured event order (opencode
---1.18.32) is: session.status busy -> message.updated(user) -> parts, so the
---busy that starts the clock has already fired by the time this runs. Clearing
---it here left the elapsed line permanently blank; the turn start is re-stamped
---at the call site instead.
local function clear_turn()
  state.turn, state.by_id = {}, {}
end

-- --- events ----------------------------------------------------------------

local function handle(event)
  if type(event) ~= 'table' or type(event.type) ~= 'string' then
    return
  end
  local properties = event.properties or {}
  -- Every event carries a sessionID once one exists; remember the first so
  -- `d` can ask the server what it actually wants to change.
  state.session = state.session or properties.sessionID or properties.sessionId

  if event.type == 'server.connected' then
    state.status, state.detail, state.error = 'IDLE', 'Connected', nil
  elseif event.type == 'message.part.updated' then
    -- The live feed. This is the event that makes the panel show the agent
    -- working rather than only its results.
    record_part(properties.part)
  elseif event.type == 'message.updated' then
    -- A new user prompt is the clean boundary between turns: parts from the
    -- previous turn keep arriving for a moment after the next one starts, so
    -- resetting on idle would interleave two turns in one list.
    local info = properties.info or {}
    if info.role == 'user' and info.id ~= state.user_msg then
      state.user_msg = info.id
      clear_turn()
      if state.status == 'RUNNING' then
        state.started_at = state.started_at or (vim.uv.now() * 1000)
      end
    end
  elseif event.type == 'session.idle' then
    -- Turn over. The timeline stays on screen as the record of what just
    -- happened; a new turn resets it when its first part arrives.
    if state.status == 'RUNNING' then
      state.status, state.detail = 'IDLE', 'Turn complete'
    end
    state.started_at = nil
  elseif event.type == 'session.error' then
    local err = properties.error or {}
    local msg = err.data and err.data.message or err.message or 'OpenCode reported an error'
    state.status, state.detail, state.error = 'FAILED', 'Turn failed', msg
    state.started_at = nil
  elseif event.type == 'session.status' then
    local status = properties.status or {}
    state.status = status.type == 'busy' and 'RUNNING' or status.type == 'error' and 'FAILED' or 'IDLE'
    state.detail = status.type or 'Connected'
    state.error = status.type == 'error' and (status.message or 'OpenCode reported an error') or nil
    if status.type == 'busy' and not state.started_at then
      state.started_at = vim.uv.now() * 1000
    end
  elseif event.type == 'session.execution.started' then
    state.status, state.detail, state.error = 'RUNNING', 'Agent is working', nil
    if not state.started_at then
      state.started_at = vim.uv.now() * 1000
    end
  elseif event.type == 'permission.asked' then
    local file = properties.metadata and properties.metadata.filepath
    file = file or (properties.patterns and properties.patterns[1])
    state.file = normalize(file)
    state.review = { id = properties.id, file = state.file, diff = properties.metadata and properties.metadata.diff }
    if properties.id ~= nil then
      state.reviews[properties.id] = true
      -- Index by file so `da`/`dr` can act on the row under the cursor.
      if state.file then
        state.review_files[state.file] = state.review_files[state.file] or {}
        table.insert(state.review_files[state.file], properties.id)
      end
    end
    state.status = 'REVIEW'
    state.detail = 'Permission requested'
    state.error = nil
  elseif event.type == 'file.edited' then
    local file = properties.filePath or properties.filepath or properties.path or properties.file
    if type(file) == 'table' then
      file = file.filepath or file.filePath or file.path
    end
    file = normalize(file)
    if file then
      state.file = file
      add_recent(file, '◌')
    end
    -- Counts come from the server, not from this event, so re-read the whole
    -- change set rather than guessing what moved.
    M.refresh()
    return
  elseif event.type == 'permission.replied' then
    local id = properties.requestID or properties.id
    local reply = properties.response or properties.reply or properties.decision or properties.result
    if id ~= nil then
      state.reviews[id] = nil
      -- Drop the id from whichever file queue held it, so a stale id can never
      -- be replied to twice (`da` twice would 404 on the second).
      for file, ids in pairs(state.review_files) do
        local kept = {}
        for _, queued in ipairs(ids) do
          if queued ~= id then
            kept[#kept + 1] = queued
          end
        end
        if #kept == 0 then
          state.review_files[file] = nil
        else
          state.review_files[file] = kept
        end
      end
    end
    if state.review and state.review.id == id then
      local rejected = reply == 'reject' or reply == 'rejected' or reply == false
      local target = state.review.file or state.file
      state.review = nil
      if target then
        add_recent(target, rejected and '✗' or '✓')
      end
    end
    if state.status == 'REVIEW' and vim.tbl_isempty(state.reviews) then
      state.status, state.detail = 'IDLE', 'Connected'
    end
    M.refresh()
    return
  elseif event.type == 'server.instance.disposed' then
    state.status, state.detail, state.error = 'FAILED', 'Server disconnected', 'Server disconnected'
    state.changes = {}
  end
  update()
end

-- --- setup -----------------------------------------------------------------

function M.reset(root)
  state.root = vim.fs.normalize(root or vim.fn.getcwd())
  state.status, state.detail, state.file, state.review = 'DISCONNECTED', 'No active server', nil, nil
  state.reviews, state.recent, state.error = {}, {}, nil
  state.review_files = {}
  state.changes, state.session = {}, nil
  state.mcp = nil
  state.user_msg, state.started_at = nil, nil
  clear_turn()
end

function M.handle(event)
  handle(event)
end

function M.render()
  return render()
end

---MCP summary line, exposed for the spec. The rendered panel already carries
---this string; re-deriving it here would let the two drift apart silently.
function M.mcp_summary()
  return mcp_summary()
end

---Feed a raw /mcp response body, exactly as the server sends it.
function M.set_mcp(body)
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= 'table' then
    return
  end
  local out = {}
  for name, entry in pairs(decoded) do
    if type(entry) == 'table' then
      table.insert(out, { name = name, status = entry.status or 'unknown', error = entry.error })
    else
      table.insert(out, { name = name, status = tostring(entry) })
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  state.mcp = out
end

---Seed the change tree directly. The live path is `refresh()`; this exists so
---the rendering half can be tested without a server (see agent-panel_spec).
function M.set_changes(changes)
  state.changes = changes or {}
  update()
end

function M.show()
  return show()
end

function M.toggle()
  toggle()
end

---Forget the panel's window without touching the buffer.
---
---`toggle()` cannot do this: it re-runs `ensure_tree()` on the next open, and
---that errors if the user has closed NvimTree. The panel docks to whatever tree
---window exists, so losing the tree must lose the panel too -- hence the
---FileType guard in setup(). This is that recovery, on a key.
function M.detach()
  if win and win:valid() then
    win:hide()
  end
  win = nil
  tree_win = nil
end

function M.open_file()
  open_file()
end

function M.is_open()
  return win ~= nil and win:valid()
end

---Current opencode session id, or nil before the first event.
---Used by checkpoints.lua to scope snapshots to one agent session.
function M.session()
  return state.session
end

---Pending permission ids for a file, oldest first.
---
---The only public window onto `state.review_files`, which is otherwise a
---private local. It exists because that map's entire behaviour is "which ids
---does `da` send to permit()", and nothing else observable reflects it: the
---REVIEW badge is driven by `state.reviews` (keyed by id, not by file), so it
---stays lit whether or not the per-file map is correct. Without this, the
---pruning logic could be wrong and every other assertion would still pass --
---verified by deliberately breaking the prune and watching the spec stay green.
---@param file string
---@return number[]
function M.pending_replies(file)
  return vim.deepcopy(state.review_files[file] or {})
end

function M.setup()
  augroup = vim.api.nvim_create_augroup('OpenCodeAgentPanel', { clear = true })
  activity_ns = vim.api.nvim_create_namespace('OpenCodeAgentPanel')
  vim.api.nvim_create_autocmd('User', {
    group = augroup,
    pattern = 'OpencodeEvent:*',
    callback = function(args)
      handle(args.data and args.data.event)
    end,
  })
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup,
    pattern = 'NvimTree',
    callback = function()
      if win and not win:valid() then
        win = nil
      end
    end,
  })

  -- Live tracking: the tree must follow the agent, not just react to the one
  -- event that happened to arrive. 1.5s is fast enough to feel live and slow
  -- enough that a long session does not turn into a poll storm.
  --
  -- The elapsed counter rides this same tick instead of owning a second timer:
  -- a busy agent emits parts constantly, so anything more precise than 1.5s is
  -- false precision on a number that is meant to answer "is it stuck?".
  -- ponytail: fixed interval; switch to server push (or stop polling when the
  -- panel is closed) if it ever shows up in a profile.
  if poll_timer then
    poll_timer:stop()
    poll_timer:close()
  end
  poll_timer = vim.uv.new_timer()
  poll_timer:start(
    1500,
    1500,
    vim.schedule_wrap(function()
      if not M.is_open() then
        return
      end
      if state.started_at and state.status == 'RUNNING' then
        -- Repaint for the clock even with no server to re-read changes from.
        update()
      end
      if server() then
        M.refresh()
      end
    end)
  )

  M.reset(vim.fn.getcwd())

  -- Without this the panel keeps the root it was set up with: change tree, MCP
  -- poll, and patch fetch all point at the directory you left. Work in two
  -- projects in one nvim session and the panel is quietly wrong.
  vim.api.nvim_create_autocmd('DirChanged', {
    group = vim.api.nvim_create_augroup('AgentPanelDirChanged', { clear = true }),
    callback = function()
      M.reset(vim.fn.getcwd())
    end,
    desc = 'Re-root the agent panel when the working directory changes',
  })
end

return M
