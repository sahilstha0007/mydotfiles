-- Run several agents side by side (the Antigravity Agent Manager equivalent).
--
-- Measured, not assumed:
--   * `opencode serve --port 0` takes an OS-assigned port when 4096 is taken and
--     prints it on stdout. Three same-cwd servers ran concurrently on 37113 /
--     4096 / 33277 with no crash (1.18.32) -- the Bun segfault the single-
--     instance guard was written for no longer reproduces.
--   * opencode.nvim ALREADY has the manager: `discovery/init.lua` starts a
--     server at 0, uses the one it finds at 1, and at 2+ opens a picker that
--     scores servers by cwd-prefix overlap with nvim's cwd
--     (`ui/select_server.lua`). Nothing in the config ever reached 2+, because
--     the guard refused before a second server could exist.
--
-- So this module does not reimplement a manager. It starts extra servers in
-- their own tmux panes, which is what makes the count go above 1 -- and the
-- plugin's own picker takes over from there.
--
-- <Space>aA

local M = {}

---tmux pane holding an agent, as %id, or nil outside tmux.
---@return string|nil
local function here()
  return vim.env.TMUX_PANE
end

local function have_tmux()
  return vim.fn.executable('tmux') == 1 and here() ~= nil
end

---@return boolean ok, string message
local function run(argv)
  local out = vim.system(argv, { text = true }):wait()
  if not out then
    return false, 'could not run ' .. argv[1]
  end
  return out.code == 0, ((out.stdout or '') .. (out.stderr or ''))
end

---Existing opencode servers and the port each is on.
---Discovery is the same shape the plugin uses (pgrep for `serve`, then lsof
---for the listening port) so this list and the plugin's cannot disagree.
---@return {port: string, cwd: string?}[]
function M.servers()
  local out = {}
  local pids = vim.fn.systemlist('pgrep -f "opencode" 2>/dev/null')
  for _, pid in ipairs(pids) do
    if pid:match('^%d+$') then
      -- argv, not comm: `opencode` is a pnpm shell wrapper here, so the real
      -- process is the bun binary with `serve` in argv. Same reasoning as the
      -- guard in opencode-agent.lua.
      local raw = vim.uv.fs_readlink('/proc/' .. pid .. '/cmdline')
      local argv = raw and vim.split(raw, '\0', { trimempty = true }) or {}
      if vim.tbl_contains(argv, 'serve') then
        local port
        for _, exe in ipairs(vim.fn.systemlist('lsof -Pan -p ' .. pid .. '-iTCP -sTCP:LISTEN 2>/dev/null')) do
          port = exe:match('(127%.0%.0%.1:([0-9]+))')
          if port then
            port = port:match(':([0-9]+)$')
            break
          end
        end
        if port then
          local link = vim.uv.fs_readlink('/proc/' .. pid .. '/cwd')
          table.insert(out, { port = port, cwd = link })
        end
      end
    end
  end
  return out
end

local function notify(msg, level)
  vim.notify('agents: ' .. msg, level or vim.log.levels.INFO)
end

---Start one more agent for `cwd` in a fresh tmux pane.
---
---The pane is named so it is findable later, and `-d 70` makes it small: an
---agent you are watching should not take half the screen away from the code.
---@return boolean ok, string message
function M.spawn(cwd, agent)
  cwd = cwd or vim.fn.getcwd()
  agent = agent or 'opencode'
  if not have_tmux() then
    return false, 'not inside tmux — outside tmux there is no pane to put it beside'
  end
  local before = #M.servers()
  local name = 'agent-' .. agent
  local ok, out = run {
    'tmux', 'split-window', '-h', '-d', '-P', '-F', '#{pane_id}',
    '-c', cwd, '-n', name, agent,
  }
  if not ok then
    return false, vim.trim(out)
  end
  -- No waiting on a health poll: the server prints its port when it is up, and
  -- the plugin's discovery retries for 5s on its own. Sleeping here would
  -- block the UI for a start-up time we do not control.
  return true, string.format('%s started%s (pane %s)', agent, before > 0 and ' — pick a server on the next ask' or '', vim.trim(out))
end

function M.pick()
  local running = M.servers()
  local cwd = vim.fn.getcwd()

  vim.ui.select({
    { label = string.format('+ opencode here (%d running)', #running), act = function()
      local ok, msg = M.spawn(cwd, 'opencode')
      notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    end },
    { label = '+ claude here', act = function()
      local ok, msg = M.spawn(cwd, 'claude')
      notify(msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
    end },
  }, {
    prompt = string.format('Agents (%d opencode server%s): ', #running, #running == 1 and '' or 's'),
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if choice then
      choice.act()
    end
  end)
end

-- No keymap registered here. <leader>aA is owned by the lazy.nvim spec in
-- lua/plugins/editor/multi-agent.lua, which calls setup() on init. Registering
-- it in both places meant the second registration silently won and the first
-- was dead — the same failure mode that duplicate `virtual` names cause.
function M.setup() end

return M
