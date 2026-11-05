-- Test: the wallpaper palette must load even when the environment lies.
--
-- colors/custom.lua used to read the matugen palette with
--     pcall(dofile, os.getenv('HOME') .. '/.config/wezterm/colors/matugen.lua')
-- and `ok and matugen.background` was the ONLY gate on the whole theme system.
-- Under a systemd unit, a flatpak, or any launcher that scrubs the environment,
-- os.getenv('HOME') is nil, the concat raises, the pcall swallows it, and the
-- config dies with a bare "attempt to concatenate a nil value". Verified
-- against this wezterm build:
--
--     $ env -u HOME wezterm --config-file ~/.config/wezterm/wezterm.lua start
--     Configuration Error: .../colors/custom.lua:182: attempt to concatenate
--     a nil value
--
-- So the bug was not a silent fallback at all -- it was a total config
-- failure. Either way the path is wrong: it is read from the environment when
-- wezterm already knows where the config lives.
--
-- The palette sits BESIDE the config file, so it must be resolved from
-- wezterm.config_dir, which also keeps a checkout working from any path.
--
-- Run: luajit tests/check_theme_source.lua <config-root>

local root = assert(arg[1], 'usage: check_theme_source.lua <config-root>')

local pass, fail = 0, 0
local function check(name, ok, detail)
   if ok then
      pass = pass + 1
      print('  PASS  ' .. name)
   else
      fail = fail + 1
      print('  FAIL  ' .. name .. (detail and ('  <- ' .. tostring(detail)) or ''))
   end
end

package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- Serve a DECOY palette from a config_dir that is not home_dir.
--
-- Two roots on purpose. If home_dir held the palette too, a fix that rebuilt
-- the path from wezterm.home_dir would pass every scenario below for the
-- wrong reason, and would break the moment anyone runs a config that is not at
-- ~/.config/wezterm. The decoy palette carries a background no catppuccin base
-- uses, so "which directory answered" is answerable from the result alone.
--
--   #123456 / #654321 are not mocha, not latte, and not this wallpaper.
local DECOY = {
   foreground = '#e0e0e0',
   background = '#123456',
   primary = '#abcdef',
   secondary = '#fedcba',
   tertiary = '#fedcba',
   success = '#0a5a0a',
   error = '#ff0000',
   surface0 = '#654321',
   surface1 = '#654322',
   surface2 = '#654323',
   outline = '#654324',
}

-- os.tmpname() is no use here: LuaJIT's creates a plain FILE, so mkdir -p
-- under it fails and the decoy palette below lands nowhere.
math.randomseed(os.time())
local decoy_dir = ('/tmp/wezterm-theme-decoy-%d-%d'):format(os.time(), math.random(1e6))
assert(os.execute('mkdir -p ' .. decoy_dir .. '/colors'))
local decoy_palette = assert(io.open(decoy_dir .. '/colors/matugen.lua', 'w'))
decoy_palette:write('return {\n')
for k, v in pairs(DECOY) do
   decoy_palette:write(string.format('   %s = "%s",\n', k, v))
end
decoy_palette:write('}\n')
decoy_palette:close()

-- The stock catppuccin mocha base, hardcoded in colors/custom.lua. If that is
-- what resolved, the pipeline fell back instead of loading the palette.
local MOCHA_BASE = '#1f1f28'

-- custom.lua's only wezterm dependency is the directory it reads the palette
-- from.
_G.wezterm = {
   home_dir = root,
   config_dir = decoy_dir,
   target_triple = 'x86_64-unknown-linux-gnu',
   os = 'Linux',
   log_error = function() end,
   log_warn = function() end,
   log_info = function() end,
   on = function() end,
}
package.loaded['wezterm'] = _G.wezterm

local real_getenv = os.getenv

---Load colors/custom.lua with HOME reporting `value`.
---@return table? colourscheme, or nil plus the load error
local function scheme_with_home(value)
   os.getenv = function(name)
      if name == 'HOME' then
         return value
      end
      return real_getenv(name)
   end
   -- dofile, not require: package.loaded would hand back the first scenario's
   -- module and every later scenario would assert against stale state.
   local ok, res = pcall(dofile, root .. '/colors/custom.lua')
   os.getenv = real_getenv
   if not ok then
      return nil, res
   end
   return res
end

---Background resolved with HOME reporting `home`, or nil if the load failed.
local function bg_with_home(home)
   local cs, err = scheme_with_home(home)
   return cs and cs.background or nil, err
end

-- 1. Self-check: the stub has to actually be able to lie, or every scenario
--    below passes for the wrong reason.
do
   os.getenv = function(name)
      if name == 'HOME' then
         return nil
      end
      return real_getenv(name)
   end
   local probe = os.getenv('HOME')
   os.getenv = real_getenv
   check('the stub can present HOME as nil', probe == nil, 'got ' .. tostring(probe))
end

-- 2. HOME scrubbed entirely (systemd unit / flatpak). This is the case that
--    used to kill the whole config at colors/custom.lua:182.
do
   local bg, err = bg_with_home(nil)
   check(
      'palette loads with HOME unset',
      bg == DECOY.background,
      'background ' .. tostring(bg) .. ' (' .. tostring(err) .. '), expected ' .. DECOY.background
   )
   check(
      'the stock catppuccin fallback is NOT what resolved',
      bg ~= nil and bg ~= MOCHA_BASE,
      'fell back to ' .. tostring(bg)
   )
end

-- 3. HOME set but pointing somewhere with no palette in it (a unit that pins
--    HOME to a service account, a --user systemd instance). Same silent loss,
--    and the reason the guard has to be the config directory rather than any
--    reconstruction of $HOME + a hardcoded suffix.
do
   local bg, err = bg_with_home('/nonexistent-home-for-this-test')
   check(
      'palette loads with HOME pointing at an empty directory',
      bg == DECOY.background,
      'background ' .. tostring(bg) .. ' (' .. tostring(err) .. '), expected ' .. DECOY.background
   )
end

-- 4. A wallpaper-only token must land too, so the check above cannot be
--    satisfied by a background that happens to match. surface0 is adopted
--    un-guarded (no contrast check) and reaches the tab bar.
do
   local cs, err = scheme_with_home(nil)
   check(
      'a wallpaper surface token reaches the chrome',
      cs
         and cs.tab_bar
         and cs.tab_bar.inactive_tab
         and cs.tab_bar.inactive_tab.bg_color == DECOY.surface0,
      tostring(err)
         or tostring(
            cs and cs.tab_bar and cs.tab_bar.inactive_tab and cs.tab_bar.inactive_tab.bg_color
         ) .. ' vs palette surface0 ' .. DECOY.surface0
   )
end

-- 5. The palette comes from config_dir, NOT from home_dir. config_dir holds
--    the decoy; home_dir holds this repo's real palette. Resolving to
--    DECOY.background is what proves the config directory won.
do
   local real = dofile(root .. '/colors/matugen.lua')
   check(
      'home_dir really does hold a different palette (the decoy is meaningful)',
      real.background ~= DECOY.background,
      'both are ' .. tostring(real.background)
   )
   local bg = bg_with_home(nil)
   check(
      'palette resolves against config_dir, not home_dir',
      bg == DECOY.background,
      'resolved ' .. tostring(bg) .. ' -- expected the decoy ' .. DECOY.background
   )
end

-- 6. And the honest control: with the palette genuinely absent, the fallback
--    must still be the stock mocha base. Without this, a "fix" that simply
--    deleted the pcall would pass 1-5 and ship an unthemed window.
do
   local real_dofile = dofile
   _G.dofile = function(path)
      if path:match('matugen%.lua$') then
         error('simulated: no palette on disk')
      end
      return real_dofile(path)
   end
   local cs, err = scheme_with_home(nil)
   _G.dofile = real_dofile
   check('a missing palette still loads colors/custom.lua', cs ~= nil, err)
   check(
      'a missing palette still falls back to stock mocha',
      cs ~= nil and cs.background == MOCHA_BASE,
      cs and ('got ' .. tostring(cs.background)) or err
   )
end

-- 7. Readability of the resolved scheme.
--
-- The guard above proves a wallpaper TOKEN can be trusted. It says nothing
-- about the colours derived from it, and those are what actually carry text:
-- `brights`, the selection pair and the cursor. Three separate bugs lived
-- there, none of which any check would have caught:
--
--   * five of eight `brights` slots were byte-identical to their `ansi`
--     counterpart, so `bold` (wezterm's bold_brightens_ansi_colors) rendered
--     identically to plain text and bright CLI output read flat;
--   * the light theme's selection put the foreground at 3.96:1, an AA failure;
--   * the light theme's cursor was rosewater on the background at 2.34:1 with
--     a 2.00:1 glyph inside it -- hard to find and hard to read.
--
-- So this asserts the DERIVED colours against the same WCAG 4.5 rule the
-- guard uses, in both theme directions. Both directions matter: the light
-- path is where all three of the above were worst.
--
-- The checks are computed from the loaded scheme rather than from constants,
-- so they follow the palette instead of pinning today's one.
local MIN_CONTRAST = 4.5
-- A `brights` slot must be a VISIBLE step up from its `ansi` counterpart, or
-- bold text is indistinguishable from plain. 1.10 is the floor every slot of
-- every palette in this suite clears; the tightest real case is catppuccin
-- mocha's yellow, #f9e2af -> #fcebcd.
local MIN_BRIGHT_STEP = 1.10
-- The selection only has to be DISTINGUISHABLE, not AA: it is a UI affordance,
-- not body text, and pushing it to 4.5:1 against the background would mean
-- filling the block with a saturated accent, which is the garish look this
-- whole change backs away from. 1.30 keeps it unmistakably not-the-page.
local MIN_SELECTION_STEP = 1.30

local function rel_lum(hex)
   if type(hex) ~= 'string' or not hex:match('^#%x%x%x%x%x%x$') then
      return -1
   end
   local function ch(c)
      c = c / 255
      if c <= 0.04045 then
         return c / 12.92
      end
      return ((c + 0.055) / 1.055) ^ 2.4
   end
   return 0.2126 * ch(tonumber(hex:sub(2, 3), 16))
      + 0.7152 * ch(tonumber(hex:sub(4, 5), 16))
      + 0.0722 * ch(tonumber(hex:sub(6, 7), 16))
end

local function ratio(a, b)
   local la, lb = rel_lum(a), rel_lum(b)
   if la < 0 or lb < 0 then
      return 0
   end
   local hi, lo = la > lb and la or lb, la < lb and la or lb
   return (hi + 0.05) / (lo + 0.05)
end

local SLOTS = { 'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white' }

---Assert every readability invariant on one loaded scheme.
---@param label string
---@param cs table the loaded colourscheme
---@param palette table? the matugen palette it came from, when known
local function check_readable(label, cs, palette)
   local bg = cs.background

   check(
      label .. ': foreground clears 4.5:1 on the background',
      ratio(cs.foreground, bg) >= MIN_CONTRAST,
      string.format('%.2f:1', ratio(cs.foreground, bg))
   )

   -- The foreground is pushed AWAY from the background, and it has to stay
   -- pushed -- checked against the palette's own foreground token rather than
   -- against the flat background, because the flat background cannot see the
   -- problem. utils/backdrops.lua composites the wallpaper UNDER this colour,
   -- so the surface the text actually sits on is the wash blended with
   -- whatever the artwork is doing there. Measured at a mid-range wash of 0.60
   -- with a fully-bleeding-through wallpaper region: latte's raw #4c4f69
   -- scores 2.52:1 and the boosted #22242f scores 4.88:1 -- the boost is the
   -- only thing keeping light themes readable there, and asserting against the
   -- flat bg passes with or without it.
   if palette and palette.foreground then
      local raw = math.abs(rel_lum(palette.foreground) - rel_lum(bg))
      local got = math.abs(rel_lum(cs.foreground) - rel_lum(bg))
      check(
         label .. ': foreground is pushed away from the background, not left raw',
         got > raw,
         string.format(
            '%.4f vs the palette token %.4f (%s -> %s)',
            got,
            raw,
            palette.foreground,
            cs.foreground
         )
      )
   end

   -- The cursor is one fg/bg pair, so both directions are the same number;
   -- assert both anyway, because a future edit that breaks only one of them
   -- (a hardcoded crust again) should not be able to pass.
   check(
      label .. ': cursor is findable against the background',
      ratio(cs.cursor_bg, bg) >= MIN_CONTRAST,
      string.format('cursor_bg %.2f:1', ratio(cs.cursor_bg, bg))
   )
   check(
      label .. ': the glyph inside the cursor clears 4.5:1',
      ratio(cs.cursor_fg, cs.cursor_bg) >= MIN_CONTRAST,
      string.format('%.2f:1', ratio(cs.cursor_fg, cs.cursor_bg))
   )

   -- A selection has two jobs that pull opposite ways: it must be visibly
   -- distinct from the page, and the text on it must stay readable. Both are
   -- asserted. MIN_SELECTION_STEP is deliberately low -- a soft lift is the
   -- point, not a saturated slab of accent.
   local sel = ratio(cs.selection_bg, bg)
   check(
      label .. ': the selection is visibly distinct from the background',
      sel >= MIN_SELECTION_STEP,
      string.format('%.2f:1', sel)
   )
   check(
      label .. ': text on the selection clears 4.5:1',
      ratio(cs.selection_fg, cs.selection_bg) >= MIN_CONTRAST,
      string.format('%.2f:1', ratio(cs.selection_fg, cs.selection_bg))
   )

   for i, name in ipairs(SLOTS) do
      local normal, bright = cs.ansi[i], cs.brights[i]
      check(
         label .. ': ' .. name .. ' bright is a visible step above its normal slot',
         ratio(bright, normal) >= MIN_BRIGHT_STEP,
         string.format('%.3f:1 (%s -> %s)', ratio(bright, normal), normal, bright)
      )
      -- A bright slot must never be LESS readable than the normal slot it was
      -- lifted from. The bar is not a flat 4.5, because ANSI `black` is
      -- deliberately near-invisible -- it is the slot shell prompts use for
      -- de-emphasised text, and neither catppuccin base gives it more than
      -- 1.79:1. Demanding 4.5 of it would be demanding the wrong thing.
      -- The rule is: keep whatever contrast the normal slot already had, and
      -- reach full AA whenever the normal slot reached it.
      local bar = math.min(MIN_CONTRAST, ratio(normal, bg))
      check(
         label .. ': ' .. name .. ' bright is never less readable than its normal slot',
         ratio(bright, bg) >= bar - 1e-9,
         string.format('%.2f:1, needs %.2f (%s -> %s)', ratio(bright, bg), bar, normal, bright)
      )
   end
end

-- The decoy is a dark palette (#123456), so this is the dark-theme path.
check_readable('decoy (dark)', assert(scheme_with_home(nil)), DECOY)

-- And the light path. No wallpaper in the current cache resolves light, so
-- without this the whole light branch -- where every one of the three bugs
-- above was worst -- would be untested.
do
   -- A bright background (so luminance() >= 0.5 picks latte) with tokens that
   -- are deliberately mid-dark, the shape that makes the derived colours hard.
   local LIGHT = {
      foreground = '#4c4f69',
      background = '#eff1f5',
      primary = '#1e66f5',
      secondary = '#ea76cb',
      tertiary = '#df8e1d',
      success = '#40a02b',
      error = '#d20f39',
      surface0 = '#ccd0da',
      surface1 = '#bcc0cc',
      surface2 = '#acb0be',
      outline = '#9ca0b0',
   }
   local light_dir = ('/tmp/wezterm-theme-light-%d-%d'):format(os.time(), math.random(1e6))
   assert(os.execute('mkdir -p ' .. light_dir .. '/colors'))
   local p = assert(io.open(light_dir .. '/colors/matugen.lua', 'w'))
   p:write('return {\n')
   for k, v in pairs(LIGHT) do
      p:write(string.format('   %s = "%s",\n', k, v))
   end
   p:write('}\n')
   p:close()

   local real_config_dir = wezterm.config_dir
   wezterm.config_dir = light_dir
   local cs, err = scheme_with_home(nil)
   wezterm.config_dir = real_config_dir
   os.execute('rm -rf ' .. light_dir)

   check(
      'the light palette resolves to a light background',
      cs ~= nil and rel_lum(cs.background) > 0.5,
      tostring(err)
   )
   if cs and rel_lum(cs.background) > 0.5 then
      check_readable('latte (light)', cs, LIGHT)
   end
end

print(('\n%d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
