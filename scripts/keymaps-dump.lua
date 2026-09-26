-- Keymap dump tool. Bootstraps its own probe git repo at /tmp/probe_repo
-- (git init + tracked main.py) so gitsigns buffer maps attach; no cwd needed.
-- Usage: nvim --headless -u ~/.config/nvim/init.lua -c "luafile ~/.config/nvim/scripts/keymaps-dump.lua" -c "qa!"
-- Writes ~/.cache/nvim/keymaps_dump.json (all modes, global + buffer-local).
-- Final union dump: force-load mini.nvim modules (VeryLazy headless miss),
-- attach gitsigns (buffer maps), then dump global + buffer maps.
-- Neutralize session persistence for this headless run: the user config
-- (lua/plugins/editor/mini.lua) writes session 'last' on VimLeavePre when a
-- named buffer exists (our probe main.py would trigger it). Clear the group
-- at script end (after plugin spec has created it) instead of guessing timing.
local clear_session_autosave = function()
  pcall(vim.api.nvim_clear_autocmds, { group = 'mini-sessions' })
end
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Bootstrap the probe repo (tracked file → gitsigns attaches)
local probe = '/tmp/probe_repo'
if vim.fn.isdirectory(probe .. '/.git') == 0 then
  vim.fn.mkdir(probe, 'p')
  vim.fn.writefile({ 'x = 1', '' }, probe .. '/main.py')
  vim.fn.system({ 'git', '-C', probe, 'init', '--quiet' })
  vim.fn.system({ 'git', '-C', probe, 'add', 'main.py' })
  vim.fn.system({ 'git', '-C', probe, '-c', 'user.email=dump@local', '-c', 'user.name=dump', 'commit', '--quiet', '-m', 'track main.py' })
end

-- Force-load every lazy spec so keys=/module maps exist
local ok = pcall(function()
  -- trigger lazy load of everything with a build/keys lazy trigger
  vim.cmd('Lazy load mini.nvim')
  vim.cmd('Lazy load gitsigns.nvim')
  vim.cmd('Lazy load grug-far.nvim')
  vim.cmd('Lazy load yanky.nvim')
  vim.cmd('Lazy load venv-selector.nvim')
  vim.cmd('Lazy load octo.nvim')
end)


-- Fire VeryLazy (headless never does) so deferred maps load
local ok_vl = pcall(function()
  vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy' })
end)
-- also force treesitter-textobjects config now that autocmd fired
local ok_to = pcall(function()
  local lazycfg = require('lazy.core.config').plugins['nvim-treesitter-textobjects']
  if lazycfg and not lazycfg._.loaded then
    require('lazy').load({ plugins = { 'nvim-treesitter-textobjects' } })
  end
end)

-- Force-load mini.nvim submodules that VeryLazy-defer
for _, mod in ipairs({ 'mini.surround', 'mini.move', 'mini.ai', 'mini.bracketed', 'mini.operators' }) do
  pcall(require, mod)
end

-- gitsigns attach on a scratch git buffer so on_attach buffer maps exist
local gs_err = nil
local gs_ok = pcall(function()
  vim.cmd('edit /tmp/probe_repo/main.py')
  vim.cmd('write')
  local gs = require('gitsigns')
  local aok, aerr = pcall(gs.attach, {
    bufnr = 0,
    ctx = {
      file = vim.api.nvim_buf_get_name(0),
      gitdir = '/tmp/probe_repo/.git',
      toplevel = '/tmp/probe_repo',
    },
  })
  if not aok then gs_err = tostring(aerr) end
  vim.wait(1500, function() return false end)
  -- retry once (throttle may have deferred)
  pcall(gs.attach, {
    bufnr = 0,
    ctx = {
      file = vim.api.nvim_buf_get_name(0),
      gitdir = '/tmp/probe_repo/.git',
      toplevel = '/tmp/probe_repo',
    },
  })
  vim.wait(1500, function() return false end)
end)
if gs_err then print('GS ATTACH ERR: ' .. gs_err) end
print('gs attach done, ok=' .. tostring(gs_ok) .. ' bufmaps=' .. #vim.api.nvim_buf_get_keymap(0, 'n'))

-- Now that all plugin specs have run (incl. the mini-sessions VimLeavePre
-- autocmd), clear it so this headless run never writes session 'last'.
clear_session_autosave()

local function safe(v)
  local t = type(v)
  if t == 'string' or t == 'number' or t == 'boolean' then return v end
  if t == 'function' then return '<function>' end
  if t == 'nil' then return nil end
  if t == 'table' then
    local out = {}
    for k2, v2 in pairs(v) do
      if type(k2) == 'string' or type(k2) == 'number' then out[tostring(k2)] = safe(v2) end
    end
    return out
  end
  return tostring(v)
end

local function dump(getmaps, buf)
  local out = {}
  for _, mode in ipairs({ 'n', 'v', 'x', 's', 'o', 'i', 'l', 'c', 't' }) do
    local maps = {}
    local ok2, res = pcall(getmaps, mode, buf)
    if ok2 and res then
      for _, m in ipairs(res) do
        table.insert(maps, {
          lhs = safe(m.lhs), lhsraw = safe(m.lhsraw),
          rhs = safe(m.rhs), silent = safe(m.silent),
          desc = safe(m.desc), buffer = safe(m.buffer),
          nowait = safe(m.nowait), noremap = safe(m.noremap),
          mode = safe(m.mode), script = safe(m.script),
          expr = safe(m.expr), sid = safe(m.sid),
          script_version = safe(m.script_version),
          replace_keycodes = safe(m.replace_keycodes),
          callback = safe(m.callback),
        })
      end
      table.sort(maps, function(a, b) return (a.lhs or '') < (b.lhs or '') end)
      out[mode] = maps
    end
  end
  return out
end

local result = {
  generated = os.date('%Y-%m-%dT%H:%M:%S'),
  global = dump(vim.fn.maparg and function(mode) return vim.api.nvim_get_keymap(mode) end or function(mode) return vim.api.nvim_get_keymap(mode) end),
  buffer = dump(function(mode, buf) return vim.api.nvim_buf_get_keymap(buf, mode) end, 0),
  commands = {},
  loaded = { mini = ok, gitsigns = gs_ok },
}

-- :commands from user config (grep-documented set)
for _, cmd in ipairs({ 'Lazy', 'Mason', 'Rest', 'GrugFar', 'VenvSelect', 'Octo' }) do
  local ok3, out3 = pcall(vim.api.nvim_get_commands, { output = 'dict' })
  result.commands[cmd] = ok3 and (out3[cmd] ~= nil) or false
end

local f = io.open(os.getenv('HOME') .. '/.cache/nvim/keymaps_dump.json', 'w')
f:write(vim.json.encode(result))
f:close()
print('UNION DUMP OK: g=' .. #result.global.n .. ' b=' .. #result.buffer.n)
