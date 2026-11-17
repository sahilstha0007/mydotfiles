-- Test: the COMMITTED static palette must be internally consistent.
--
-- colors/custom.lua and colors/matugen.lua used to be generated from the
-- wallpaper by matugen, with light/dark variants derived at load time. That is
-- gone: both files are now static Apple Dark Glass palettes committed to the
-- repo. There is no HOME lookup, no dofile of a generated palette, and no
-- contrast/luminance derivation left to exercise.
--
-- What is worth testing now is the palette itself:
--   * the committed hexes are exactly the ones the static design specifies;
--   * the two wezterm files agree with each other (chrome vs token table);
--   * the scheme is readable (fg/bg, cursor pair, selection) by the WCAG rule;
--   * each bright ANSI slot is a visible step above its normal slot, and never
--     less readable against the background;
--   * custom.lua did NOT quietly regain the dynamic derivation machinery.
--
-- The checks are computed from the loaded tables as well as pinned to the
-- committed values, so a bad edit is caught and a good palette still passes.
--
-- Run: luajit tests/check_theme_source.lua <config-root>

local _script_dir = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]+$')) or '.'
local root = dofile(_script_dir .. '/lib/resolve_root.lua')('check_theme_source.lua', arg)

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

-- The committed static design (Apple Dark Glass). Any drift here is a real
-- regression: these are the values every other terminal in the stack mirrors.
local BG = '#1c1c1e'
local FG = '#f5f5f7'
local ACCENT = '#2dd4bf'
local ANSI = {
   '#3a3a3c', -- black
   '#ff6b6b', -- red
   '#7dce8b', -- green
   '#f2d97a', -- yellow
   '#2dd4bf', -- blue (accent)
   '#cba6f0', -- magenta
   '#64d2ff', -- cyan
   '#ebebf5', -- white
}
local BRIGHTS = {
   '#6e6e73',
   '#ff8a80',
   '#a3e5ae',
   '#f7e6a3',
   '#5eead4',
   '#dcb8f5',
   '#9fdcf5',
   '#f5f5f7',
}
local SLOT_NAMES = { 'black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white' }

-- Body text, the cursor pair and full-strength ANSI colours must clear AA.
local MIN_CONTRAST = 4.5
-- A bright slot must be a VISIBLE step up from its normal slot, or `bold`
-- (wezterm's bold_brightens_ansi_colors) renders identically to plain text.
-- 1.08 is the floor this static palette actually clears; the tightest case is
-- white, #ebebf5 -> #f5f5f7, which is already at the display ceiling. Pushing
-- every slot to 1.10 would fail that one for no readability gain.
local MIN_BRIGHT_STEP = 1.08
-- The selection is a UI affordance, not body text: distinct from the page and
-- with legible text on it, but deliberately not a 4.5:1 slab of saturated
-- accent (white on the teal accent scores ~1.86:1 by design).
local MIN_SELECTION_STEP = 1.30
local MIN_SELECTION_TEXT = 1.50

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

-- Both palettes are plain tables now: no wezterm global, no environment.
local ok_custom, custom = pcall(dofile, root .. '/colors/custom.lua')
check(
   'colors/custom.lua loads as a table',
   ok_custom and type(custom) == 'table',
   ok_custom or custom
)
local ok_matugen, matugen = pcall(dofile, root .. '/colors/matugen.lua')
check(
   'colors/matugen.lua loads as a table',
   ok_matugen and type(matugen) == 'table',
   ok_matugen or matugen
)
if not (ok_custom and ok_matugen and type(custom) == 'table' and type(matugen) == 'table') then
   print(('\n%d passed, %d failed'):format(pass, fail))
   os.exit(1)
end

-- 1. Committed values. These are the source of truth the rest of the stack is
--    meant to mirror; a change here without matching edits elsewhere is drift.
check('background is the committed dark value', custom.background == BG, custom.background)
check('foreground is the committed value', custom.foreground == FG, custom.foreground)
check(
   'accent is the blue ANSI slot',
   custom.ansi and custom.ansi[5] == ACCENT,
   custom.ansi and custom.ansi[5]
)
check('accent is the cursor colour', custom.cursor_bg == ACCENT, custom.cursor_bg)
check('accent is the selection colour', custom.selection_bg == ACCENT, custom.selection_bg)

for i, name in ipairs(SLOT_NAMES) do
   check(
      'ansi ' .. name .. ' is the committed hex',
      custom.ansi and custom.ansi[i] == ANSI[i],
      custom.ansi and custom.ansi[i]
   )
   check(
      'bright ' .. name .. ' is the committed hex',
      custom.brights and custom.brights[i] == BRIGHTS[i],
      custom.brights and custom.brights[i]
   )
end

check('matugen.background is the committed value', matugen.background == BG, matugen.background)
check('matugen.foreground is the committed value', matugen.foreground == FG, matugen.foreground)
check('matugen.primary is the committed accent', matugen.primary == ACCENT, matugen.primary)

-- 2. The chrome scheme and the token table must agree. They are separate
--    files and used to be generated by different paths, so this is the seam.
check(
   'wezterm and matugen agree on background',
   custom.background == matugen.background,
   tostring(custom.background) .. ' vs ' .. tostring(matugen.background)
)
check(
   'wezterm and matugen agree on foreground',
   custom.foreground == matugen.foreground,
   tostring(custom.foreground) .. ' vs ' .. tostring(matugen.foreground)
)
check(
   'wezterm accent matches matugen.primary',
   custom.ansi[5] == matugen.primary,
   tostring(custom.ansi[5]) .. ' vs ' .. tostring(matugen.primary)
)

-- 3. Readability, computed from the loaded scheme.
check(
   'foreground clears 4.5:1 on the background',
   ratio(custom.foreground, custom.background) >= MIN_CONTRAST,
   string.format('%.2f:1', ratio(custom.foreground, custom.background))
)
check(
   'cursor is findable against the background',
   ratio(custom.cursor_bg, custom.background) >= MIN_CONTRAST,
   string.format('%.2f:1', ratio(custom.cursor_bg, custom.background))
)
check(
   'the glyph inside the cursor clears 4.5:1',
   ratio(custom.cursor_fg, custom.cursor_bg) >= MIN_CONTRAST,
   string.format('%.2f:1', ratio(custom.cursor_fg, custom.cursor_bg))
)
local sel = ratio(custom.selection_bg, custom.background)
check(
   'selection is visibly distinct from the background',
   sel >= MIN_SELECTION_STEP,
   string.format('%.2f:1', sel)
)
local sel_text = ratio(custom.selection_fg, custom.selection_bg)
check(
   'text on the selection stays legible',
   sel_text >= MIN_SELECTION_TEXT,
   string.format('%.2f:1', sel_text)
)

-- 4. Bright slots: visible step above normal, never less readable than normal.
for i, name in ipairs(SLOT_NAMES) do
   local normal, bright = custom.ansi[i], custom.brights[i]
   local step = ratio(bright, normal)
   check(
      name .. ' bright is a visible step above its normal slot',
      step >= MIN_BRIGHT_STEP,
      string.format('%.3f:1 (%s -> %s)', step, normal, bright)
   )
   -- ANSI black is deliberately near-invisible; demand only what the normal
   -- slot already had, up to full AA when the normal slot reached it.
   local bar = math.min(MIN_CONTRAST, ratio(normal, custom.background))
   check(
      name .. ' bright is never less readable than its normal slot',
      ratio(bright, custom.background) >= bar - 1e-9,
      string.format(
         '%.2f:1, needs %.2f (%s -> %s)',
         ratio(bright, custom.background),
         bar,
         normal,
         bright
      )
   )
end

-- 5. Guard the design decision itself: none of the dynamic machinery came
--    back. Strip comments first so the header's prose is not a false hit.
do
   local fh = assert(io.open(root .. '/colors/custom.lua', 'r'))
   local src = fh:read('*a')
   fh:close()
   local code = src:gsub('%-%-[^\n]*', '')
   local found = {}
   for _, token in ipairs({ 'dofile(', 'os.getenv', 'luminance', 'MIN_CONTRAST', 'matugen' }) do
      if code:find(token, 1, true) then
         found[#found + 1] = token
      end
   end
   check('custom.lua has no wallpaper/derive machinery', #found == 0, table.concat(found, ', '))
end

print(('\n%d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
