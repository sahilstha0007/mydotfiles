-- Test: nvim actually reaches the palette file it is supposed to read.
--
-- WHY THIS FILE EXISTS
--
-- read_wezterm_palette() loads ~/.config/wezterm/colors/custom.lua and evals
-- it. That file opens with `local wezterm = require('wezterm')`, and outside
-- wezterm that require ALWAYS raises — so the function returned false on every
-- call for as long as it existed, and read_terminal_palette() silently fell
-- through to kitty's file instead. At the time wezterm and kitty were themed
-- from DIFFERENT wallpapers (wezterm = the dev-stack cascade, kitty = ml4w's
-- desktop path), so the editor wore one wallpaper's palette while the tmux bar
-- and the chrome around it wore another. Nothing errored. Nothing logged.
--
-- The two terminal profiles maintain clear boundaries:
-- - WezTerm uses the dev stack's custom wallpaper cascade (~/.config/wezterm/colors/custom.lua).
-- - Kitty (daily driver) uses ML4W's palette (~/.config/kitty/colors-matugen.conf).
-- Both profiles resolve their own palette independently, and neither overwrites the other.
--
-- The existing terminal_colors_spec.lua could not catch this: it tests the
-- colour MATHS (contrast, acc, pick_accents) against synthetic palettes and
-- never calls a reader. Correct maths applied to the wrong palette is exactly
-- the bug. So this spec asserts the source-selection half: does the reader
-- succeed, which file answered, and is the host terminal respected.
--
-- Every check below fails against the pre-fix code (verified by reverting the
-- stub: check 1 goes false, checks 2-4 go false with it).
--
-- Run: nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/terminal_palette_source_spec.lua')" -c "qa!"

-- Same runtimepath-derived root as the colour spec, for the same reason: a
-- hardcoded path tests the live tree even when the suite runs against a copy.
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
local HOME = vim.env.HOME or ''
local WEZ_CUSTOM = HOME .. '/.config/wezterm/colors/custom.lua'
local KITTY_NIGHTFOX = HOME .. '/.config/kitty/themes/nightfox.conf'
local KITTY_CONF = (vim.uv or vim.loop).fs_stat(KITTY_NIGHTFOX) and KITTY_NIGHTFOX
  or (HOME .. '/.config/kitty/colors-matugen.conf')

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
-- Extract the REAL source-selection region: `palette_file` through the end of
-- read_terminal_palette(), stopping just before poll_palette_file(). Anchored
-- by content, not line numbers, so `make fmt` cannot break it.
-- ---------------------------------------------------------------------------
local f = assert(io.open(SRC, 'r'))
local body = f:read '*a'
f:close()
local lines = vim.split(body, '\n', { plain = true })

local start, stop = nil, nil
for i, l in ipairs(lines) do
  if not start and l:match '^local palette_file = nil' then
    start = i
  end
  if start and not stop and l:match '^local function poll_palette_file' then
    stop = i - 1
    break
  end
end
assert(start, 'could not find the palette_file declaration in ' .. SRC)
assert(stop, 'could not find poll_palette_file to bound the region')

local CHUNK = table.concat({
  'local pal = _TEST_PAL',
  'local palette_file = nil',
  table.concat(vim.list_slice(lines, start + 1, stop), '\n'),
  [[
return {
  read_kitty_palette = read_kitty_palette,
  read_wezterm_palette = read_wezterm_palette,
  read_terminal_palette = read_terminal_palette,
  pal = function() return pal end,
  palette_file = function() return palette_file end,
}]],
}, '\n')

-- Each compiled instance needs its own `pal`; LuaJIT's loadstring ignores an
-- env argument, so bind _TEST_PAL in the function's own environment — the same
-- technique terminal_colors_spec.lua uses.
local function build()
  local env = setmetatable({
    _TEST_PAL = { ansi = {}, fg = nil, bg = nil },
  }, { __index = _G })
  local fn = assert(loadstring(CHUNK))
  setfenv(fn, env)
  return fn(), env._TEST_PAL
end

local function hex6(v)
  return type(v) == 'string' and v:match '^#%x%x%x%x%x%x$' ~= nil
end

-- ---------------------------------------------------------------------------
-- CHECK 1: the wezterm reader SUCCEEDS. This is the bug.
-- ---------------------------------------------------------------------------
local M, pal = build()
do
  local ok = M.read_wezterm_palette()
  check(
    ok == true,
    'read_wezterm_palette() resolves custom.lua instead of failing the require',
    'returned ' .. tostring(ok)
  )

  local missing = {}
  for i = 0, 15 do
    if not hex6(pal.ansi[i]) then
      missing[#missing + 1] = i
    end
  end
  check(
    #missing == 0,
    'all 16 ANSI slots were populated from wezterm',
    'missing: ' .. table.concat(missing, ',')
  )
  check(hex6(pal.fg), 'foreground came through', tostring(pal.fg))
  check(hex6(pal.bg), 'background came through', tostring(pal.bg))

  -- ---------------------------------------------------------------------
  -- CHECK 2: the file that answered is the cascade's, so the live watcher is
  -- pointed at the directory the cascade actually writes.
  -- ---------------------------------------------------------------------
  check(
    M.palette_file() == WEZ_CUSTOM,
    'the wezterm palette file is the one recorded for the fs watcher',
    tostring(M.palette_file())
  )

  -- ---------------------------------------------------------------------
  -- CHECK 3: the `wezterm` stub is removed again. A leaked preload entry makes
  -- every later require('wezterm') inside nvim return a table instead of
  -- raising, which would hide this class of bug for good.
  -- ---------------------------------------------------------------------
  check(
    package.preload['wezterm'] == nil,
    'the wezterm preload stub is restored (not left in package.preload)',
    tostring(package.preload['wezterm'])
  )
end

-- ---------------------------------------------------------------------------
-- CHECK 4: kitty's reader SUCCEEDS on its ML4W-managed config.
-- Kitty is the daily driver and reads ~/.config/kitty/colors-matugen.conf,
-- maintaining clear boundaries from WezTerm's wallpaper cascade.
-- ---------------------------------------------------------------------------
do
  local fk = io.open(KITTY_CONF, 'r')
  if not fk then
    print 'SKIP: kitty palette file absent; kitty reader check not run'
  else
    fk:close()
    local Mk, kpal = build()
    local ok = Mk.read_kitty_palette()
    check(
      ok == true,
      'read_kitty_palette() parses colors-matugen.conf successfully',
      'returned ' .. tostring(ok)
    )

    local missing = {}
    for i = 0, 15 do
      if not hex6(kpal.ansi[i]) then
        missing[#missing + 1] = i
      end
    end
    check(
      #missing == 0,
      'all 16 ANSI slots were populated from kitty config',
      'missing: ' .. table.concat(missing, ',')
    )
    check(hex6(kpal.fg), 'kitty foreground came through', tostring(kpal.fg))
    check(hex6(kpal.bg), 'kitty background came through', tostring(kpal.bg))
    check(
      Mk.palette_file() == KITTY_CONF,
      'kitty palette file is recorded for the fs watcher',
      tostring(Mk.palette_file())
    )
  end
end

-- ---------------------------------------------------------------------------
-- CHECK 5: explicit terminal profile selects the palette policy even inside tmux.
-- WezTerm reads the WezTerm custom cascade, while Kitty reads its own ML4W kitty config.
-- Only an unknown terminal stays on the stock palette. Every env var touched is restored.
-- ---------------------------------------------------------------------------
do
  local KEYS = {
    'TERMINAL_STACK_PROFILE',
    'WEZTERM_PANE',
    'WEZTERM_EXECUTABLE',
    'TERM_PROGRAM',
    'KITTY_WINDOW_ID',
    'TERM',
  }
  local saved = {}
  for _, k in ipairs(KEYS) do
    saved[k] = vim.env[k]
  end
  local function set_env(t)
    for _, k in ipairs(KEYS) do
      vim.env[k] = t[k] or nil
    end
  end
  local function restore()
    for _, k in ipairs(KEYS) do
      vim.env[k] = saved[k]
    end
  end

  local wez_existed = io.open(WEZ_CUSTOM, 'r')
  if wez_existed then
    wez_existed:close()
  end
  local kitty_existed = io.open(KITTY_CONF, 'r')
  if kitty_existed then
    kitty_existed:close()
  end

  if wez_existed ~= nil and kitty_existed ~= nil then
    set_env {
      TERMINAL_STACK_PROFILE = 'kitty',
      KITTY_WINDOW_ID = '1',
      TERM = 'xterm-kitty',
    }
    local mk = build()
    check(
      mk.read_terminal_palette() == true and mk.palette_file() == KITTY_CONF,
      'kitty profile reads its own ML4W palette file, even inside tmux',
      tostring(mk.palette_file())
    )

    set_env { TERMINAL_STACK_PROFILE = 'wezterm', TERM = 'tmux-256color' }
    local mw = build()
    check(
      mw.read_terminal_palette() == true and mw.palette_file() == WEZ_CUSTOM,
      'wezterm profile reads only the wallpaper cascade, even inside tmux',
      tostring(mw.palette_file())
    )

    set_env { KITTY_WINDOW_ID = '1', TERM = 'xterm-kitty' }
    local legacy_kitty = build()
    check(
      legacy_kitty.read_terminal_palette() == true
        and legacy_kitty.palette_file() == KITTY_CONF,
      'kitty marker fallback reads kitty palette file',
      tostring(legacy_kitty.palette_file())
    )

    set_env { WEZTERM_PANE = '1', TERM = 'xterm-256color' }
    local legacy_wez = build()
    check(
      legacy_wez.read_terminal_palette() == true
        and legacy_wez.palette_file() == WEZ_CUSTOM,
      'wezterm marker fallback reads the cascade file',
      tostring(legacy_wez.palette_file())
    )

    set_env {}
    local no_host = build()
    check(
      no_host.read_terminal_palette() == false and no_host.palette_file() == nil,
      'an unknown terminal does not guess a wallpaper source',
      tostring(no_host.palette_file())
    )
  end

  restore()
end

-- ---------------------------------------------------------------------------

print(
  string.format(
    'terminal_palette_source_spec: %d pass, %d fail',
    passed,
    failed
  )
)
if failed > 0 then
  vim.cmd 'cq'
end
