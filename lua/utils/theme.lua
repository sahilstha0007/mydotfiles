-- Active theme flavour for plugins that read the catppuccin palette directly
-- (gitsigns, bufferline, lualine-theme, snacks dashboard). terminal-colors
-- flips between latte (light wallpaper) and mocha (dark wallpaper) and sets
-- vim.o.background accordingly — every consumer must ask for the SAME flavour
-- or it paints dark-theme hues over a light theme (or vice versa).

local M = {}

--- Active catppuccin flavour, derived from the background direction set by
--- terminal-colors (light background -> 'latte', otherwise 'mocha').
function M.flavour()
  return vim.o.background == 'light' and 'latte' or 'mocha'
end

--- Live catppuccin palette for the active flavour (includes the terminal
--- color_overrides recompiled by terminal-colors on every palette change).
function M.palette()
  return require('catppuccin.palettes').get_palette(M.flavour())
end

return M
