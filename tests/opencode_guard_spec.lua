-- Loop 2 gate: prove the single-instance guard against a REAL opencode server.
--
-- The guard lives in the `server.start` override in
-- lua/plugins/editor/opencode-agent.lua. Its job is to stop this nvim from
-- spawning a second `opencode serve` when one is already running for this
-- cwd -- the duplicate-spawn race behind the Bun segfault.
--
-- History, because it is the whole reason this file exists: the guard used to
-- match `basename(argv[1]) == 'opencode'` and `tbl_contains(argv, '--port')`.
-- On this machine `opencode` is a pnpm shell wrapper, so the real server's
-- argv is:
--     argv[0] = .../node_modules/opencode-ai/bin/opencode.exe
--     argv[1] = serve
--     argv[2] = --port
-- That guard could therefore never fire: it demanded a shape no real server
-- has. The gate below pins the corrected behaviour against a live process so
-- that regression cannot come back unnoticed.
--
--   A. real `opencode serve` for this cwd  => detected (true positive)
--   B. arbitrary lookalike mentioning the words => NOT detected (no false +
--      silently refusing to start when nothing is running)
--   C. a server for a DIFFERENT cwd       => NOT detected (projects isolated)
--   D. the plugin's OWN discovery finds it  (the gate that actually matters)

local root = '/home/sahil/.config/nvim'
vim.opt.rtp:prepend(root)

-- --- copied verbatim from opencode-agent.lua -------------------------------

local function normalize(path)
  path = vim.uv.fs_realpath(path) or vim.fs.normalize(path)
  return path ~= '/' and path:gsub('/+$', '') or path
end

local function overlaps(a, b)
  a, b = normalize(a), normalize(b)
  local function contains(parent, child)
    local prefix = parent == '/' and '/' or parent .. '/'
    return child == parent or child:sub(1, #prefix) == prefix
  end
  return contains(a, b) or contains(b, a)
end

local function server_overlaps(cwd)
  for _, dir in ipairs(vim.fn.glob('/proc/[0-9]*', false, true)) do
    local pid = dir:match('/proc/(%d+)$')
    local exe = pid and vim.uv.fs_readlink(dir .. '/exe')
    if exe and exe:match('[/\\]opencode[^/\\]*$') then
      local cmdline = dir .. '/cmdline'
      local file = io.open(cmdline, 'rb')
      local raw = file and file:read('*a')
      if file then
        file:close()
      end
      local argv = raw and vim.split(raw, '\0', { plain = true, trimempty = true }) or {}
      if vim.tbl_contains(argv, 'serve') then
        local process_cwd = vim.uv.fs_readlink(dir .. '/cwd')
        if process_cwd and overlaps(process_cwd, cwd) then
          return true
        end
      end
    end
  end
  return false
end

-- --- helpers ---------------------------------------------------------------

local cwd = vim.fn.getcwd()

-- Start a real `opencode serve` in THIS cwd, on a free-ish high port.
local port = 49300 + (vim.fn.getpid() % 400)
local server = vim.fn.jobstart({ 'opencode', 'serve', '--port', tostring(port) }, {
  cwd = cwd,
  on_stdout = function() end,
  on_stderr = function() end,
  on_exit = function() end,
})
assert(server > 0, 'could not launch opencode serve for the test')

-- Wait for the server to be listening (the guard keys on the process, so it
-- only needs the process to exist -- but the health check proves it is real).
local listening = false
for _ = 1, 60 do
  if server_overlaps(cwd) then
    listening = true
    break
  end
  vim.wait(250, function()
    return false
  end)
end

if not listening then
  pcall(vim.fn.jobstop, server)
  error('FAIL A: a real `opencode serve` for this cwd was NOT detected by the guard')
end
io.write('A ok: real `opencode serve` detected for this cwd\n')

-- D. The guard is only half the contract. The OTHER half is that opencode.nvim
--    can find the server at all: it scans with `pgrep -f "opencode.*--port"`
--    (server/discovery/process/unix.lua:5). A server without `--port` in its
--    argv is invisible to the plugin, so every ask dies with
--    "No OpenCode servers found with overlapping CWD".
--    This is the assertion that would have caught the `serve`-without-`--port`
--    regression, and it is why `command` carries `--port 0`.
local discovered = vim.fn.systemlist('pgrep -f "opencode.*--port"')
assert(#discovered > 0, 'FAIL D: plugin pgrep cannot find the server we start')
io.write('D ok: plugin discovery (pgrep -f "opencode.*--port") finds the server\n')

-- C. A server for a different cwd must not count. /proc is a different tree.
assert(not server_overlaps('/proc'), 'FAIL C: non-overlapping cwd treated as served')
io.write('C ok: other cwd not treated as served\n')

-- B. A lookalike whose command line merely mentions opencode + serve + port
--    must be ignored. This is the false positive that would silently stop a
--    server from ever starting. We only spawn a plain `sleep` with those words
--    in argv -- its exe is /usr/bin/sleep, so the guard must skip it.
local decoy = vim.fn.jobstart({ 'sleep', '30', 'opencode', 'serve', '--port' }, {
  cwd = cwd,
  on_exit = function() end,
})
if decoy > 0 then
  -- The guard must still report exactly the real server and nothing more.
  assert(server_overlaps(cwd), 'FAIL B: guard lost the real server when a decoy was alive')
  io.write('B ok: mention-only decoy did not confuse the guard\n')
  pcall(vim.fn.jobstop, decoy)
end

-- --- cleanup: the guard must release once the server is gone ---------------
pcall(vim.fn.jobstop, server)
local released = vim.wait(8000, function()
  return not server_overlaps(cwd)
end, 200)
assert(released, 'FAIL: guard still held ~8s after the server exited (stale /proc entry)')
io.write('cleanup ok: guard released after server exit\n')

io.write('opencode_guard: ok\n')
