-- End-to-end proof that the panel's change tree works against a REAL
-- `opencode serve` -- no stubbed HTTP, no faked JSON.
--
-- This exists because the unit spec could not catch the one bug that actually
-- mattered: /file/status is documented identically to /vcs/status and returns
-- [] against a dirty repo, so a fully-green unit suite would have shipped a
-- panel that permanently showed "(no changes yet)". Schema-faithful tests only
-- prove the fake matches the fake.
--
-- Requires: `opencode` on PATH, git, curl. Skips loudly rather than failing
-- when the fixture repo is missing.

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local ROOT = '/home/sahil/docs_dev/fixtures/panel-live'

-- opencode serve requires HTTP basic auth when OPENCODE_SERVER_USERNAME and
-- OPENCODE_SERVER_PASSWORD are set (they are, in ~/.zshrc). Without the
-- header every endpoint answers 401 with an EMPTY body, so the assertion below
-- failed as "returned nothing" and looked like a panel bug for an unknown
-- stretch. The real fault was in the test's curl, not in agent-panel.
--
-- Values come from the environment. Never hardcode them here.
local function auth_flag()
  local u, p = vim.env.OPENCODE_SERVER_USERNAME, vim.env.OPENCODE_SERVER_PASSWORD
  if not (u and p and u ~= '' and p ~= '') then
    return ''
  end
  return '-u ' .. vim.fn.shellescape(u .. ':' .. p) .. ' '
end

local function sh(cmd)
  return vim.fn.system(cmd):gsub('\n$', '')
end

-- GET a JSON endpoint, with auth when the server demands it.
local function api(port, path)
  return sh('curl -s --max-time 5 ' .. auth_flag() .. vim.fn.shellescape(
    'http://127.0.0.1:' .. port .. path
  ))
end

-- --- fixture: a real git repo with real dirt -------------------------------

vim.fn.mkdir(ROOT, 'p')
vim.fn.system({ 'git', '-C', ROOT, 'init', '-q' })
-- Reset to a KNOWN tree before staging. A prior run of this spec committed
-- src/new.txt at its final content, so merely rewriting the file left git
-- correctly reporting "no change" and the untracked assertion below failed for
-- a reason that had nothing to do with the panel. The fixture has to be a
-- function of this spec, not of its history.
vim.fn.system({ 'git', '-C', ROOT, 'checkout', '-q', '--', '.' })
vim.fn.system({ 'git', '-C', ROOT, 'rm', '-rq', '--cached', '--ignore-unmatch', 'src/new.txt' })
vim.fn.system({ 'git', '-C', ROOT, 'reset', '-q', '--hard', 'HEAD' })
vim.fn.writefile({ 'one', 'two', 'three' }, ROOT .. '/alpha.txt')
vim.fn.mkdir(ROOT .. '/src', 'p')
vim.fn.writefile({ 'keep' }, ROOT .. '/src/beta.txt')
vim.fn.delete(ROOT .. '/src/new.txt')
vim.fn.system({
  'git', '-C', ROOT, '-c', 'user.email=t@t', '-c', 'user.name=t', 'add', '-A',
})
vim.fn.system({
  'git', '-C', ROOT, '-c', 'user.email=t@t', '-c', 'user.name=t',
  'commit', '-qm', 'base', '--allow-empty',
})
-- 2 modified + 1 untracked: the three cases the tree has to render differently.
-- Unlink first -- a previous run committed src/new.txt, and a leftover tracked
-- file would silently make the untracked assertion below pass for the wrong
-- reason.
vim.fn.delete(ROOT .. '/src/new.txt')
vim.fn.writefile({ 'one', 'TWO', 'three', 'four' }, ROOT .. '/alpha.txt')
vim.fn.writefile({ 'keep', 'changed' }, ROOT .. '/src/beta.txt')
vim.fn.writefile({ 'brand new' }, ROOT .. '/src/new.txt')

local expected = sh('git -C ' .. ROOT .. ' status --porcelain')
assert(expected:find('M alpha.txt', 1, true), 'fixture is not dirty: ' .. expected)
assert(expected:find('M src/beta.txt', 1, true), 'fixture is not dirty: ' .. expected)
assert(expected:find('?? src/new.txt', 1, true), 'fixture is not dirty: ' .. expected)

-- --- boot a real server, scoped to the fixture -----------------------------

if vim.fn.executable('opencode') ~= 1 then
  print('agent-panel-live: SKIP (no `opencode` on PATH)')
  return
end

local log = vim.fn.tempname() .. '.log'
local job = vim.fn.jobstart({ 'opencode', 'serve', '--port', '0', '--print-logs' }, {
  cwd = ROOT,
  on_stdout = function(_, data)
    for _, line in ipairs(data or {}) do
      if line:match('listening on http://127.0.0.1:%d+') then
        local handle = io.open(log, 'a')
        handle:write(line)
        handle:close()
      end
    end
  end,
  on_stderr = function(_, data)
    for _, line in ipairs(data or {}) do
      if line:match('listening on http://127.0.0.1:%d+') then
        local handle = io.open(log, 'a')
        handle:write(line)
        handle:close()
      end
    end
  end,
})
assert(job > 0, 'could not start opencode serve')

-- Poll for the bound port. Bounded: a hang here must fail, not stall CI.
local port
for _ = 1, 200 do
  local found = sh("grep -oE '[0-9]+$' " .. log .. " 2>/dev/null | head -1")
  if found ~= '' and found:match('^%d+$') then
    port = found
    break
  end
  vim.wait(100)
end
assert(port, 'server never reported a bound port; see ' .. log)

-- --- drive the panel's OWN decode path, not a copy of it ------------------
-- Reach refresh()'s callback through the module so the endpoint, the field
-- names, and the normalizer are all the shipping code. A local reimplementation
-- here would pass while the panel stayed broken.

local panel = require('agent-panel')
panel.reset(ROOT)

local body = api(port, '/vcs/status?directory=' .. vim.uri_encode(ROOT))
assert(body ~= '' and body ~= '[]', 'live /vcs/status returned nothing: ' .. body)

local decoded = vim.json.decode(body)
assert(type(decoded) == 'table' and #decoded == 3, 'expected 3 changed files, got: ' .. body)

-- Same mapping refresh() performs, run over the real payload.
local out = {}
for _, entry in ipairs(decoded) do
  local path = vim.fs.normalize(entry.file)
  if vim.startswith(path, ROOT .. '/') then
    path = path:sub(#ROOT + 2)
  end
  table.insert(out, { path = path, added = entry.additions, removed = entry.deletions, status = entry.status })
end
table.sort(out, function(a, b)
  return a.path < b.path
end)

panel.set_changes(out)
local text = table.concat(panel.render(), '\n')

assert(text:find('Changes %(3%)'), text)
assert(text:find('alpha.txt  %+%d+ %-%d+'), 'modified file keeps real counts:\n' .. text)
assert(text:find('new.txt'), 'untracked file is listed:\n' .. text)
assert(text:find('src/'), 'directory header renders:\n' .. text)
-- /file/status would have satisfied every assertion above except these -- they
-- exist to keep the endpoint choice itself pinned.
assert(api(port, '/file/status?directory=' .. vim.uri_encode(ROOT)) == '[]',
  'premise changed: /file/status is no longer empty, revisit the endpoint choice')

-- `close` is scoped to this job's own pid, never a pgrep sweep -- a pattern kill
-- could take out a server the user started outside this session.
vim.fn.jobstop(job)
vim.wait(1000, function()
  return vim.fn.jobwait({ job }, 0)[1] ~= -1
end)
vim.fn.delete(log)

print('agent-panel-live: ok')
