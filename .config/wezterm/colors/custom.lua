-- Wallpaper-driven colorscheme: matugen tokens (colors/matugen.lua, written by
-- utils/sync-wallpaper.sh with `-m smart`) are merged onto a catppuccin base.
-- The base — mocha (dark) or latte (light) — is chosen from the wallpaper's
-- own background luminance, so a bright wallpaper yields a LIGHT theme (dark
-- text, dark accents readable on light) and a dark wallpaper a DARK theme
-- (bright text). Everything downstream (nvim via OSC/file adoption, tmux via
-- colors-from-matugen.sh) derives light/dark the same way, so all three stay
-- in sync from this one file.
-- stylua: ignore

local wezterm = require('wezterm')

local function luminance(hex)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

-- Catppuccin mocha (dark wallpaper base)
local mocha = {
   rosewater = '#f5e0dc',
   flamingo  = '#f2cdcd',
   pink      = '#f5c2e7',
   mauve     = '#cba6f7',
   red       = '#f38ba8',
   maroon    = '#eba0ac',
   peach     = '#fab387',
   yellow    = '#f9e2af',
   green     = '#a6e3a1',
   teal      = '#94e2d5',
   sky       = '#89dceb',
   sapphire  = '#74c7ec',
   blue      = '#89b4fa',
   lavender  = '#b4befe',
   text      = '#cdd6f4',
   subtext1  = '#bac2de',
   subtext0  = '#a6adc8',
   overlay2  = '#9399b2',
   overlay1  = '#7f849c',
   overlay0  = '#6c7086',
   surface2  = '#585b70',
   surface1  = '#45475a',
   surface0  = '#313244',
   base      = '#1f1f28',
   mantle    = '#181825',
   crust     = '#11111b',
}

-- Catppuccin latte (light wallpaper base)
local latte = {
   rosewater = '#dc8a78',
   flamingo  = '#dd7878',
   pink      = '#ea76cb',
   mauve     = '#8839ef',
   red       = '#d20f39',
   maroon    = '#e64553',
   peach     = '#fe640b',
   yellow    = '#df8e1d',
   green     = '#40a02b',
   teal      = '#179299',
   sky       = '#04a5e5',
   sapphire  = '#209fb5',
   blue      = '#1e66f5',
   lavender  = '#7287fd',
   text      = '#4c4f69',
   subtext1  = '#5c5f77',
   subtext0  = '#6c6f85',
   overlay2  = '#7c7f93',
   overlay1  = '#8c8fa1',
   overlay0  = '#9ca0b0',
   surface2  = '#acb0be',
   surface1  = '#bcc0cc',
   surface0  = '#ccd0da',
   base      = '#eff1f5',
   mantle    = '#e6e9ef',
   crust     = '#dce0e8',
}

-- WCAG relative luminance + contrast ratio. The old gate was a hand-picked
-- threshold on the 0.299/0.587/0.114 "luminance" number, which is a display-
-- brightness approximation and not a readability measure. It let #6e6e6a
-- (ratio 3.64:1) and #787878 (4.20:1) through as "readable" on a near-black
-- bg, because their 0.43/0.47 brightness scores cleared the 0.40 cut — grey
-- code text shipping at under 4.5:1. Contrast ratio answers the actual
-- question: is this token legible on THIS background, in either direction.
local MIN_CONTRAST = 4.5 -- WCAG AA for normal text

local function channel(c)
   c = c / 255
   if c <= 0.04045 then
      return c / 12.92
   end
   return ((c + 0.055) / 1.055) ^ 2.4
end

---WCAG relative luminance (0..1) of a '#rrggbb' string.
---@param hex string
---@return number
local function rel_lum(hex)
   if type(hex) ~= 'string' or not hex:match('^#%x%x%x%x%x%x$') then
      return -1
   end
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

---WCAG contrast ratio (1..21) between two '#rrggbb' strings. Symmetric, so it
---works for a dark token on a light bg and a light token on a dark one.
---@param a string
---@param b string
---@return number
local function contrast(a, b)
   local la, lb = rel_lum(a), rel_lum(b)
   if la < 0 or lb < 0 then
      return 0
   end
   local hi, lo = la > lb and la or lb, la < lb and la or lb
   return (hi + 0.05) / (lo + 0.05)
end

-- Readability guard — a wallpaper token must reach MIN_CONTRAST against the
-- theme background, else it falls back to the catppuccin base for that slot.
-- Same rule in tmux's colors-from-matugen.sh and nvim's terminal-colors.lua;
-- keep all three in sync. (This wallpaper's "success" is a dark olive at
-- 2.87:1 on the near-black bg, which is why code green falls back to catppuccin.)
---@param hex string? the wallpaper token
---@param fallback string the catppuccin base colour for the slot
---@param bg string the theme background the token must read against
---@return string
local function guard(hex, fallback, bg)
   if not hex then
      return fallback
   end
   if contrast(hex, bg) < MIN_CONTRAST then
      return fallback
   end
   return hex
end

---Blend two hexes in sRGB. Deliberately NOT perceptual: every use here is a
---short hop between two colours that are already close (bg->accent tint,
---slot->extreme lift), where gamma-space interpolation is what an eyedropper
---would produce and keeps the hue steady. Linear-light mixing would swing the
---hue of a saturated accent and break the "same palette" promise.
---@param a string
---@param b string
---@param t number 0 = a, 1 = b
---@return string
local function blend(a, b, t)
   local function rgb(hex)
      return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
   end
   local ar, ag, ab = rgb(a)
   local br, bg_, bb = rgb(b)
   return string.format(
      '#%02x%02x%02x',
      math.floor(ar + (br - ar) * t + 0.5),
      math.floor(ag + (bg_ - ag) * t + 0.5),
      math.floor(ab + (bb - ab) * t + 0.5)
   )
end

-- Two derived colours, and the reason each one exists.
--
-- Every value below was picked by measuring, not by taste: run the numbers in
-- the comment next to each constant before changing it. The pairing that
-- matters is the WORST case over every palette this config can resolve —
-- stock mocha, stock latte, and whatever matugen last wrote — not the one
-- palette sitting on disk right now.
--
-- BRIGHT_LIFT: how far an ANSI slot travels toward the theme extreme (white
-- on dark themes, black on light) to become its `brights` counterpart.
-- Before this, five of eight slots were byte-identical to their normal
-- counterpart — green, yellow, blue, magenta and cyan all emitted the SAME
-- hex for ansi[n] and brights[n]. `bold` on a colour (wezterm's
-- bold_brightens_ansi_colors, on by default) then rendered identically to
-- plain text, which is why bright CLI output read flat. 0.40 is the smallest
-- blend that lifts every slot of every palette the test suite exercises by a
-- contrast step of at least 1.10 over its normal slot (mocha's yellow, the
-- hardest case: #f9e2af -> #fcebcd, 1.10) while keeping the slot itself on the
-- right side of MIN_CONTRAST against the background. Larger only greys the
-- darks out further — mocha's black slot reaches 5.2:1 at 0.40 and keeps
-- climbing toward white.
local BRIGHT_LIFT = 0.40

-- SELECTION_LIFT: how far the background travels toward the wallpaper accent
-- to make the selection block. This is deliberately NOT a saturated accent
-- fill. Over a wallpaper, a block painted in the accent itself is a garish
-- slab of colour sitting in the middle of the artwork; a low-alpha accent
-- tint reads as the glass lifting under the text instead, which is the whole
-- point of the mood. 0.42 is where it clears a visible step from the
-- background (mocha 2.5:1, live wallpaper 2.9:1) AND still leaves selection_fg
-- comfortably over MIN_CONTRAST. See SELECTION_FG for why that second half is
-- not automatic.
local SELECTION_LIFT = 0.42

-- SELECTION_FG is the palette extremity — pure white on dark themes, pure
-- black on light — rather than the theme's own foreground.
--
-- Why it cannot be `foreground`: a selection tint moves the background toward
-- the accent, and on LIGHT themes that walk ends somewhere the guard-checked
-- foreground no longer clears 4.5:1. Measured, latte: foreground #4c4f69 on
-- the #97b7f5 selection is 3.96:1 — a real AA failure, and it is the value
-- that shipped. Pure black on the same block is 10.41:1.
--
-- Why it cannot be 'none' (keep each cell's own colour): wezterm's docs say a
-- transparent selection_fg falls back to the CURRENT text colour, which for a
-- selection spanning coloured output is the cell's own ANSI slot. Measured on
-- the same block, that puts ansi black (#45475a dark / #bcc0cc light) at
-- 1.40:1 and 1.11:1 — invisible. So the pair has to be set explicitly: a
-- mid-tint accent block with one strong label colour on it.
local SELECTION_FG = { dark = '#ffffff', light = '#000000' }

---Hue (0..360) of a '#rrggbb' string; -1 for invalid or monochrome.
---@param hex string
---@return number
local function hue(hex)
   if type(hex) ~= 'string' or not hex:match('^#%x%x%x%x%x%x$') then
      return -1
   end
   local r = tonumber(hex:sub(2, 3), 16) / 255
   local g = tonumber(hex:sub(4, 5), 16) / 255
   local b = tonumber(hex:sub(6, 7), 16) / 255
   local max, min = math.max(r, g, b), math.min(r, g, b)
   local d = max - min
   if d == 0 then
      return -1
   end
   local h
   if max == r then
      h = ((g - b) / d) % 6
   elseif max == g then
      h = (b - r) / d + 2
   else
      h = (r - g) / d + 4
   end
   return h * 60
end

---Circular hue distance in degrees (0..180).
---@param a number
---@param b number
---@return number
local function hue_dist(a, b)
   if a < 0 or b < 0 then
      return 180
   end
   local d = math.abs(a - b)
   return math.min(d, 360 - d)
end

-- Apply the wallpaper's matugen tokens over the chosen catppuccin base.
-- Mirrored by ~/.config/tmux/colors-from-matugen.sh — keep in sync.
local function apply_wallpaper(base, mat, light)
   local c = {}
   for k, v in pairs(base) do
      c[k] = v
   end
   c.base      = mat.background
   c.mantle    = mat.background
   c.crust     = mat.background
   -- Every token is checked against the background it will actually sit on,
   -- so the guard needs the resolved bg, not the light/dark flag.
   local bg = c.base
   c.text      = guard(mat.foreground, base.text, bg)
   -- Push plain text AWAY from the background, because the background is not
   -- the background the text actually sits on: utils/backdrops.lua composites
   -- the wallpaper UNDER this colour (hsb brightness = wash, then a flat wash
   -- of the bg at the same opacity). Where the artwork is bright, the real
   -- backdrop is far lighter than `bg` and text loses contrast there — that
   -- is the "wallpaper is busy here" case, and no amount of guarding `bg`
   -- sees it, because the guard only knows the flat colour.
   --
   -- 0.55 is measured against the nine wallpapers in ~/.cache/wezterm-wallpapers
   -- at a wash of 0.82 (the older default; the current 0.85 is darker, so
   -- these are conservative lower bounds): worst composited backdrop #474743 (mocha) /
   -- #3d3e2d (live olive), where raw text scores 6.45 and 8.45 and this scores
   -- 7.97 and 9.73. Raising it to 0.70 buys only +0.44 more at that wash and
   -- is not worth the loss of the hue.
   --
   -- The original version brightened on dark themes and left light themes on
   -- the raw token, because there was no measured reason to move them. There
   -- is one now: a bright wallpaper has dark regions in it, they composite
   -- through the wash exactly the same way, and latte's #4c4f69 scores 4.67
   -- on the #c4c6c9 that a black region produces at wash 0.82 — under 4.5
   -- the moment anything shifts. Darkening the same distance restores 9.01.
   -- Move away from the background; the direction is the only thing that flips.
   if c.text then
      c.text = blend(c.text, light and '#000000' or '#ffffff', 0.18)
   end
   c.subtext1 = blend(c.text, bg, 0.15)
   c.subtext0 = blend(c.text, bg, 0.30)
   -- The Hero Accent: signature wallpaper primary for cursor, tabs, borders, and pills
   c.accent    = guard(mat.primary, base.blue, bg)

   -- Red (ANSI 1): error / deletion / red. Must be in red/coral range (325..35)
   local err_h = hue(mat.error)
   if (err_h >= 325 or err_h <= 35) and contrast(mat.error, bg) >= MIN_CONTRAST then
      c.red = mat.error
   else
      c.red = base.red
   end

   -- Green (ANSI 2): success / addition / commands. Must be in green/lime range (65..170)
   local succ_h = hue(mat.success)
   local prim_h = hue(mat.primary)
   if (succ_h >= 65 and succ_h <= 170) and contrast(mat.success, bg) >= MIN_CONTRAST then
      c.green = mat.success
   elseif (prim_h >= 65 and prim_h <= 170) and contrast(mat.primary, bg) >= MIN_CONTRAST then
      c.green = mat.primary
   else
      c.green = base.green
   end

   -- Yellow (ANSI 3): warning / notice. Must be in yellow/amber range (35..80) and distinct from green
   local tert_h = hue(mat.tertiary)
   if (tert_h >= 35 and tert_h <= 80) and hue_dist(tert_h, hue(c.green)) >= 25 and contrast(mat.tertiary, bg) >= MIN_CONTRAST then
      c.yellow = mat.tertiary
   elseif (prim_h >= 35 and prim_h <= 80) and hue_dist(prim_h, hue(c.green)) >= 25 and contrast(mat.primary, bg) >= MIN_CONTRAST then
      c.yellow = mat.primary
   else
      c.yellow = base.yellow
   end

   -- Blue (ANSI 4): information / functions / paths / HERO ACCENT.
   -- Adopts the wallpaper primary accent (c.accent) so that functions,
   -- chrome, line numbers, and tabs reflect the signature wallpaper palette.
   c.blue = c.accent

   -- Magenta (ANSI 5): keywords / control flow. Must be distinct from red and blue
   local sec_h = hue(mat.secondary)
   if (sec_h >= 265 and sec_h <= 335) and contrast(mat.secondary, bg) >= MIN_CONTRAST then
      c.pink = mat.secondary
   else
      c.pink = base.pink
   end

   -- Cyan (ANSI 6): operators / interfaces. Must be in cyan/teal range (160..210)
   if (tert_h >= 160 and tert_h <= 210) and contrast(mat.tertiary, bg) >= MIN_CONTRAST then
      c.teal = mat.tertiary
   elseif (sec_h >= 160 and sec_h <= 210) and contrast(mat.secondary, bg) >= MIN_CONTRAST then
      c.teal = mat.secondary
   else
      c.teal = base.teal
   end

   c.rosewater = base.rosewater

   -- Guarantee hue separation: no two ANSI slots can be closer than 30°
   local taken = {}
   for _, name in ipairs({ 'blue', 'green', 'yellow', 'red', 'pink', 'teal' }) do
      local h = hue(c[name])
      local collides = false
      if h >= 0 then
         for _, other in ipairs(taken) do
            if hue_dist(h, other) < 30 then
               collides = true
               break
            end
         end
      end
      if collides then
         c[name] = base[name]
      elseif h >= 0 then
         table.insert(taken, h)
      end
   end
   c.surface0  = mat.surface0
   c.surface1  = mat.surface1
   c.surface2  = mat.surface2
   c.overlay0  = mat.outline
   return c
end

local base = mocha -- fallback: stock catppuccin mocha if matugen never ran
-- The palette lives BESIDE this file, so resolve the path from wezterm, never
-- from the environment. `os.getenv('HOME')` is nil under a systemd unit, a
-- flatpak, or any launcher that scrubs the environment -- and the concat then
-- raises, taking the ENTIRE config down with it (verified: `env -u HOME
-- wezterm start` dies here with "attempt to concatenate a nil value", not
-- with a quiet fallback).
--
-- wezterm.config_dir is the directory of the config file actually being run,
-- so this also survives a checkout that is NOT at ~/.config/wezterm.
-- wezterm.home_dir is the fallback for a build without it; unlike os.getenv
-- it is resolved from the passwd entry, not the environment.
local palette_path = (wezterm.config_dir or wezterm.home_dir .. '/.config/wezterm')
   .. '/colors/matugen.lua'
local ok, matugen = pcall(dofile, palette_path)
-- Which way this palette points. Default dark, because `base` above falls back
-- to mocha when no palette is readable. Needed below by the derived colours
-- (brights, selection, cursor), which each pick one of two values by it.
local light = false
if ok and type(matugen) == 'table' and matugen.background then
   -- Bright wallpaper background -> light theme (latte), dark -> mocha.
   light = luminance(matugen.background) >= 0.5
   base = apply_wallpaper(light and latte or mocha, matugen, light)
end

-- '#rrggbb' -> 'rgba(r, g, b, a)' (alpha 0..1). Used for translucent chrome
-- that must follow the theme: dark glass over dark themes, light glass over
-- light themes.
local function rgba(hex, a)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return string.format('rgba(%d, %d, %d, %s)', r, g, b, tostring(a))
end

-- The 8 normal ANSI slots, in wezterm's order. Built here as a value (not
-- inlined in the table below) because `brights` is DERIVED from it -- see
-- BRIGHT_LIFT for why the two can no longer be written independently.
local ansi = {
   base.surface1, -- black
   base.red,      -- red
   base.green,    -- green
   base.yellow,   -- yellow
   base.blue,     -- blue
   base.pink,     -- magenta
   base.teal,     -- cyan
   base.subtext1, -- white
}

-- The palette extremity for this theme direction. Dark themes brighten toward
-- white, light themes darken toward black -- always AWAY from the background,
-- which is what keeps a lifted slot more readable than the one it came from.
local extreme = light and '#000000' or '#ffffff'

---Lift one slot to its `brights` counterpart.
---@param slot string
---@return string
local function brighten(slot)
   return blend(slot, extreme, BRIGHT_LIFT)
end

-- The cursor.
--
-- It used to be rosewater with a crust label, which is invisible on light
-- themes: latte rosewater #dc8a78 against the #eff1f5 background is 2.34:1,
-- and its #dce0e8 label on that block is 2.00:1 — a 4.5:1 failure on the
-- block AND a 2.00:1 failure on the character sitting inside it. The cursor is
-- the one thing that must never be hard to find, so it now comes from the
-- shared accent instead: base.blue is the wallpaper primary in the ANSI blue
-- slot (the same token the tab pill, pane-select chip and tmux pill use), so
-- the cursor belongs to the palette rather than to a hardcoded rose.
--
-- On light themes the accent is mid-dark (latte #1e66f5 = 4.34:1 on its own
-- background, just under MIN_CONTRAST), so it is run through brighten() the
-- same way an ANSI slot would be. That lands #1445a7 at 7.61:1 -- the label
-- and the block are the same 7.61:1 either way, because a block cursor paints
-- the cell and its glyph with one fg/bg pair. 8.08:1 dark.
--
-- guard() keeps the plain accent whenever it already clears MIN_CONTRAST, so
-- dark themes get the saturated primary (10.90:1 on the live wallpaper) and
-- only light themes pay for the lift. Darkening on a light theme and
-- lightening on a dark one are the same operation: move away from the page.
local cursor = guard(base.accent or base.blue, brighten(base.accent or base.blue), base.base)

-- The selection: a soft accent lift, with the label pinned to the extreme so
-- the pair always clears MIN_CONTRAST. Both numbers are argued in
-- SELECTION_LIFT / SELECTION_FG above.
local selection_bg = blend(base.base, cursor, SELECTION_LIFT)

local colorscheme = {
   foreground = base.text,
   background = base.base,
   cursor_bg = cursor,
   cursor_border = cursor,
   -- The glyph inside the block: the background colour, so cursor contrast is
   -- symmetric with the block's own contrast against the page. A hardcoded
   -- `crust` cannot do this — crust IS base.base on a wallpaper theme (both
   -- are aliased to mat.background), so it worked by accident and would break
   -- the moment the two stopped being the same value.
   cursor_fg = base.base,
   selection_bg = selection_bg,
   selection_fg = light and SELECTION_FG.light or SELECTION_FG.dark,
   -- quick_select_* need `ColorSpec` tables on this wezterm version
   quick_select_label_bg = { Color = base.surface1 },
   quick_select_label_fg = { Color = base.text },
   quick_select_match_bg = { Color = base.yellow },
   quick_select_match_fg = { Color = base.crust },
   ansi = ansi,
   brights = {
      brighten(ansi[1]), -- black
      brighten(ansi[2]), -- red
      brighten(ansi[3]), -- green
      brighten(ansi[4]), -- yellow
      brighten(ansi[5]), -- blue
      brighten(ansi[6]), -- magenta
      brighten(ansi[7]), -- cyan
      brighten(ansi[8]), -- white
   },
   tab_bar = {
      background = rgba(base.base, 0.4),
      active_tab = {
         bg_color = base.surface2,
         fg_color = base.text,
      },
      inactive_tab = {
         bg_color = base.surface0,
         fg_color = base.subtext1,
      },
      inactive_tab_hover = {
         bg_color = base.surface0,
         fg_color = base.text,
      },
      new_tab = {
         bg_color = base.base,
         fg_color = base.text,
      },
      new_tab_hover = {
         bg_color = base.mantle,
         fg_color = base.text,
         italic = true,
      },
   },
   visual_bell = base.red,
   indexed = {
      [16] = base.peach,
      [17] = base.rosewater,
   },
   scrollbar_thumb = base.surface2,
   split = base.overlay0,
   compose_cursor = base.flamingo,
}

return colorscheme
