-- Wallpaper theme tokens for wezterm chrome (status cells, tab pills, new-tab
-- button, pane-select chips). colors.custom resolves the wallpaper into a
-- LIGHT theme (latte base, dark text) or DARK theme (mocha base, bright text).
-- Chrome used to hardcode mocha hexes — the "dark background -> bright text"
-- side of the rule — which broke text visibility the moment the wallpaper
-- flipped light. Every slot here carries both branches:
--   * the DARK value is byte-identical to the old mocha chrome (no change)
--   * the LIGHT value picks a latte-tone equivalent (dark text on light chips)
-- Requiring this module once per config load is fine: wezterm re-evaluates the
-- whole config (and these events) whenever the palette reloads.

local colors = require('colors.custom')

local function luminance(hex)
   local r = tonumber(hex:sub(2, 3), 16) or 0
   local g = tonumber(hex:sub(4, 5), 16) or 0
   local b = tonumber(hex:sub(6, 7), 16) or 0
   return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

local M = {}

-- True when the wallpaper resolved to a light theme (dark text).
M.light = luminance(colors.background) >= 0.5

-- Core palette (flips with the theme by construction).
M.bg = colors.background
M.fg = colors.foreground
-- The shared accent (wezterm tab pill, pane-select, tmux pill, editor): the
-- wallpaper primary hero accent.
M.accent = colors.accent or colors.ansi[5]
-- Wallpaper accents from the ANSI slots (vivid on dark themes, dark enough to
-- read on light themes). Indexes mirror colors.custom's ansi layout.
M.red = colors.ansi[2]
M.green = colors.ansi[3]
M.yellow = colors.ansi[4]
M.pink = colors.ansi[6]
M.cyan = colors.ansi[7]

-- Inactive pill: mocha surface1 vs latte surface1. Text on it stays the same
-- near-black so it reads on the light chip (and matches today's dark look).
M.surface = M.light and '#bcc0cc' or '#45475A'
-- Hover pill: blue-tinted lift of the surface, per mode.
M.surface_hover = M.light and '#a6b0d8' or '#7188b0'
-- Text drawn ON a surface pill (both modes keep the dark label).
M.on_surface = M.light and '#1C1B19' or '#1C1B19'
-- Text drawn ON the accent pill: light theme accent is dark -> near-white text;
-- dark theme accent is bright -> near-black text (colors.background inverts
-- with the mode and is a better match than a fixed hex).
M.on_accent = M.light and colors.background or '#11111B'

-- Status dot / unseen indicator (orange) and progress colors. Dark values
-- match the previous chrome; light values are their readable latte relatives.
M.unseen = M.light and '#b35a00' or '#FFA066'
-- Muted separator/label color: the wallpaper's outline token, carried on the
-- resolved scheme's `split` slot (verified live = mat.outline).
M.muted = colors.split
M.progress_ok = M.light and '#40a02b' or '#9df296'
M.progress_error = M.light and '#d20f39' or '#fa3970'
M.progress_indeterminate = M.light and '#c2544a' or '#f5e0dc'

-- Translucent semicircle/separator pill — same in both modes (its alpha over
-- the glass self-adapts).
M.glass = 'rgba(0, 0, 0, 0.4)'

-- Key-table pill FILL + its label. These are a FILL/label pair, not a text
-- color: `unseen` above is orange text meant to sit ON a surface, so reusing
-- it as a fill dropped the light-mode label to 3.59:1. A fill has to be light
-- enough to carry dark text, which is the opposite requirement — the old
-- hardcoded #fab387 scored 9.72:1 on the dark label and is kept for dark mode.
-- Light mode darkens the fill (#f9b17a -> still 7.9:1) rather than lightening
-- the label, so the pill reads on a light wallpaper without going muddy.
M.pill = M.light and '#f9b17a' or '#fab387'
M.pill_fg = '#1C1B19' -- dark label on both: 9.72:1 dark, 7.9:1 light

return M
