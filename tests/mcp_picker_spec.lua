-- MCP picker: reading and editing the opencode config.
--
-- Both functions under test here touch the user's live opencode config, which
-- sets their model. So every assertion runs against a throwaway XDG_CONFIG_HOME
-- with a synthetic config, never the real one.
--
-- The two things worth testing are the two places this can quietly go wrong:
--   - the file is .jsonc, and vim.json.decode throws on a `//` comment
--   - remove() rewrites the whole file, and a partial write makes opencode fail
--     to start at the *next* session, not now
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/mcp_picker_spec.lua

vim.opt.runtimepath:prepend('/home/sahil/.config/nvim')

local passed, failed = 0, 0
local function check(cond, msg)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

-- --- a throwaway config dir, pointed at by XDG_CONFIG_HOME -------------------
local home = vim.fn.tempname()
vim.fn.mkdir(home .. '/opencode', 'p')
vim.env.XDG_CONFIG_HOME = home
local path = home .. '/opencode/opencode.jsonc'

local function write(body)
  vim.fn.writefile(vim.split(body, '\n'), path)
end
local function slurp()
  return table.concat(vim.fn.readfile(path), '\n')
end
-- luanil so a written `"mcp": null` reads as nil rather than vim.NIL userdata.
local function read_json()
  return vim.json.decode(slurp(), { luanil = { object = true, array = true } })
end

local picker = require('mcp-picker')

-- --- list: no config at all -------------------------------------------------
write(vim.json.encode({ model = 'some/model' }))
check(picker.list().name == nil, 'a config with no mcp key should list nothing')
check(#picker.list() == 0, 'expected zero servers, got ' .. #picker.list())

-- --- list: servers, sorted, status from `enabled` ---------------------------
write(vim.json.encode({
  model = 'some/model',
  mcp = {
    zeta = { type = 'remote', url = 'https://z.example/mcp', enabled = true },
    alpha = { type = 'remote', url = 'https://a.example/mcp', enabled = false },
  },
}))
local servers = picker.list()
check(#servers == 2, 'expected 2 servers, got ' .. #servers)
check(servers[1].name == 'alpha', 'not sorted alphabetically: ' .. (servers[1] and servers[1].name or 'nil'))
check(servers[1].status == 'disabled', 'enabled:false should read as disabled, got ' .. servers[1].status)
check(servers[2].status == 'configured', 'an enabled server should read configured, got ' .. servers[2].status)
check(servers[2].url == 'https://z.example/mcp', 'url not carried through: ' .. tostring(servers[2].url))

-- --- list: the .jsonc comment path -----------------------------------------
-- This is the case that breaks on a machine where the user has annotated their
-- config, which is the normal state for a hand-maintained file.
write(table.concat({
  '{',
  '  // the model I actually use',
  '  "model": "some/model",',
  '  "mcp": { "alpha": { "type": "remote", "url": "https://a.example/mcp" } }',
  '}',
}, '\n'))
local commented = picker.list()
check(#commented == 1, 'a commented config should still list its server, got ' .. #commented)
check(commented[1] and commented[1].name == 'alpha', 'comment stripped the wrong thing: ' .. vim.inspect(commented))

-- --- list: unparseable config must not throw --------------------------------
write('{ this is not json')
local junk = pcall(picker.list)
check(junk, 'list() must not throw on a malformed config')

-- --- remove: an unparseable config must be left alone, byte for byte -------
-- The failure this guards is the worst one available: nvim rewrites a config
-- it could not read, the user's model and every other key are gone, and they
-- find out at the next opencode start. Refusing costs them one manual fix.
local malformed = '{ this is not json'
write(malformed)
local refused, why = picker.remove('anything')
check(refused == false, 'remove must refuse a config it cannot parse')
check(slurp() == malformed, 'the malformed config was rewritten anyway: ' .. slurp())
check(tostring(why):find('nothing was changed', 1, true) ~= nil, 'the refusal should say the file is untouched: ' .. tostring(why))

-- --- remove: refuses a server that is not there -----------------------------
check(picker.remove('nope') == false, 'removing an unknown server should fail')

-- --- remove: takes out exactly one entry, leaves the rest of the file alone --
write(vim.json.encode({
  model = 'the/user/model',
  theme = 'tokyonight',
  mcp = {
    keepme = { type = 'remote', url = 'https://k.example/mcp' },
    goneme = { type = 'remote', url = 'https://g.example/mcp' },
  },
}))
local ok, msg = picker.remove('goneme')
check(ok, 'remove should succeed on a configured server: ' .. tostring(msg))
check(picker.list().name == 'keepme' or #picker.list() == 1, 'wrong server count after remove: ' .. #picker.list())
local after = picker.list()
check(after[1] and after[1].name == 'keepme', 'the surviving server is wrong: ' .. (after[1] and after[1].name or 'nil'))
local body = read_json()
check(body.model == 'the/user/model', 'remove clobbered model: ' .. tostring(body.model))
check(body.theme == 'tokyonight', 'remove clobbered an unrelated key: ' .. tostring(body.theme))

-- --- remove: the last server leaves the config valid ------------------------
-- An empty Lua table encodes as `{}` (an object) rather than `[]`, which
-- opencode would read as "one server with a weird name" instead of "no servers".
write(vim.json.encode({ model = 'the/user/model', mcp = { only = { url = 'https://o.example/mcp' } } }))
check(picker.remove('only'), 'removing the only server should succeed')
check(#picker.list() == 0, 'after removing the last server there should be none, got ' .. #picker.list())
local emptied = read_json()
check(emptied.mcp == nil or vim.tbl_count(emptied.mcp) == 0, 'an empty mcp map should be dropped, got: ' .. slurp())
check(emptied.model == 'the/user/model', 'emptying mcp clobbered model')

-- --- remove: no leftover temp file ------------------------------------------
check(vim.fn.filereadable(path .. '.mcpbak') == 0, 'the atomic-write temp file was left behind')

print(string.format('mcp_picker: %d passed, %d failed', passed, failed))
if failed > 0 then
  vim.cmd('cq')
else
  vim.cmd('qa!')
end
