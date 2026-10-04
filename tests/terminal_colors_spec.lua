-- Task 3 test: the nvim readability gate is a real WCAG contrast ratio.
--
-- The point of this spec is that it loads the REAL functions out of
-- lua/plugins/ui/terminal-colors.lua by line range and evals them, rather
-- than re-typing a copy. A re-typed copy is a test of the copy: the four
-- places that are supposed to stay in sync (wezterm colors/custom.lua, tmux
-- colors-from-matugen.sh, nvim terminal-colors.lua) would drift and the spec
-- would still go green, which is exactly the failure mode this file exists
-- to catch.
--
-- What is asserted:
--   1. contrast() matches the WCAG reference values to 2dp (hand-computed,
--      and cross-checked against the published algorithm).
--   2. contrast() is SYMMETRIC — a dark token on a light bg and a light token
--      on a dark bg are the same question, and the gate must handle both.
--   3. The old brightness approximation really did pass colours that fail
--      4.5:1. If this ever goes false the gate is no longer load-bearing and
--      the whole change was theatre.
--   4. acc() rejects the tokens the old gate accepted, and keeps the ones
--      that are genuinely fine.
--   5. MIN_CONTRAST is 4.5 and the same constant appears in the other two
--      consumers, so "keep the three in sync" is enforced, not just written
--      in a comment.
--
-- Run: nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/terminal_colors_spec.lua')" -c "qa!"

-- Resolve the config root from the runtimepath rather than hardcoding it.
-- Hardcoding made this spec test the LIVE file even when run against a copy,
-- so every mutation of a copy passed green — the spec looked thorough and
-- proved nothing. minimal_init.lua prepends this path, so take it from there.
--
-- This lookup is the SECOND half of that fix. The first half was this file:
-- making the source path dynamic is pointless if the runtimepath still points
-- at the live tree, so both were hardcoded and both had to move.
--
-- ipairs, not a generic for: nvim 0.12 returns this list with a __pairs that
-- is not callable, so `for p in list` dies with "attempt to call a table
-- value" before the loop body ever runs. ipairs does not consult __pairs.
local function config_root()
  for _, p in ipairs(vim.api.nvim_list_runtime_paths()) do
    local st = vim.uv.fs_stat(p .. '/lua/plugins/ui/terminal-colors.lua')
    if st and st.type == 'file' then
      return p
    end
  end
  error 'could not locate the nvim config root on the runtimepath'
end

local ROOT = config_root()
local SRC = ROOT .. '/lua/plugins/ui/terminal-colors.lua'

local passed, failed = 0, 0
local function check(cond, msg, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    print('FAIL: ' .. msg .. (detail and ('  <- ' .. tostring(detail)) or ''))
  end
end

-- ---------------------------------------------------------------------------
-- Load the real source. Ranges are asserted below so an edit that moves them
-- fails loudly instead of silently evaluating the wrong lines.
-- ---------------------------------------------------------------------------
local f = assert(io.open(SRC, 'r'))
local body = f:read '*a'
f:close()
-- Split on newlines KEEPING empty lines: gmatch('[^\n]+') would silently drop
-- them and every line number below would drift.
local lines = vim.split(body, '\n', { plain = true })

local function slice(from, to)
  return table.concat(vim.list_slice(lines, from, to), '\n')
end

-- Locate each region by CONTENT, not by hardcoded line number. This used to
-- pin exact lines (116/141/170/191/227), so `make fmt` shifted them and the
-- spec went red for a reason that had nothing to do with the colour maths it
-- exists to test. Anchoring on the definitions themselves means reformatting
-- can never break it, while a renamed or deleted function still fails loudly
-- -- which is the only failure the line anchors were ever trying to catch.
local function block(start_pat, end_pat)
  local first
  for i, l in ipairs(lines) do
    if l:match(start_pat) then
      first = i
      break
    end
  end
  assert(first, 'no line matches start pattern: ' .. start_pat)
  for j = first, #lines do
    if lines[j]:match(end_pat) then
      return first, j
    end
  end
  error('no line after ' .. first .. ' matches end pattern: ' .. end_pat)
end

-- Section 1: MIN_CONTRAST through acc(), ending just before hue()'s doc comment.
local a1, b1 =
  block('^local MIN_CONTRAST = ', "^%-%- Hue %(0%.%.360%) of a '#rrggbb'")
-- Section 2: hue() and MIN_HUE_SEP, up to just before pick_accents().
local a2, b2 = block('^local function hue%(', '^local function pick_accents%(')
b2 = b2 - 1 -- pick_accents' own doc comment belongs to section 3
-- Section 3: pick_accents() through its closing `end`.
local a3, b3 = block('^local function pick_accents%(%)$', '^end$')

check(
  lines[a1] == 'local MIN_CONTRAST = 4.5 -- WCAG AA for normal text',
  'MIN_CONTRAST block found',
  lines[a1]
)
check(
  lines[a3] == 'local function pick_accents()',
  'pick_accents block found',
  lines[a3]
)
check(
  b1 < a2,
  ('sections do not overlap (acc ends %d, hue starts %d)'):format(b1, a2),
  ('b1=%d a2=%d'):format(b1, a2)
)
check(
  b2 < a3,
  ('sections do not overlap (hue ends %d, pick_accents starts %d)'):format(
    b2,
    a3
  ),
  ('b2=%d a3=%d'):format(b2, a3)
)

-- acc() needs `pal`; build a minimal one so the function is self-contained.
-- No forward declarations: each sliced `local function` declares its own local,
-- and a forward `local contrast` at the top would just create a separate nil
-- local that the `return` then reads instead of the real function.
local CHUNK = table.concat({
  'local pal = _TEST_PAL',
  slice(a1, b1), -- MIN_CONTRAST, channel, rel_lum, contrast, saturation, acc
  slice(a2, b2), -- hue, hue_dist, MIN_HUE_SEP (needed by pick_accents)
  slice(a3, b3), -- pick_accents
  'return { MIN_CONTRAST = MIN_CONTRAST, rel_lum = rel_lum, contrast = contrast, saturation = saturation, acc = acc, pick_accents = pick_accents }',
}, '\n')

-- ---------------------------------------------------------------------------
-- CHECK 1: contrast() matches WCAG reference values
-- ---------------------------------------------------------------------------
-- Reference values from the WCAG 2.1 relative-luminance definition, computed
-- with the published coefficients and the 0.04045 / 12.92 / 1.055 / 2.4 curve.
local function ref_contrast(a, b)
  local function lin(c)
    c = c / 255
    if c <= 0.04045 then
      return c / 12.92
    end
    return ((c + 0.055) / 1.055) ^ 2.4
  end
  local function rl(h)
    return 0.2126 * lin(tonumber(h:sub(2, 3), 16))
      + 0.7152 * lin(tonumber(h:sub(4, 5), 16))
      + 0.0722 * lin(tonumber(h:sub(6, 7), 16))
  end
  local la, lb = rl(a), rl(b)
  local hi, lo = la > lb and la or lb, la < lb and la or lb
  return (hi + 0.05) / (lo + 0.05)
end

-- Known-good pairs with their published ratios:
--   #ffffff / #000000  -> 21.0   (the maximum the formula can produce)
--   #777777 / #ffffff  ->  4.478 (fails 4.5 — the classic AA boundary case)
--   #767676 / #ffffff  ->  4.542 (the lightest grey that passes AA)
local known = {
  { '#ffffff', '#000000', 21.0 },
  { '#000000', '#ffffff', 21.0 },
  { '#ffffff', '#ffffff', 1.0 },
  { '#777777', '#ffffff', 4.478 },
  { '#767676', '#ffffff', 4.542 },
}

_G._TEST_PAL = { ansi = {}, fg = nil, bg = nil }
local fn0, err0 = loadstring(CHUNK)
if type(fn0) ~= 'function' then
  check(
    false,
    'the extracted source compiles',
    'loadstring returned ' .. type(fn0) .. ': ' .. tostring(err0)
  )
  os.exit(1)
end
check(true, 'the extracted source compiles')
local mod = fn0
do
  local T = mod()
  _G._TEST_PAL = nil

  for _, k in ipairs(known) do
    local got = T.contrast(k[1], k[2])
    local want = ref_contrast(k[1], k[2])
    check(
      math.abs(got - want) < 0.01,
      string.format('contrast(%s, %s) = %.3f', k[1], k[2], got),
      string.format(
        'got %.4f, WCAG says %.4f, documented %.3f',
        got,
        want,
        k[3]
      )
    )
  end

  -- The three tokens from the live wallpaper palette, cross-checked against
  -- the ratios quoted in the wezterm audit.
  for _, hex in ipairs { '#ffb4ab', '#e1c38c', '#ffb3ac', '#904a45' } do
    local got = T.contrast(hex, '#1a1110')
    local want = ref_contrast(hex, '#1a1110')
    check(
      math.abs(got - want) < 0.01,
      string.format('contrast(%s, #1a1110) = %.2f', hex, got),
      string.format('got %.4f, WCAG says %.4f', got, want)
    )
  end

  -- -------------------------------------------------------------------------
  -- CHECK 2: symmetry — the gate must work in both directions
  -- -------------------------------------------------------------------------
  check(
    math.abs(
      T.contrast('#ffb3ac', '#1a1110') - T.contrast('#1a1110', '#ffb3ac')
    ) < 1e-9,
    'contrast is symmetric on a light token / dark bg'
  )
  check(
    math.abs(
      T.contrast('#1e66f5', '#eff1f5') - T.contrast('#eff1f5', '#1e66f5')
    ) < 1e-9,
    'contrast is symmetric on a dark token / light bg (the latte case)'
  )
  check(
    T.contrast('#1e66f5', '#eff1f5') > 1.0,
    'a dark token on a light bg is measurable, not clamped to zero'
  )

  -- -------------------------------------------------------------------------
  -- CHECK 3: the old gate really did pass what the new one rejects
  -- -------------------------------------------------------------------------
  -- The old rule was `luminance(hex) >= 0.40` on a dark bg, where luminance
  -- is (0.299r + 0.587g + 0.114b)/255. These are the greys that satisfied it
  -- and still fail 4.5:1 — the concrete reason the gate was replaced.
  local function old_lum(hex)
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255
  end
  local disputed = { '#6e6e6e', '#6e6e6a', '#787878', '#737373' }
  local old_passed_new_fails = 0
  for _, hex in ipairs(disputed) do
    if old_lum(hex) >= 0.40 and T.contrast(hex, '#1a1110') < T.MIN_CONTRAST then
      old_passed_new_fails = old_passed_new_fails + 1
    end
  end
  check(
    old_passed_new_fails >= 3,
    'the old brightness cut accepted greys that fail WCAG AA',
    old_passed_new_fails .. ' of ' .. #disputed .. ' disputed greys'
  )
  check(
    T.contrast('#6e6e6a', '#1a1110') < 4.5
      and T.contrast('#787878', '#1a1110') < 4.5,
    'the two greys quoted in the code comments are both under 4.5:1',
    string.format(
      '#6e6e6a=%.2f #787878=%.2f',
      T.contrast('#6e6e6a', '#1a1110'),
      T.contrast('#787878', '#1a1110')
    )
  )

  -- -------------------------------------------------------------------------
  -- CHECK 4: MIN_CONTRAST is the AA constant
  -- -------------------------------------------------------------------------
  check(T.MIN_CONTRAST == 4.5, 'MIN_CONTRAST is 4.5', tostring(T.MIN_CONTRAST))

  -- -------------------------------------------------------------------------
  -- CHECK 5: acc() applies the gate — re-eval with a controlled palette
  -- -------------------------------------------------------------------------
  -- acc() reads the module-local `pal`, so the extraction is re-run with a
  -- palette we choose. This is the part that matters: contrast() being
  -- correct is worthless if acc() never calls it.
  -- acc() reads a module-local `pal`, so each controlled palette needs its
  -- own compiled instance. LuaJIT's loadstring ignores an env argument, so
  -- bind _TEST_PAL in the function's own environment instead.
  local function eval_with(pal)
    local env = setmetatable({ _TEST_PAL = pal }, { __index = _G })
    local fn = assert(loadstring(CHUNK))
    setfenv(fn, env)
    return fn()
  end

  -- (a) the live wallpaper's dark-olive success token: 2.87:1, must be refused
  local pal_bad = { ansi = {}, bg = '#1a1110', fg = '#f1dedc' }
  pal_bad.ansi[2] = '#904a45' -- base green  — unreadable
  pal_bad.ansi[10] = '#904a45' -- bright green — also unreadable
  pal_bad.ansi[4] = '#ffb3ac' -- base blue   — readable
  pal_bad.ansi[12] = '#ffb3ac' -- bright blue
  local T_bad = eval_with(pal_bad)
  check(
    T_bad.acc(2, 10) == nil,
    'acc() refuses the 2.87:1 olive success token',
    tostring(T_bad.acc(2, 10))
  )
  check(
    T_bad.acc(4, 12) == '#ffb3ac',
    'acc() still adopts the readable blue',
    tostring(T_bad.acc(4, 12))
  )

  -- (b) a grey slot must be refused on saturation, not on contrast
  local pal_grey = { ansi = {}, bg = '#1a1110', fg = '#f1dedc' }
  pal_grey.ansi[2] = '#e0e2e8' -- ml4w's grey "green"
  pal_grey.ansi[10] = '#e0e2e8'
  local T_grey = eval_with(pal_grey)
  check(
    T_grey.acc(2, 10) == nil,
    'acc() refuses a high-contrast GREY slot (saturation gate still works)',
    tostring(T_grey.acc(2, 10))
  )

  -- (c) with no background known yet, contrast cannot be judged — acc() must
  --     not refuse everything and blank the whole theme on the first paint
  local pal_nobg = { ansi = {}, bg = nil, fg = nil }
  pal_nobg.ansi[2] = '#904a45'
  pal_nobg.ansi[10] = '#a6e3a1'
  local T_nobg = eval_with(pal_nobg)
  check(
    T_nobg.acc(2, 10) == '#a6e3a1',
    'acc() adopts the bright variant when no background is known',
    tostring(T_nobg.acc(2, 10))
  )

  -- (d) a missing slot must not crash
  local pal_sparse = { ansi = {}, bg = '#1a1110' }
  local T_sparse = eval_with(pal_sparse)
  local ok_sparse = pcall(T_sparse.acc, 7, 15)
  check(ok_sparse, 'acc() survives an entirely empty palette slot')
  check(
    T_sparse.acc(7, 15) == nil,
    'acc() returns nil for an empty slot',
    tostring(T_sparse.acc(7, 15))
  )

  -- (e) pick_accents must still produce a spread, not collapse to one colour
  local pal_mono = { ansi = {}, bg = '#1a1110', fg = '#f1dedc' }
  for i = 0, 15 do
    pal_mono.ansi[i] = '#ffb3ac' -- monochromatic wallpaper
  end
  local T_mono = eval_with(pal_mono)
  local ok_mono, accents = pcall(T_mono.pick_accents)
  check(ok_mono, 'pick_accents() runs on a monochromatic palette', accents)
  if ok_mono and type(accents) == 'table' then
    local n = 0
    for _ in pairs(accents) do
      n = n + 1
    end
    check(
      n < 3,
      'a monochromatic palette yields few distinct accents (derivation fills the rest)',
      n .. ' accents adopted'
    )
    check(
      accents.blue ~= nil,
      'the primary is always adopted for the blue slot',
      tostring(accents.blue)
    )
  end
end

-- ---------------------------------------------------------------------------
-- CHECK 6: the constant is in sync across all three consumers
-- ---------------------------------------------------------------------------
-- "Keep the three in sync" is a comment in three files. This makes it a test.
-- If someone changes one MIN_CONTRAST and not the others, this goes red.
do
  local function has_const(path, pattern)
    local fh = io.open(path, 'r')
    if not fh then
      return false, 'cannot read ' .. path
    end
    local body = fh:read '*a'
    fh:close()
    return body:match(pattern) ~= nil
  end

  check(
    has_const(
      (vim.env.HOME or '') .. '/.config/wezterm/colors/custom.lua',
      'local MIN_CONTRAST = 4%.5'
    ),
    'wezterm colors/custom.lua uses the same MIN_CONTRAST'
  )
  check(
    has_const(
      (vim.env.HOME or '') .. '/.config/tmux/colors-from-matugen.sh',
      'MIN_CONTRAST=4%.5'
    ),
    'tmux colors-from-matugen.sh uses the same MIN_CONTRAST'
  )
  check(
    has_const(SRC, 'local MIN_CONTRAST = 4%.5'),
    'nvim terminal-colors.lua uses the same MIN_CONTRAST'
  )
end

print(string.format('terminal_colors_spec: %d pass, %d fail', passed, failed))
if failed > 0 then
  vim.cmd 'cq'
end
