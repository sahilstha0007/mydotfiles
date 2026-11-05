-- <leader>bd and <leader>bD must do DIFFERENT things.
--
-- The bug: `bD` was `<cmd>bd<CR>`, and `:bd` is an abbreviation of `:bdelete` --
-- so `<leader>bD` was the same command as `<leader>bd`, under a second name,
-- while its description claimed "Delete Buffer and Window". Reading one binding
-- cannot show this: both are syntactically valid. Only comparing the two against
-- each other reveals a key that exists twice under two names, one of which lies
-- about what it does.
--
-- The smaller sibling of git_keymap_conflicts_spec.lua: that one counts owners
-- per key in the <leader>g group, this one asserts the two buffer-delete keys
-- are not secretly the same binding.
--
-- Scope: these two keys only. A whole-tree duplicate-action detector is
-- deliberately not attempted -- it goes red on the harmless nvim-dap /
-- nvim-dap-ui pairs (`<leader>du`, `de`) and an allowlist of known-fine
-- duplicates is exactly the kind of thing that rots.
--
-- Run: nvim --headless -u tests/minimal_init.lua -l tests/buffer_delete_spec.lua

local _src = debug.getinfo(1, 'S').source:sub(2)
local _cand = vim.fn.fnamemodify(_src, ':p:h:h')
local root = vim.env.NVIM_CONFIG_ROOT or (vim.fn.isdirectory(_cand .. '/lua') == 1 and _cand or (vim.fn.fnamemodify(_cand, ':h') .. '/.config/nvim'))
local KEYMAPS = root .. '/lua/keymaps.lua'

--- The text of one `<leader>KEY` binding, from its keymap.set( up to the line
--- that closes the call. Stylua wraps these across lines, so matching a single
--- line is not enough and matching the whole file is not either.
local function binding(KEY)
  local lines = vim.fn.readfile(KEYMAPS)
  for i, line in ipairs(lines) do
    if line:find("'<leader>" .. KEY .. "'", 1, true) then
      local block = {}
      for j = i, math.min(i + 10, #lines) do
        block[#block + 1] = lines[j]
        if j > i and lines[j]:match '^%)' then
          break
        end
      end
      return table.concat(block, '\n')
    end
  end
  return nil
end

local failures = {}

local bd, bD = binding 'bd', binding 'bD'

-- 1. Both must exist and route through snacks.bufdelete. This is the change
--    under test: before it, both were raw :bdelete.
for _, pair in ipairs { { 'bd', bd }, { 'bD', bD } } do
  local key, text = pair[1], pair[2]
  if not text then
    failures[#failures + 1] = ('<leader>%s not found in keymaps.lua'):format(
      key
    )
  elseif not text:find 'Snacks%.bufdelete' then
    failures[#failures + 1] = ('<leader>%s does not call Snacks.bufdelete'):format(
      key
    )
  end
end

-- 2. The two must not resolve to the same action. bD is the wipe variant; if it
--    is "simplified" back to delete(), it becomes a duplicate of bd and the
--    second name starts lying again.
if bd and bD then
  local bd_wipes = bd:find 'wipe%s*=%s*true' ~= nil
  local bD_wipes = bD:find 'wipe%s*=%s*true' ~= nil
  if bd_wipes == bD_wipes then
    failures[#failures + 1] = (
      '<leader>bd and <leader>bD resolve to the same action (wipe=%s both). '
      .. 'They must differ: bd deletes, bD wipes.'
    ):format(tostring(bD_wipes))
  end
end

-- 3. Neither description may promise a window close. Verified against the real
--    plugin: both snacks paths preserve the layout (2 windows -> 2), so
--    "Delete Buffer and Window" is simply false.
for _, pair in ipairs { { 'bd', bd }, { 'bD', bD } } do
  if pair[2] and pair[2]:find('and Window', 1, true) then
    failures[#failures + 1] = (
      "<leader>%s description claims 'and Window', but neither snacks variant "
      .. 'closes a window -- measured 2 windows -> 2 on both'
    ):format(pair[1])
  end
end

if #failures > 0 then
  error(
    ('buffer_delete_spec: %d failure(s)\n  - %s'):format(
      #failures,
      table.concat(failures, '\n  - ')
    )
  )
end

print 'ok    tests/buffer_delete_spec.lua'
