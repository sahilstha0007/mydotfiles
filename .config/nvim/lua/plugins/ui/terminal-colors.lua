-- Terminal-adopting colorscheme.
--
-- Instead of a fixed wallpaper-derived palette (the old matugen theme), nvim
-- queries the terminal emulator it runs inside for its actual palette and
-- adopts it. Both kitty and wezterm answer OSC 4 (colors 0-15), OSC 10 (fg)
-- and OSC 11 (bg) queries, and both push updated OSC 4 sequences to running
-- apps when the terminal colorscheme changes — so nvim re-tints live when you
-- switch themes in the terminal.
--
-- Mechanics (documented in :h TermResponse):
--   * vim.api.nvim_ui_send("\027]4;N;?\027\\") asks the host terminal for
--     color index N; the response arrives as a TermResponse event.
--   * The 16 ANSI colors + fg/bg are mapped onto catppuccin's semantic slots
--     (base/surface/text/overlay + accents) via color_overrides, so every
--     catppuccin integration (treesitter, blink, gitsigns, snacks, trouble,
--     neo-tree, lualine, bufferline, …) follows the terminal automatically.
--   * If the terminal never answers (no OSC support / non-tty, or nvim runs
--     inside tmux which eats OSC queries), the stack reads wezterm's
--     colors/custom.lua and watches colors/matugen.lua for live re-tints.
--     TERMINAL_STACK_PROFILE selects the source; legacy KITTY_WINDOW_ID /
--     WEZTERM_PANE markers remain supported. Both kitty and WezTerm share one
--     wallpaper palette (kitty's colors are regenerated from wezterm's), so
--     kitty adopts it too. Unknown profiles keep stock Catppuccin.

local M = {}

-- ---------------------------------------------------------------------------
-- Palette state
-- ---------------------------------------------------------------------------
local pal = {
  ansi = {}, -- [0..15] -> '#rrggbb'
  fg = nil, -- OSC 10
  bg = nil, -- OSC 11
}

-- True once the 16 ANSI colors have been collected. fg/bg are optional —
-- build_overrides falls back to catppuccin defaults for those.
local function complete()
  for i = 0, 15 do
    if not pal.ansi[i] then
      return false
    end
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Color helpers
-- ---------------------------------------------------------------------------
-- Convert a color response component to an 8-bit hex channel.
-- Terminals answer with rgb:RRRR/GGGG/BBBB (16-bit, kitty/wezterm) or
-- rgb:RR/GG/BB (8-bit).
local function chan(v)
  local n = tonumber(v, 16)
  if n >= 0x100 then
    n = math.floor(n / 257)
  end
  return n
end

-- Parse an OSC color spec into '#rrggbb'. Handles rgb:RRRR/GGGG/BBBB,
-- rgba:RRRR/GGGG/BBBB/AAAA (alpha ignored) and #rrggbb.
local function parse_color(spec)
  if not spec then
    return nil
  end
  local r, g, b = spec:match 'rgba?:%s*(%x+)/(%x+)/(%x+)'
  if r and g and b then
    return string.format('#%02x%02x%02x', chan(r), chan(g), chan(b))
  end
  local hex = spec:match '#(%x%x%x%x%x%x)'
  if hex then
    return '#' .. hex
  end
  return nil
end

-- Mix two '#rrggbb' colors by fraction t (0..1) toward the second.
local function mix(a, b, t)
  local function rgb(hex)
    return tonumber(hex:sub(2, 3), 16),
      tonumber(hex:sub(4, 5), 16),
      tonumber(hex:sub(6, 7), 16)
  end
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  local function ch(x, y)
    return string.format('%02x', math.floor(x + (y - x) * t + 0.5))
  end
  return '#' .. ch(ar, br) .. ch(ag, bg) .. ch(ab, bb)
end

-- Perceived luminance (0..1) of a '#rrggbb' color. Used ONLY to pick the theme
-- direction from the wallpaper: bright background -> light theme (dark text),
-- dark -> dark theme (bright text). This mirrors the rule in wezterm's
-- colors/custom.lua and tmux's colors-from-matugen.sh so all three flip
-- together. Token readability is a separate question, answered by contrast()
-- below — this brightness approximation is not a readability measure.
local function luminance(hex)
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

local function is_light_bg()
  local bg = pal.bg
  return bg and bg:match '^#[%x][%x][%x][%x][%x][%x]$' and luminance(bg) >= 0.5
end

-- WCAG relative luminance + contrast ratio. The readability gate used to be a
-- hand-picked cut on `luminance()` (0.40 dark / 0.63 light), which is a display-
-- brightness approximation rather than a readability measure — it let #6e6e6a
-- (3.64:1) and #787878 (4.20:1) through as readable on a near-black bg. Same
-- rule and same constant in wezterm's colors/custom.lua and tmux's
-- colors-from-matugen.sh; keep the three in sync.
local MIN_CONTRAST = 4.5 -- WCAG AA for normal text

local function channel(c)
  c = c / 255
  if c <= 0.04045 then
    return c / 12.92
  end
  return ((c + 0.055) / 1.055) ^ 2.4
end

---WCAG relative luminance (0..1) of a '#rrggbb' colour.
---@param hex string
---@return number
local function rel_lum(hex)
  local r = tonumber(hex:sub(2, 3), 16) or 0
  local g = tonumber(hex:sub(4, 5), 16) or 0
  local b = tonumber(hex:sub(6, 7), 16) or 0
  return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
end

---WCAG contrast ratio (1..21) between two colours; symmetric, so it covers
---both a dark token on a light bg and a light token on a dark one.
---@param a string
---@param b string
---@return number
local function contrast(a, b)
  local la, lb = rel_lum(a), rel_lum(b)
  local hi, lo = la > lb and la or lb, la < lb and la or lb
  return (hi + 0.05) / (lo + 0.05)
end

-- Saturation (0..1) of a '#rrggbb' color. Terminal palettes occasionally map
-- accent slots to grays — ml4w's kitty theme uses #e0e2e8 for green AND cyan,
-- which washes the whole UI out gray when adopted wholesale. We only adopt an
-- accent when it is actually colorful; gray slots keep catppuccin mocha's own
-- vibrant accent instead.
local function saturation(hex)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  if max == min then
    return 0
  end
  return (max - min) / (255 - math.abs(max + min - 255))
end

-- Pick an accent from an ANSI pair (base + bright). Prefers the bright variant
-- (terminals design those to read on dark backgrounds), falling back to the
-- base variant when only that one is colorful. Returns nil when both are gray
-- or fail the MIN_CONTRAST check against the adopted background — the caller
-- then keeps catppuccin's own accent. (Saturation alone passed this wallpaper's
-- dark olive success token as "green" code text; it reads at 2.87:1.)
local ACCENT_MIN_SAT = 0.2
local function acc(idx, bright)
  local base, bv = pal.ansi[idx], pal.ansi[bright]
  local bg = pal.bg
  local function readable(hex)
    if not hex then
      return false
    end
    if not bg then
      return true
    end
    return contrast(hex, bg) >= MIN_CONTRAST
  end
  if readable(bv) and saturation(bv) >= ACCENT_MIN_SAT then
    return bv
  end
  if readable(base) and saturation(base) >= ACCENT_MIN_SAT then
    return base
  end
  return nil
end

-- Hue (0..360) of a '#rrggbb' color; -1 for achromatic grays (never passed
-- here — acc() already filters those out).
local function hue(hex)
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

-- Circular hue distance in degrees.
local function hue_dist(a, b)
  local d = math.abs(a - b)
  return math.min(d, 360 - d)
end

-- Adopt terminal accents with GUARANTEED hue separation so code syntax keeps
-- IDE-style contrast even on monochromatic wallpapers. The wallpaper's primary
-- hue always owns the blue slot (UI chrome, links, functions stay themed), but
-- every other accent is adopted only when its hue is far enough from every
-- accent already taken — otherwise that slot falls back to catppuccin's fixed
-- syntax palette. An all-warm wallpaper therefore yields gold chrome + the
-- stock mint/green/red/lavender code palette, never everything-gold.
local MIN_HUE_SEP = 40
local function pick_accents()
  local chosen = {} -- slot -> hex
  local taken = {} -- accepted hues

  local primary = acc(4, 12) -- wallpaper primary -> blue slot, always
  if primary then
    chosen.blue = primary
    taken[#taken + 1] = hue(primary)
  end

  local candidates = {
    { 'lavender', 4, 12 },
    { 'sapphire', 6, 14 },
    { 'sky', 6, 14 },
    { 'teal', 6, 14 },
    { 'green', 2, 10 },
    { 'yellow', 3, 11 },
    { 'peach', 3, 11 },
    { 'red', 1, 9 },
    { 'maroon', 1, 9 },
    { 'mauve', 5, 13 },
    { 'pink', 5, 13 },
    { 'flamingo', 1, 9 },
  }
  for _, c in ipairs(candidates) do
    local hex = acc(c[2], c[3])
    if hex then
      local h = hue(hex)
      local distinct = h >= 0
      for _, other in ipairs(taken) do
        if not distinct or hue_dist(h, other) < MIN_HUE_SEP then
          distinct = false
          break
        end
      end
      if distinct then
        chosen[c[1]] = hex
        taken[#taken + 1] = h
      end
    end
  end
  return chosen
end

-- ---------------------------------------------------------------------------
-- Map the terminal palette onto catppuccin mocha slots
-- ---------------------------------------------------------------------------
local MOCHA_DEFAULTS = {
  base = '#1e1e2e',
  text = '#cdd6f4',
  surface0 = '#313244',
  surface1 = '#45475a',
  surface2 = '#585b70',
  overlay0 = '#6c7086',
  overlay1 = '#7f849c',
  overlay2 = '#9399b2',
  blue = '#89b4fa',
  lavender = '#b4befe',
  sapphire = '#74c7ec',
  sky = '#89dceb',
  teal = '#94e2d5',
  green = '#a6e3a1',
  yellow = '#f9e2af',
  peach = '#fab387',
  red = '#f38ba8',
  maroon = '#eba0ac',
  mauve = '#cba6f7',
  pink = '#f5c2e7',
  flamingo = '#f2cdcd',
  rosewater = '#f5e0dc',
}

-- Light (latte) defaults — used when the adopted background is bright, so
-- gray ANSI slots fall back to colors that actually read on light surfaces.
local LATTE_DEFAULTS = {
  base = '#eff1f5',
  text = '#4c4f69',
  surface0 = '#ccd0da',
  surface1 = '#bcc0cc',
  surface2 = '#acb0be',
  overlay0 = '#9ca0b0',
  overlay1 = '#8c8fa1',
  overlay2 = '#7c7f93',
  blue = '#1e66f5',
  lavender = '#7287fd',
  sapphire = '#209fb5',
  sky = '#04a5e5',
  teal = '#179299',
  green = '#40a02b',
  yellow = '#df8e1d',
  peach = '#fe640b',
  red = '#d20f39',
  maroon = '#e64553',
  mauve = '#8839ef',
  pink = '#ea76cb',
  flamingo = '#dd7878',
  rosewater = '#dc8a78',
}

-- HSLUV-space helpers via catppuccin's bundled lib: perceptually uniform
-- hue rotation (unlike naive RGB hue math) so derived accents keep the same
-- perceived lightness/saturation as the ones the wallpaper provided.
local hsluv = require 'catppuccin.lib.hsluv'

-- Hue (HSLUV space) of a hex color.
local function hsluv_hue(hex)
  local h = unpack(hsluv.hex_to_hsluv(hex))
  return h
end

-- Derive a full, FUNCTIONALLY DISTINCT accent set for code syntax.
--
-- Why: a monochromatic wallpaper (this one is all warm red/orange) collapses
-- most terminal accent slots onto 1-2 hues, so pick_accents() adopts only 2-3
-- of them and every other syntax slot silently falls back to catppuccin
-- defaults — a half-mixed palette where functions/strings/types barely
-- differ from the wallpaper-primary chrome.
--
-- Strategy: whatever pick_accents() failed to adopt gets SYNTHESIZED at a
-- guaranteed hue, spaced evenly around the wheel (golden-angle offsets from
-- the primary hue), while keeping the wallpaper's own saturation/lightness
-- (HSLUV) so everything reads as one family. Result: every functional group
-- of code — comments, strings, numbers, keywords, operators, types,
-- functions, members, params — has its own distinguishable hue, always.
-- @param chosen table from pick_accents (slot -> hex, partial)
-- @param primary_hex the wallpaper-primary hex (blue slot, always adopted)
-- @param D defaults table (provides s/l reference when primary is missing)
local function derive_accents(chosen, primary_hex, D)
  -- hue offsets (degrees, HSLUV space) per slot, measured from the primary/
  -- blue hue. Even ~36° spacing puts every functional role on its own hue:
  -- functions(blue=primary) / types(yellow) / strings(green) / operators(sky)
  -- / escapes(pink) / params(maroon) / keywords(mauve) / members(lavender) /
  -- builtins(red) / numbers(peach). At the wallpaper's saturation+lightness
  -- a 36° HSLUV step is a clearly visible color change (deltaE >> JND).
  local OFFSETS = {
    blue = 0,
    yellow = 40,
    green = 76,
    sky = 112,
    pink = 148,
    maroon = 184,
    mauve = 220,
    lavender = 256,
    red = 292,
    peach = 328,
    teal = 94,
    sapphire = 130,
    flamingo = 58,
    rosewater = 20,
  }
  -- reference color for s/l: the wallpaper primary if we have it, else the
  -- slot's own default (keeps light/dark themes both sane). Saturation
  -- capped at 55 (user: s85+ reads as too bright/harsh) — soft, easy-on-the-
  -- eyes hues close to stock catppuccin's own chroma; lightness 78 keeps
  -- contrast ≥10:1 on the dark transparent bg.
  local ref = primary_hex or D.blue
  local base_hue = hsluv_hue(ref)
  local _, s, l = unpack(hsluv.hex_to_hsluv(ref))
  s = math.min(s or 55, 55)
  l = math.min(l or 78, 78)
  for slot, offset in pairs(OFFSETS) do
    if not chosen[slot] and ref then
      chosen[slot] = hsluv.hsluv_to_hex { (base_hue + offset) % 360, s, l }
    end
  end
  return chosen
end

local function build_overrides()
  local D = is_light_bg() and LATTE_DEFAULTS or MOCHA_DEFAULTS
  local A = pick_accents()
  -- guarantee FULL functional variation: synthesize any accent the terminal
  -- palette couldn't provide (monochromatic wallpaper case), hue-spaced
  -- around the primary so no two code roles share a color
  derive_accents(A, A.blue, D)
  -- Normalize EVERY accent (adopted + derived) to the same softness target:
  -- s55 / l78 HSLUV. Adopted ones keep their natural hue but lose any neon
  -- oversaturation — all 10 roles render at the same gentle chroma (user:
  -- saturation was too bright). Dark themes only; light themes keep
  -- guard-checked tokens as-is.
  if not is_light_bg() then
    for slot, hex in pairs(A) do
      local h = hsluv_hue(hex)
      if h >= 0 then
        A[slot] = hsluv.hsluv_to_hex { h, 55, 78 }
      end
    end
  end
  local base = pal.bg or D.base
  local text = pal.fg or D.text
  -- Surfaces are derived from bg/fg blends, never from ANSI slots: ml4w puts a
  -- light gray (#e0e2e8) in slot 8, which made menus/popups look like washed-
  -- out gray boxes when adopted as surface0.
  local surface0 = mix(base, text, 0.08)

  -- Neutral ramp gate. The ACCENT slots are vetted by acc() (contrast,
  -- saturation, hue separation), but these are fixed blend ratios — so a
  -- wallpaper whose own text token is low-contrast lands overlay1 at 3.8:1
  -- on a dark bg and 2.3:1 on a light one. overlay1 IS the Comment /
  -- @comment colour and overlay0 IS LineNr / @operator / SignColumn: the most
  -- read glyphs on screen, failing WCAG AA while the comment above them
  -- claimed otherwise.
  --
  -- Fix in the ramp itself, not at each call site: keep the demote intent by
  -- taking the SMALLEST lift off `base` that clears MIN_CONTRAST, so a healthy
  -- wallpaper is bit-for-bit unchanged and only a failing one moves.
  local function readable(t)
    if contrast(mix(text, base, t), base) >= MIN_CONTRAST then
      return mix(text, base, t)
    end
    for lift = t - 0.05, 0, -0.05 do
      local c = mix(text, base, lift)
      if contrast(c, base) >= MIN_CONTRAST then
        return c
      end
    end
    return text -- nothing in the ramp passes; full-contrast text is the floor
  end

  return {
    base = base,
    mantle = mix(base, '#000000', 0.15),
    crust = mix(base, '#000000', 0.3),
    surface0 = surface0,
    surface1 = mix(surface0, text, 0.12),
    surface2 = mix(surface0, text, 0.25),
    overlay0 = readable(0.68),
    overlay1 = readable(0.55),
    overlay2 = readable(0.4),
    text = text,
    subtext0 = readable(0.3),
    subtext1 = readable(0.15),
    -- Accents: wallpaper primary owns blue (chrome + functions stay themed);
    -- every other accent is adopted only when hue-distinct (pick_accents), so
    -- monochromatic wallpapers fall back to catppuccin's spread-out syntax
    -- palette — code never collapses into one color.
    blue = A.blue or D.blue,
    lavender = A.lavender or D.lavender,
    sapphire = A.sapphire or D.sapphire,
    sky = A.sky or D.sky,
    teal = A.teal or D.teal,
    green = A.green or D.green,
    yellow = A.yellow or D.yellow,
    peach = A.peach or D.peach,
    red = A.red or D.red,
    maroon = A.maroon or D.maroon,
    mauve = A.mauve or D.mauve,
    pink = A.pink or D.pink,
    flamingo = A.flamingo or D.flamingo,
    rosewater = D.rosewater,
  }
end

-- ---------------------------------------------------------------------------
-- catppuccin options (same design language as the old matugen theme, but
-- colors are sourced from the terminal instead of a wallpaper).
-- ---------------------------------------------------------------------------
local function catppuccin_opts()
  -- Wallpaper direction decides the flavour: latte on bright backgrounds
  -- (dark text), mocha on dark ones. vim.o.background must flip BEFORE the
  -- scheme compiles — plugins and syntax files branch on it.
  local light = is_light_bg()
  local flavour = light and 'latte' or 'mocha'
  vim.o.background = light and 'light' or 'dark'
  return {
    flavour = flavour,
    transparent_background = true, -- let kitty/wezterm opacity show through
    color_overrides = { [flavour] = build_overrides() },
    integrations = {
      nvimtree = true,
      treesitter = true,
      blink_cmp = true,
      gitsigns = true,
      which_key = true,
      mini = { enabled = true },
      snacks = true,
      lsp_trouble = true,
      treesitter_context = true,
      ufo = true,
      flash = true,
    },
    highlight_overrides = {
      [flavour] = function(c)
        -- Overlay design (full transparency edition): every float — snacks
        -- picker, which-key, hover docs, dressing, completion — has a fully
        -- transparent body; rims are a luminous blue-tinted edge; selected
        -- rows are marked with bold + underline accent fg, never a fill.
        local rim = mix(c.surface2, c.blue, 0.35) -- luminous blue float border
        -- Octo's *Dark* tokens want a deeper tone on dark themes and a
        -- softened tone on light ones (same luminance rule as the rest).
        local darken = is_light_bg()
            and function(hex)
              return mix(hex, c.base, 0.45)
            end
          or function(hex)
            return mix(hex, '#000000', 0.45)
          end
        return {
          -- Comments: catppuccin uses overlay0, the most-demoted slot, which
          -- reads as barely-there gray. overlay1 keeps the "receded" feel one
          -- step brighter. build_overrides' readable() gate is what actually
          -- holds this at MIN_CONTRAST — do not trust the fixed 0.55 blend
          -- ratio to do it, it lands at 3.8:1 on a typical dark wallpaper.
          Comment = { fg = c.overlay1, italic = true },

          -- Explorer blends with terminal. nvim-tree.lua is the active tree,
          -- so these are NvimTree* groups; catppuccin's nvimtree integration
          -- themes the rest.
          NvimTreeNormal = { bg = 'NONE', fg = c.text },
          NvimTreeNormalNC = { bg = 'NONE' },
          NvimTreeEndOfBuffer = { bg = 'NONE' },
          NvimTreeWinSeparator = { fg = c.surface1, bg = 'NONE' },

          -- Completion popup: FULL TRANSPARENCY (user preference) — body is
          -- NONE like every other float; active row = blue bold underline.
          Pmenu = { bg = 'NONE', fg = c.text },
          PmenuSel = { bg = 'NONE', fg = c.blue, bold = true, underline = true },
          PmenuMatchSel = { bg = 'NONE', fg = c.blue, bold = true },
          PmenuKindSel = { bg = 'NONE', fg = c.blue, bold = true },
          PmenuExtraSel = { bg = 'NONE', fg = c.text, bold = true },
          PmenuSbar = { bg = 'NONE' },
          PmenuThumb = { bg = c.blue },

          -- blink.cmp overlays: FULL TRANSPARENCY — body NONE so the menu
          -- floats directly over the wallpaper; active row = underline.
          BlinkCmpMenu = { bg = 'NONE', fg = c.text },
          -- border bg pinned to transparent so the rounded corners read as
          -- clean curves over the wallpaper
          BlinkCmpMenuBorder = { fg = rim, bg = 'NONE' },
          BlinkCmpMenuSelection = {
            bg = 'NONE',
            fg = c.blue,
            bold = true,
            underline = true,
          },
          BlinkCmpScrollBarThumb = { bg = c.blue },
          BlinkCmpScrollBarGutter = { bg = 'NONE' },
          BlinkCmpLabel = { fg = c.text },
          BlinkCmpLabelMatch = { fg = c.blue, bold = true },
          BlinkCmpLabelDetail = { fg = c.overlay1 },
          BlinkCmpDoc = { bg = 'NONE' },
          BlinkCmpDocBorder = { fg = rim, bg = 'NONE' },
          BlinkCmpSignatureHelp = { bg = 'NONE' },
          BlinkCmpSignatureHelpBorder = { fg = rim, bg = 'NONE' },
          BlinkCmpGhostText = { fg = c.overlay0 },
          BlinkCmpKindFunction = { fg = c.blue },
          BlinkCmpKindMethod = { fg = c.blue },
          BlinkCmpKindVariable = { fg = c.red },
          BlinkCmpKindConstant = { fg = c.yellow },
          BlinkCmpKindClass = { fg = c.yellow },
          BlinkCmpKindKeyword = { fg = c.mauve },
          BlinkCmpKindSnippet = { fg = c.green },
          BlinkCmpKindText = { fg = c.subtext0 },
          BlinkCmpKindProperty = { fg = c.subtext0 },

          -- contrast polish — underline/fg based, no filled boxes (full
          -- transparency: wallpaper visible through everything)
          Search = { bg = 'NONE', fg = c.blue, bold = true, underline = true },
          CurSearch = {
            bg = 'NONE',
            fg = c.yellow,
            bold = true,
            underline = true,
          },
          Visual = { bg = 'NONE', fg = c.text, bold = true },
          MatchParen = {
            bg = 'NONE',
            fg = c.blue,
            bold = true,
            underline = true,
          },
          IncSearch = {
            bg = 'NONE',
            fg = c.peach,
            bold = true,
            underline = true,
          },
          WinSeparator = { fg = c.surface1 },

          -- Active line: NO bg (full transparency) — the cursor row is
          -- marked by the blue bold line number alone.
          CursorLine = { bg = 'NONE' },
          CursorLineNr = { fg = c.blue, bold = true },

          -- Floating windows (hover, diagnostics popup, dressing, which-key):
          -- fully transparent body — the wallpaper shows through, with the
          -- luminous blue-tinted rim so the rounded edges read as colored
          -- glass, not a gray line. winblend (options.lua) frosts the rest.
          FloatBorder = { fg = rim, bg = 'NONE' },
          FloatTitle = { fg = c.blue, bg = 'NONE' },
          NormalFloat = { bg = 'NONE', fg = c.text },

          -- Treesitter context: transparent header with muted separator line
          TreesitterContext = { bg = 'NONE' },
          TreesitterContextLineNumber = {
            fg = c.blue,
            bold = true,
            bg = 'NONE',
          },
          TreesitterContextSeparator = { fg = c.surface1, bg = 'NONE' },

          -- Diagnostics: undercurl with live palette colors
          DiagnosticUnderlineError = { undercurl = true, sp = c.red },
          DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow },
          DiagnosticUnderlineInfo = { undercurl = true, sp = c.blue },
          DiagnosticUnderlineHint = { undercurl = true, sp = c.teal },

          -- Todo / notes: bright accent
          Todo = { fg = c.yellow, bold = true },

          -- Inlay hints: soft muted text, no background fill
          LspInlayHint = { fg = c.overlay0, bg = 'NONE', italic = true },

          -- -----------------------------------------------------------------
          -- Snacks picker — the single picker (telescope removed)
          -- -----------------------------------------------------------------
          SnacksPickerSelected = {
            bg = 'NONE',
            fg = c.blue,
            bold = true,
            underline = true,
          },
          SnacksPickerMatch = { fg = c.blue, bold = true },
          SnacksPickerPrompt = { fg = c.flamingo },
          SnacksPickerTitle = { fg = c.blue, bg = 'NONE' },
          SnacksPickerInputTitle = { fg = c.blue, bg = 'NONE' },
          SnacksPickerListTitle = { fg = c.lavender, bg = 'NONE' },
          SnacksPickerPreviewTitle = { fg = c.green, bg = 'NONE' },

          -- -----------------------------------------------------------------
          -- Notifications — accent-colored text, transparent body
          -- -----------------------------------------------------------------
          -- Notifications — accent-colored text, transparent body
          SnacksNotifierInfo = { fg = c.blue },
          SnacksNotifierWarn = { fg = c.yellow },
          SnacksNotifierError = { fg = c.red },
          SnacksNotifierDebug = { fg = c.peach },
          SnacksNotifierTrace = { fg = c.rosewater },

          -- -----------------------------------------------------------------
          -- Octo — GitHub issues/PRs/discussions (gh CLI backend)
          -- -----------------------------------------------------------------
          -- Octo's semantic colors map onto the wallpaper palette: status
          -- dots, timeline markers, and merge-state chips all re-tint when
          -- the wallpaper changes (catppuccin re-applies this table).
          OctoWhite = { fg = c.text },
          OctoGrey = { fg = c.overlay1 },
          OctoBlack = { fg = c.base },
          OctoRed = { fg = c.red },
          OctoDarkRed = { fg = darken(c.red) },
          OctoGreen = { fg = c.green },
          OctoDarkGreen = { fg = darken(c.green) },
          OctoYellow = { fg = c.yellow },
          OctoDarkYellow = { fg = darken(c.yellow) },
          OctoBlue = { fg = c.blue },
          OctoDarkBlue = { fg = darken(c.blue) },
          OctoPurple = { fg = c.mauve },
          -- merge-state chips: filled pills (text flips to the surface color)
          OctoStateOpen = { fg = c.base, bg = c.green },
          OctoStateClosed = { fg = c.base, bg = c.red },
          OctoStateMerged = { fg = c.base, bg = c.mauve },
        }
      end,
    },
  }
end

-- ---------------------------------------------------------------------------
-- Terminal query + live update
-- ---------------------------------------------------------------------------
local function query()
  local q = {}
  for i = 0, 15 do
    q[#q + 1] = string.format('\027]4;%d;?\027\\', i)
  end
  -- fg (OSC 10) and bg (OSC 11)
  q[#q + 1] = '\027]10;?\027\\\027]11;?\027\\'
  pcall(vim.api.nvim_ui_send, table.concat(q))
end

local host_terminal

-- Re-run theme setup + colorscheme with the current profile and palette.
-- Under Kitty: uses Nightfox theme.
-- Under WezTerm: uses Catppuccin with live wallpaper overrides.
local function apply()
  local host = host_terminal()
  if host == 'kitty' then
    local ok, err = pcall(function()
      local ok_nf, nightfox = pcall(require, 'nightfox')
      if ok_nf and nightfox then
        nightfox.setup {
          options = {
            transparent = true,
            terminal_colors = true,
            dim_inactive = false,
            styles = {
              comments = 'italic',
              keywords = 'bold',
              types = 'italic,bold',
            },
          },
        }
        vim.cmd.colorscheme 'nightfox'
        require('plugins.ui.hierarchy').apply()
      else
        local opts = catppuccin_opts()
        require('catppuccin').setup(opts)
        vim.cmd.colorscheme 'catppuccin'
        require('plugins.ui.hierarchy').apply()
      end
    end)
    if not ok then
      vim.notify(
        'terminal-colors (kitty): ' .. tostring(err),
        vim.log.levels.ERROR
      )
    end
    return
  end

  local opts = catppuccin_opts()
  local ok, err = pcall(function()
    require('catppuccin').setup(opts)
    vim.cmd.colorscheme 'catppuccin'
    -- Hierarchy rides on the SAME re-tint. It was its own lazy spec once and
    -- that was the bug: two specs naming one plugin cannot agree on `dir`
    -- (this file renames it to 'catppuccin', a bare 'catppuccin/nvim' resolves
    -- to lazy/nvim) and lazy rejects the second with "Plugin changed dir". One
    -- owner for the palette; the hierarchy is just the last step of it.
    require('plugins.ui.hierarchy').apply()
  end)
  if not ok then
    vim.notify('terminal-colors: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

local apply_timer
local function schedule_apply()
  if apply_timer then
    apply_timer:stop()
  else
    apply_timer = vim.uv.new_timer()
  end
  -- debounce: kitty/wezterm answer the 18 queries in a burst. The timer
  -- callback can fire inside vim.wait() (a fast event context) where
  -- vim.notify/snacks would crash — defer via vim.schedule to a normal
  -- context before touching catppuccin or any UI.
  apply_timer:start(40, 0, function()
    vim.schedule(apply)
  end)
end

-- A single TermResponse event may carry several OSC responses back-to-back
-- (kitty/wezterm can batch them), so parse every `ESC ] N ; ...` response in
-- order. Returns true when at least one color was newly captured.
local function parse_sequences(seq)
  local changed = false
  for body in seq:gmatch '\027%]([^\027\x07]+)' do
    -- body is "N;spec" (e.g. "4;1;rgb:..." or "11;rgb:...")
    local num, spec = body:match '^(%d+);(.*)$'
    if num and spec then
      if num == '4' then
        local idx, colorspec = spec:match '^(%d+);(.*)$'
        local hex = idx and parse_color(colorspec)
        if hex then
          idx = tonumber(idx)
          if idx >= 0 and idx <= 15 and pal.ansi[idx] ~= hex then
            pal.ansi[idx] = hex
            changed = true
          end
        end
      elseif num == '10' then
        local hex = parse_color(spec)
        if hex and pal.fg ~= hex then
          pal.fg = hex
          changed = true
        end
      elseif num == '11' then
        local hex = parse_color(spec)
        if hex and pal.bg ~= hex then
          pal.bg = hex
          changed = true
        end
      end
    end
  end
  return changed
end

local function on_termresponse(ev)
  local seq = ev.data.sequence or ''
  if parse_sequences(seq) and complete() then
    schedule_apply()
  end
end

-- ---------------------------------------------------------------------------
-- Fallback source: the terminal's own config file
-- ---------------------------------------------------------------------------
-- OSC queries only reach the terminal when nvim is DIRECTLY attached to it.
-- Under tmux (this setup's normal case) tmux eats the queries and answers
-- nothing, so OSC adoption silently fails. Both kitty and wezterm keep their
-- palette in a config file on disk (ml4w writes them on theme switch), so
-- read the ACTIVE terminal's file as the authoritative fallback — works
-- inside tmux and updates when the file changes.

local palette_file = nil -- resolved palette file once found

-- Follow `include` lines in a kitty config file. Returns a list of
-- { path, content } pairs for every file in the chain (resolved relative
-- to the kitty config dir).
local function read_kitty_with_includes(path, depth)
  depth = depth or 0
  if depth > 4 then
    return {}
  end
  local f = io.open(path, 'r')
  if not f then
    return {}
  end
  local content = f:read '*a'
  f:close()
  local out = { { path = path, content = content } }
  for line in content:gmatch '[^\n]+' do
    local inc = line:match '^%s*include%s+([^%s]+)'
    if inc then
      local incpath = inc:gsub('%$HOME', vim.env.HOME or '')
      if not vim.startswith(incpath, '/') then
        incpath = vim.fs.dirname(path) .. '/' .. incpath
      end
      local sub = read_kitty_with_includes(incpath, depth + 1)
      for _, s in ipairs(sub) do
        out[#out + 1] = s
      end
    end
  end
  return out
end

-- Parse kitty color directives (color0..color15, foreground, background) into
-- pal. Returns true when the 16 ANSI colors were all found. Tracks the file
-- that supplied the colors so the live watcher can poll it (ml4w re-writes
-- colors-matugen.conf on theme switch).
local function read_kitty_palette()
  local home = vim.env.HOME or ''
  local conf = home .. '/.config/kitty/kitty.conf'
  local files = read_kitty_with_includes(conf)
  if #files == 0 then
    return false
  end

  local found = {}
  for _, file in ipairs(files) do
    for line in file.content:gmatch '[^\n]+' do
      -- skip /* */ block comments and # comments
      local key, val = line:match '^%s*([%w_]+)%s+(#[%x]+)'
      if key and val and not line:match '^%s*/%*' then
        local hex = val:match '^#(%x%x%x%x%x%x)$'
        if hex then
          hex = '#' .. hex
          local idx = key:match '^color(%d+)$'
          if idx then
            idx = tonumber(idx)
            if idx >= 0 and idx <= 15 then
              pal.ansi[idx] = hex
              found[idx] = true
              palette_file = file.path
            end
          elseif key == 'foreground' then
            pal.fg = hex
          elseif key == 'background' then
            pal.bg = hex
          end
        end
      end
    end
  end
  for i = 0, 15 do
    if not found[i] then
      return false
    end
  end
  return true
end

-- Parse wezterm's colorscheme file (~/.config/wezterm/colors/*.lua — ml4w
-- writes colors/custom.lua). It's a Lua table `colorscheme` with `ansi` and
-- `brights` arrays + foreground/background, so load and read it. Returns true
-- when the 16 ANSI colors were all found.
local function read_wezterm_palette()
  local home = vim.env.HOME or ''
  local conf = home .. '/.config/wezterm/colors/custom.lua'
  local f = io.open(conf, 'r')
  if not f then
    return false
  end
  local src = f:read '*a'
  f:close()

  -- custom.lua starts with `local wezterm = require('wezterm')` and builds its
  -- palette path from `wezterm.config_dir`. Outside wezterm that require
  -- ALWAYS fails, so this read returned false on every call and nvim silently
  -- fell through to kitty's file — a different wallpaper, from a different
  -- cascade — while the tmux bar and the chrome around it wore the wezterm
  -- palette. That is the "colours get loose" bug: one colour source for the
  -- stack, another for the editor, and no error anywhere to say so.
  --
  -- The fix is the same stub utils/kitty-palette.sh already uses to read the
  -- resolved ANSI slots out of this exact file. It is only ever consulted for
  -- config_dir/home_dir, so a two-field table is a faithful stand-in, and the
  -- values that come back are the terminal's REAL slots — after the
  -- readability guard, after brights are derived, with primary already mapped
  -- into ANSI blue.
  local stub_dir = home .. '/.config/wezterm'
  local had_preload = package.preload['wezterm']
  package.preload['wezterm'] = function()
    return { config_dir = stub_dir, home_dir = home }
  end
  local fn, err = loadstring(src)
  if not fn then
    package.preload['wezterm'] = had_preload
    vim.notify(
      'terminal-colors: wezterm palette parse: ' .. tostring(err),
      vim.log.levels.WARN
    )
    return false
  end
  local ok, cs = pcall(fn)
  -- Restore unconditionally and before any early return: leaving the stub in
  -- package.preload would make every later `require('wezterm')` in this nvim
  -- resolve to a table instead of raising, which is a much harder bug to find
  -- than the one it fixes.
  package.preload['wezterm'] = had_preload
  if not ok or type(cs) ~= 'table' or not cs.ansi then
    return false
  end

  local found = {}
  local function set(i, hex)
    if type(hex) == 'string' and hex:match '^#[%x][%x][%x][%x][%x][%x]$' then
      pal.ansi[i] = hex
      found[i] = true
      palette_file = conf
    end
  end
  for i = 0, 7 do
    set(i, cs.ansi[i + 1]) -- ansi[1..8] are colors 0..7
  end
  for i = 8, 15 do
    set(i, cs.brights and cs.brights[i - 7]) -- brights[1..8] are colors 8..15
  end
  if type(cs.foreground) == 'string' then
    pal.fg = cs.foreground
  end
  if type(cs.background) == 'string' then
    pal.bg = cs.background
  end
  for i = 0, 15 do
    if not found[i] then
      return false
    end
  end
  return true
end

-- Which terminal is nvim running inside? Inside tmux the OSC query path is
-- dead, so use the explicit terminal profile or legacy emulator markers,
-- which survive the tmux boundary. Both kitty and WezTerm adopt the same
-- wallpaper palette; unknown profiles stay on stock Catppuccin.
host_terminal = function()
  local profile = os.getenv 'TERMINAL_STACK_PROFILE'
  local wez_pane = os.getenv 'WEZTERM_PANE'
  local kitty_id = os.getenv 'KITTY_WINDOW_ID'

  -- If running inside tmux, inspect tmux environment and attached clients.
  -- 1. Check pane environment or query tmux global environment if profile was not inherited.
  -- 2. Inspect the attached client's terminal type: reflects the terminal the human is looking at right now.
  if os.getenv 'TMUX' then
    if not profile then
      local h_prof =
        io.popen 'tmux show-environment -g TERMINAL_STACK_PROFILE 2>/dev/null'
      if h_prof then
        local p_out = h_prof:read '*a' or ''
        h_prof:close()
        local match_p = p_out:match '^TERMINAL_STACK_PROFILE=([%w_-]+)'
        if match_p then
          profile = match_p
        end
      end
    end

    if profile ~= nil or wez_pane ~= nil or kitty_id ~= nil then
      local handle =
        io.popen 'tmux display-message -p "#{client_termtype}" 2>/dev/null'
      local client = ''
      if handle then
        client = handle:read '*a' or ''
        handle:close()
      end
      client = client:gsub('%s+', '')
      if client == '' then
        local h2 =
          io.popen 'tmux list-clients -F "#{client_termtype}" 2>/dev/null'
        if h2 then
          client = h2:read '*a' or ''
          h2:close()
          client = client:gsub('%s+', '')
        end
      end
      if client:lower():match 'wezterm' then
        return 'wezterm'
      elseif client:lower():match 'kitty' then
        return 'kitty'
      end
    end
  end

  if profile then
    if profile == 'kitty' or profile == 'wezterm' then
      return profile
    end
    return nil
  end
  if
    wez_pane
    or os.getenv 'WEZTERM_EXECUTABLE'
    or os.getenv 'TERM_PROGRAM' == 'WezTerm'
  then
    return 'wezterm'
  end
  if kitty_id then
    return 'kitty'
  end
  return nil
end

-- Read the wallpaper palette that drives the stack:
-- - WezTerm uses the dev stack's custom wallpaper cascade (~/.config/wezterm/colors/custom.lua).
-- - Kitty (daily driver) uses ML4W's palette (~/.config/kitty/colors-matugen.conf).
-- Fallback resolves wezterm then kitty so standalone sessions inherit wallpaper colors.
local function read_terminal_palette()
  local host = host_terminal()
  if host == 'wezterm' then
    return read_wezterm_palette()
  end
  if host == 'kitty' then
    return read_kitty_palette()
  end
  return false
end

-- Re-read the palette file and report whether any color changed — the 16
-- ANSI colors plus fg/bg (a theme switch may alter only the background).
local function poll_palette_file()
  local before_ansi = vim.deepcopy(pal.ansi)
  local before_fg, before_bg = pal.fg, pal.bg
  local ok = read_terminal_palette()
  if not ok then
    -- Roll back a PARTIAL read. Both readers assign into `pal` slot by slot
    -- and report failure when one is missing — a matugen write caught
    -- mid-flight, a file swapped under us, a slot that fails to parse. Left in
    -- place, that half-populated palette becomes the next read's "before"
    -- state, so the following successful read can decide nothing changed and
    -- never re-tint: the editor keeps a mix of two wallpapers until nvim
    -- restarts. Restoring the snapshot makes a failed read a true no-op.
    pal.ansi, pal.fg, pal.bg = before_ansi, before_fg, before_bg
    return false
  end
  if pal.fg ~= before_fg or pal.bg ~= before_bg then
    return true
  end
  for i = 0, 15 do
    if pal.ansi[i] ~= before_ansi[i] then
      return true
    end
  end
  return false
end

-- Debounced re-read of the palette file after a filesystem change: the
-- wallpaper sync may rewrite the palette in a burst, so collapse events
-- within ~200ms, then re-read and re-tint once (no-op when colors unchanged).
local refresh_timer
local function refresh_from_file()
  if refresh_timer then
    refresh_timer:stop()
  else
    refresh_timer = vim.uv.new_timer()
  end
  refresh_timer:start(
    200,
    0,
    vim.schedule_wrap(function()
      if poll_palette_file() and complete() then
        apply()
      end
    end)
  )
end

-- Live palette updates when OSC is dead (inside tmux, or over ssh where no
-- terminal answers queries): watch the palette FILE instead of waiting out a
-- poll interval. An fs event fires the instant the wallpaper sync rewrites
-- the palette, so nvim re-tints ~instantly instead of up to 3s later.
-- A slow poll is kept as a safety net for sources that miss fs events
-- (e.g. atomic renames that some watchers don't surface).
local watch_timer
local watch_handles = {}

-- Watch every directory a palette can appear in. Two reasons this is a list
-- and not the single `palette_file` dir it used to be:
--
--   * the file that actually CHANGES is colors/matugen.lua, not the
--     custom.lua whose dir was being watched. They happen to share a
--     directory today, so this worked by luck rather than by design.
--   * when neither read succeeded at startup, `palette_file` was nil, the
--     watcher returned early, and nvim went the REST OF THE SESSION with no
--     file watch at all — only the 3s poll and a focus event could revive it.
--     A first paint that fails now still gets live updates once a palette
--     lands on disk.
local function start_palette_watch()
  if watch_timer then
    return
  end

  watch_timer = vim.uv.new_timer()
  watch_timer:start(
    3000,
    3000,
    vim.schedule_wrap(function()
      if poll_palette_file() and complete() then
        apply()
      end
    end)
  )

  local home = vim.env.HOME or ''
  local seen = {}
  local function watch_dir(dir)
    if not dir or dir == '' or seen[dir] then
      return
    end
    seen[dir] = true
    -- fs_stat first: watching a directory that does not exist returns an
    -- error through the callback on every event, which is noise, not a signal.
    if not vim.uv.fs_stat(dir) then
      return
    end
    local handle = vim.uv.new_fs_event()
    if not handle then
      return
    end
    local ok_start = handle:start(
      dir,
      {},
      vim.schedule_wrap(function(err2)
        if err2 then
          return
        end
        refresh_from_file()
      end)
    )
    if ok_start then
      watch_handles[#watch_handles + 1] = handle
    else
      handle:close()
    end
  end

  -- The dir of whatever file answered, so the host terminal's own source is
  -- covered even when it is not one of the two well-known paths.
  watch_dir(vim.fs.dirname(palette_file or ''))
  -- The cascade's write target (matugen.lua lands here).
  watch_dir(home .. '/.config/wezterm/colors')
  -- ml4w's desktop path for kitty.
  watch_dir(home .. '/.config/kitty')
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------
local augroup
local function setup()
  augroup = vim.api.nvim_create_augroup('terminal-colors', { clear = true })
  vim.api.nvim_create_autocmd('TermResponse', {
    group = augroup,
    callback = on_termresponse,
  })

  local host = host_terminal()

  -- Both WezTerm and Kitty adopt the shared wallpaper palette.
  -- Unknown profiles stay on stock Catppuccin mocha without querying a guessed source.
  if host == 'wezterm' or host == 'kitty' then
    -- Read the terminal's config file FIRST (fast, works inside tmux) so the
    -- very first paint already uses the terminal palette — the editor never
    -- flashes stock mocha at boot. ml4w keeps the palette in these files, so
    -- this is the authoritative source even before OSC answers. Goes through
    -- the polling reader so a half-written file rolls back instead of seeding
    -- the session with a partial palette.
    poll_palette_file()

    -- Paint immediately with whatever we have: the terminal palette when the
    -- file read above succeeded, stock mocha as a last resort.
    apply()
    query()

    -- Direct-terminal case: OSC answers refine/confirm the palette within ~300ms.
    -- If the file read already filled everything, complete() is true and this
    -- returns immediately (no boot delay).
    vim.wait(300, complete, 5)
    if complete() then
      apply()
    end

    -- Live updates: kitty/wezterm push OSC 4 to the app when the terminal
    -- colorscheme changes (caught by on_termresponse). Under tmux OSC is dead,
    -- so poll the terminal's palette file instead. Re-query on focus too, in
    -- case the palette changed while nvim was unfocused.
    start_palette_watch()
  else
    -- Unknown profiles: stock Catppuccin mocha, no adoption.
    apply()
  end

  vim.api.nvim_create_autocmd('FocusGained', {
    group = augroup,
    callback = function()
      host = host_terminal()
      if host ~= 'wezterm' and host ~= 'kitty' then
        return
      end
      vim.schedule(function()
        query()
        -- also re-read the palette file (covers tmux where OSC is dead)
        if poll_palette_file() and complete() then
          schedule_apply()
        end
        if not watch_timer then
          start_palette_watch()
        end
      end)
    end,
  })
end

local function reassert()
  poll_palette_file()
  apply()
  if not watch_timer then
    start_palette_watch()
  end
end

M.setup = setup
-- Re-assert the current palette. Exposed for external cascades (sync-wallpaper.sh)
-- and plugins that define their own highlight groups at setup time (Octo).
-- Re-reads the palette file from disk, recompiles catppuccin options, and
-- applies all highlight overrides live.
M.reassert = reassert
M.read_kitty_palette = read_kitty_palette

-- Publish M where a caller can actually reach it.
--
-- A lazy.nvim spec file has to RETURN the spec (below), so this module cannot
-- also return M. octo.lua required `plugins.ui.terminal-colors` and tested
-- `type(tc.reassert) == 'function'` — it got the spec table, so that test was
-- always false and Octo's stock Octo* groups were never re-themed by our
-- palette. The call looked present, guarded and correct, and never ran.
--
-- The spec return is untouched; the API lives under its own module name.
package.loaded['utils.terminal-colors'] = M

-- ---------------------------------------------------------------------------
-- lazy.nvim spec
-- ---------------------------------------------------------------------------
return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = false,
    priority = 1000,
    config = function()
      setup()
    end,
  },
  {
    'EdenEast/nightfox.nvim',
    name = 'nightfox',
    lazy = false,
    priority = 1000,
  },
}
