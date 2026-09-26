-- Loop 3 gate: the agent panel is the live change explorer.
--
-- Two halves are testable without a server, and both are the ones that rot:
--   1. event -> state transitions (what the badge and counters say)
--   2. change list -> tree rendering (grouping, counts, ordering)
--
-- The network half (`GET /file/status`) is deliberately NOT stubbed here: a
-- fake response would only prove the fake matches. That half is covered
-- end-to-end by docs_dev/scripts/golden-path-check.sh, which polls a real
-- `opencode serve`.

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local panel = require('agent-panel')
local root = '/home/sahil/docs_dev/fixtures/opencode-harness'

-- --- 1. event -> state ----------------------------------------------------

panel.reset(root)
panel.handle({ type = 'session.status', properties = { status = { type = 'busy' } } })
panel.handle({
  type = 'permission.asked',
  properties = {
    id = 7,
    permission = 'edit',
    patterns = { 'src/alpha.txt' },
    metadata = {
      filepath = root .. '/src/alpha.txt',
      diff = '@@ -1 +1 @@\n-alpha original\n+alpha replace',
    },
  },
})
panel.handle({
  type = 'file.edited',
  properties = { filePath = root .. '/src/beta.txt' },
})

local text = table.concat(panel.render(), '\n')
assert(text:find('REVIEW', 1, true), text)
assert(text:find('src/alpha.txt', 1, true), text)
assert(text:find('Review: 1 pending', 1, true), text)
assert(text:find('src/beta.txt', 1, true), text)
assert(not text:find('SECRET_SENTINEL', 1, true), text)

panel.handle({
  type = 'permission.replied',
  properties = { requestID = 7, response = 'reject' },
})
text = table.concat(panel.render(), '\n')
assert(text:find('Review: 0 pending', 1, true), text)
assert(text:find('✗ src/alpha.txt', 1, true), text)

panel.handle({ type = 'server.instance.disposed' })
text = table.concat(panel.render(), '\n')
assert(text:find('FAILED', 1, true), text)
assert(text:find('Server disconnected', 1, true), text)

-- A disconnect must clear the tree, not leave a stale change list on screen.
assert(text:find('(no changes yet)', 1, true), text)

-- --- 2. change list -> tree ------------------------------------------------
-- `render()` reads `state.changes`, which only `refresh()` populates. Feed the
-- same shape `/file/status` returns (path/added/removed/status) and check the
-- tree groups by directory and keeps the counts.

panel.reset(root)
panel.set_changes({
  { path = 'src/alpha.txt', added = 3, removed = 1, status = 'modified' },
  { path = 'src/beta.txt', added = 10, removed = 0, status = 'modified' },
  { path = 'README.md', added = 5, removed = 5, status = 'modified' },
  { path = 'src/new.txt', added = 1, removed = 0, status = 'added' },
})
text = table.concat(panel.render(), '\n')

assert(text:find('Changes %(4%)'), text) -- one header line per seeded change
assert(text:find('src/', 1, true), 'directories render as headers:\n' .. text)
assert(text:find('%+3 %-1'), 'alpha keeps its counts:\n' .. text)
assert(text:find('%+10 %-0'), 'beta keeps its counts:\n' .. text)
assert(text:find('%+5 %-5'), 'root file keeps its counts:\n' .. text)
assert(text:find('new.txt'), 'added file is listed:\n' .. text)

-- A directory header must appear before its files, and -- the part that
-- actually matters -- a ROOT file must not be indented under a header. The
-- render is a flat list (all headers, then all files), so position alone can't
-- express nesting: indentation is the only signal, and it regressed once
-- already when render() used a fixed 4-space indent.
local dir_line, alpha_line, readme_line
for i, line in ipairs(panel.render()) do
  if line:find('src/', 1, true) then
    dir_line = dir_line or i
  end
  if line:find('alpha.txt', 1, true) then
    alpha_line = i
  end
  if line:find('README.md', 1, true) then
    readme_line = i
  end
end
assert(dir_line and alpha_line and dir_line < alpha_line, 'header before its files:\n' .. text)

local rendered = panel.render()
assert(readme_line, 'README.md is listed:\n' .. text)
assert(rendered[readme_line]:match('^%s*●'), 'root file is not nested:\n' .. text)
assert(#rendered[readme_line]:match('^%s*') == 2, 'root file sits at depth 0:\n' .. text)
assert(#rendered[alpha_line]:match('^%s*') == 4, 'nested file sits one level deeper:\n' .. text)

print('agent-panel: ok')
