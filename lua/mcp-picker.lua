-- MCP server manager (<Space>aM).
--
-- Everything goes through `opencode mcp`, which owns the config file. Writing
-- the JSON from nvim would mean two writers for one file, and opencode reads
-- it at session start -- the two would drift the first time a server was
-- added from the terminal.
--
-- The agent reads MCP servers from its own config, so a server added here is
-- immediately available to it; this is the UI half of the gap, not a parallel
-- implementation.

local M = {}

---@return boolean ok, string out
local function run(args)
  local out = vim.system({ 'opencode', unpack(args) }, { text = true }):wait()
  if not out then
    return false, 'opencode could not be started'
  end
  return out.code == 0, ((out.stdout or '') .. (out.stderr or ''))
end

local function notify(msg, level)
  vim.notify('mcp: ' .. msg, level or vim.log.levels.INFO)
end

---Decode the opencode config, tolerating .jsonc comments.
---@return table|nil cfg
local function read_config(path)
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local body = table.concat(vim.fn.readfile(path), '\n')
  -- Only whole-line comments are stripped. A general `%-%-` strip looks right
  -- but eats the `//` in "https://" and takes the rest of the file with it:
  -- Lua patterns have no escapes, so `[^\n]` means "not backslash, not n",
  -- not "not newline". ponytail: a trailing comment after code on a line is
  -- not handled; switch to a real tokenizer if a user ever writes one.
  body = body:gsub('\n%s*//[^\r\n]*', '\n')
  -- luanil: without it a `"mcp": null` decodes to vim.NIL, which is userdata,
  -- so `pairs(cfg.mcp)` throws. That is exactly the shape remove() writes when
  -- the last server goes, so the writer would break its own reader.
  local ok, cfg = pcall(vim.json.decode, body, { luanil = { object = true, array = true } })
  if not ok or type(cfg) ~= 'table' then
    return nil
  end
  return cfg
end

---@return {name: string, status: string, url: string?}[]
function M.list()
  -- `mcp list` renders a box-drawing table; the config is the machine-readable
  -- source for the same data, and reading it cannot break when the table art
  -- changes.
  local cfg = read_config(opencode_config())
  local servers = {}
  for name, entry in pairs((cfg or {}).mcp or {}) do
    if type(entry) == 'table' then
      table.insert(servers, { name = name, status = entry.enabled == false and 'disabled' or 'configured', url = entry.url })
    end
  end
  table.sort(servers, function(a, b)
    return a.name < b.name
  end)
  return servers
end

function opencode_config()
  local base = vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')
  -- The CLI writes opencode.jsonc; the .json alongside it also exists on some
  -- setups, and opencode merges them.
  for _, name in ipairs({ 'opencode/opencode.jsonc', 'opencode/opencode.json' }) do
    local path = base .. '/' .. name
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
  return base .. '/opencode/opencode.jsonc'
end

local function add()
  vim.ui.input({ prompt = 'MCP server name: ' }, function(name)
    if not name or name == '' then
      return
    end
    vim.ui.input({ prompt = 'URL (remote server): ' }, function(url)
      if not url or url == '' then
        notify('a remote URL is required; add local servers with: opencode mcp add ' .. name, vim.log.levels.WARN)
        return
      end
      local ok, out = run({ 'mcp', 'add', name, '--url', url })
      if not ok then
        notify('add failed: ' .. vim.trim(out), vim.log.levels.ERROR)
        return
      end
      notify(vim.trim(out):gsub('^.-%*%*', ''))
      require('agent-panel').refresh()
    end)
  end)
end

---Delete a server's entry from the opencode config.
---
---There is no `opencode mcp remove` (verified: the subcommands are add / list /
---auth / logout / debug, and `logout` only clears OAuth credentials, leaving
---the server configured). So the entry is removed here, in place.
---@return boolean ok, string message
function M.remove(name)
  local path = opencode_config()
  if vim.fn.filereadable(path) == 0 then
    return false, 'no opencode config at ' .. path
  end
  local cfg = read_config(path)
  -- A config nvim cannot parse is a config nvim must not rewrite. Erroring out
  -- here beats returning a stack trace from decode() into vim.ui.select.
  if not cfg then
    return false, 'could not parse ' .. path .. ' — fix it by hand, nothing was changed'
  end
  if type(cfg.mcp) ~= 'table' or cfg.mcp[name] == nil then
    return false, name .. ' is not configured'
  end
  cfg.mcp[name] = nil
  if vim.tbl_isempty(cfg.mcp) then
    cfg.mcp = vim.NIL
  end
  local ok, encoded = pcall(vim.json.encode, cfg)
  if not ok then
    return false, 'could not re-encode ' .. path .. ' — nothing was changed'
  end
  -- Written atomically: a half-written config makes opencode fail to start, and
  -- the user would find out at the next session, not now.
  local tmp = path .. '.mcpbak'
  local f = io.open(tmp, 'w')
  if not f then
    return false, 'could not write ' .. tmp
  end
  f:write(encoded)
  f:close()
  local renamed = vim.uv.fs_rename(tmp, path)
  if not renamed then
    vim.fn.delete(tmp)
    return false, 'could not replace ' .. path
  end
  return true, name .. ' removed'
end

local function remove()
  local servers = M.list()
  if #servers == 0 then
    notify('no servers configured', vim.log.levels.WARN)
    return
  end
  vim.ui.select(servers, {
    prompt = 'Remove which MCP server? ',
    format_item = function(s)
      return s.name .. (s.url and ('  ' .. s.url) or '')
    end,
  }, function(choice)
    if not choice then
      return
    end
    vim.ui.select({ 'Cancel', 'Remove ' .. choice.name }, { prompt = 'Remove ' .. choice.name .. '? ' }, function(pick)
      if pick and pick:find('^Remove') then
        local ok, msg = M.remove(choice.name)
        notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
        require('agent-panel').refresh()
      end
    end)
  end)
end

function M.pick()
  local servers = M.list()
  local items = { { label = '+ Add a server', action = add } }
  for _, s in ipairs(servers) do
    table.insert(items, {
      label = string.format('%-18s %s  %s', s.name, s.status, s.url or 'local'),
      action = function()
        vim.ui.input({ prompt = 'URL for ' .. s.name .. ' (empty = keep): ' }, function(url)
          if url and url ~= '' then
            run({ 'mcp', 'add', s.name, '--url', url })
            require('agent-panel').refresh()
          end
        end)
      end,
    })
  end
  if #servers > 0 then
    table.insert(items, { label = '✗ Remove a server', action = remove })
  end

  vim.ui.select(items, {
    prompt = string.format('MCP servers (%d): ', #servers),
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if choice then
      choice.action()
    end
  end)
end

return M
