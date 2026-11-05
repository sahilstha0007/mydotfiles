-- One action per key in the <leader>g (git) group.
--
-- The bug: `<leader>gB` was bound twice with different actions.
--
--   lua/plugins/editor/snacks.lua:74   global, priority 1000 -> Snacks.gitbrowse()
--   lua/plugins/editor/gitsigns.lua:103 buffer-local, from on_attach -> blame_line{full=true}
--
-- gitsigns' on_attach runs on every real buffer, so its buffer-local map beat
-- the global one in practice and `Snacks.gitbrowse()` was unreachable dead code
-- -- while every doc in the repo (AGENT.md:99, docs/keymaps.md:107) described
-- the key as the blame popup. Reading two files cannot see that: both bindings
-- are syntactically valid, and only map scope + attach order decides which one a
-- user actually gets. Hence a spec that counts owners per key.
--
-- Scope: the <leader>g group only. A whole-tree duplicate detector is not what
-- this is -- it goes red on the two harmless nvim-dap / nvim-dap-ui pairs
-- (`<leader>du`, `<leader>de`: same action declared on both the provider spec
-- and the UI spec), and an allowlist of "known fine duplicates" is exactly the
-- kind of thing that rots. The git group is where the audit found the collision
-- and docs/keymaps.md documents it key by key.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/git_keymap_conflicts_spec.lua

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')
local GIT_SOURCES = { root .. '/lua/plugins/editor/gitsigns.lua' }

-- buffer-local maps come back with <leader> already expanded to whatever
-- mapleader is, so it has to match the config (init.lua sets ' ') or every
-- lookup misses.
local CONFIG_LEADER = ' '
vim.g.mapleader = CONFIG_LEADER
vim.g.maplocalleader = CONFIG_LEADER

local failed = 0
local function check(ok, msg)
  if ok then
    print('  ok   ' .. msg)
  else
    failed = failed + 1
    print('FAIL: ' .. msg)
  end
end

local function modes_of(mode)
  if mode == nil then
    return { 'n' }
  end
  if type(mode) == 'string' then
    return { mode }
  end
  return mode
end

-- [key] = { [mode] = { "site", ... } }
local owners = {}
local function claim(key, mode, site)
  owners[key] = owners[key] or {}
  owners[key][mode] = owners[key][mode] or {}
  if not vim.tbl_contains(owners[key][mode], site) then
    table.insert(owners[key][mode], site)
  end
end

-- --- source 1: lazy `keys` tables in every spec under lua/ --------------------
-- Two specs (terminal-colors.lua, phpstan.lua) require catppuccin / lint at
-- load time and throw here. Skipping them silently would leave a hole, so each
-- unloadable file is checked afterwards for a <leader>g binding it might hide.
local unloaded = {}
for _, f in ipairs(vim.fn.glob(root .. '/lua/**/*.lua', false, true)) do
  if not vim.tbl_contains(GIT_SOURCES, f) then
    local rel = f:gsub('^' .. vim.pesc(root) .. '/', '')
    local ok, specs = pcall(dofile, f)
    if not ok then
      unloaded[#unloaded + 1] = rel
    else
      local function walk(t)
        if type(t) ~= 'table' then
          return
        end
        for k, v in pairs(t) do
          -- `group =` is which-key documentation for a PREFIX, not a binding on
          -- it. Without that exclusion which-key's own '<leader>g' row looks
          -- like a second owner of every key in the group.
          if k == 'keys' and type(v) == 'table' then
            for i, e in ipairs(v) do
              if
                type(e) == 'table'
                and type(e[1]) == 'string'
                and e.group == nil
              then
                local key = e[1]:match '^<leader>(g.+)$'
                if key then
                  for _, mode in ipairs(modes_of(e.mode)) do
                    claim(key, mode, ('%s:%d'):format(rel, i))
                  end
                end
              end
            end
          end
          if type(v) == 'table' then
            walk(v)
          end
        end
      end
      walk(specs)
    end
  end
end

-- Nothing is hiding in a file that would not load.
for _, rel in ipairs(unloaded) do
  local text = table.concat(vim.fn.readfile(root .. '/' .. rel), '\n')
  check(
    not text:match '<leader>gs?[A-Z]',
    ('%s could not be loaded, so its <leader>g bindings went unchecked'):format(
      rel
    )
  )
end

-- --- source 2: gitsigns' on_attach buffer maps -------------------------------
-- Invisible to the walk above: they live in a function body, not a `keys` table.
-- Stub the two modules gitsigns' opts touches, run the real opts, and read back
-- what actually landed on a scratch buffer. Same contract the ui_owner_spec uses
-- -- load the real spec file, not a reimplementation of it.
do
  package.loaded['gitsigns'] = setmetatable({}, {
    __index = function()
      return function() end
    end,
  })
  -- gitsigns_hl() runs inside opts and feeds these straight to nvim_set_hl, so
  -- they have to be real #rrggbb values, not placeholders.
  package.loaded['utils.theme'] = {
    palette = function()
      return { green = '#a6e3a1', yellow = '#f9e2af', red = '#f38ba8' }
    end,
  }
  local spec = dofile(GIT_SOURCES[1])
  local opts = {}
  spec[1].opts(nil, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  opts.on_attach(buf)
  local n = 0
  for _, mode in ipairs { 'n', 'v' } do
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, mode)) do
      local key = m.lhs:match('^' .. vim.pesc(CONFIG_LEADER) .. '(g.+)$')
      if key then
        claim(key, mode, 'gitsigns.lua (on_attach, buffer-local)')
        n = n + 1
      end
    end
  end
  vim.api.nvim_buf_delete(buf, { force = true })
  check(
    n >= 10,
    ('premise: gitsigns on_attach registered its buffer maps (%d)'):format(n)
  )
end

-- --- the premise, then the assertion ----------------------------------------
-- If source 1 ever stops finding the git bindings, every check below passes
-- vacuously. 15 is the count docs/keymaps.md's Git section documents.
local distinct = 0
for _ in pairs(owners) do
  distinct = distinct + 1
end
check(
  distinct >= 15,
  ('premise: scanner found the git bindings (%d distinct keys)'):format(
    distinct
  )
)

for key, by_mode in pairs(owners) do
  for mode, sites in pairs(by_mode) do
    if #sites == 1 then
      check(true, ('<leader>%s [%s] -> %s'):format(key, mode, sites[1]))
    else
      check(
        false,
        ('<leader>%s [%s] has %d owners, so at least one is unreachable: %s'):format(
          key,
          mode,
          #sites,
          table.concat(sites, ' | ')
        )
      )
    end
  end
end

if failed > 0 then
  error(string.format('git-keymap-conflicts: %d assertion(s) failed', failed))
end
print 'git-keymap-conflicts: ok'
