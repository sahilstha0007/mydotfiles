-- Active theme flavour for plugins that read the theme palette directly
-- (gitsigns, bufferline, lualine-theme, snacks dashboard).
-- When in Kitty: uses Nightfox palette.
-- When in WezTerm: uses Catppuccin palette (terminal-colors with wallpaper overrides).

local M = {}

--- Active catppuccin flavour, derived from the background direction set by
--- terminal-colors (light background -> 'latte', otherwise 'mocha').
function M.flavour()
  return vim.o.background == 'light' and 'latte' or 'mocha'
end

--- Live theme palette for the active scheme and profile.
function M.palette()
  if vim.g.colors_name == 'nightfox' then
    local ok, nf_pal = pcall(require, 'nightfox.palette')
    if ok and nf_pal then
      local p = nf_pal.load 'nightfox'
      return {
        base = p.bg1,
        text = p.fg1,
        surface0 = p.bg2,
        surface1 = p.bg3,
        surface2 = p.bg4,
        overlay0 = p.comment,
        overlay1 = p.fg3,
        overlay2 = p.fg2,
        subtext0 = p.fg2,
        subtext1 = p.fg1,
        crust = p.bg0,
        mantle = p.bg0,
        blue = p.blue.base,
        green = p.green.base,
        red = p.red.base,
        yellow = p.yellow.base,
        teal = p.cyan.base,
        sky = p.cyan.bright,
        sapphire = p.blue.bright,
        lavender = p.magenta.bright,
        mauve = p.magenta.base,
        peach = p.orange.base,
        maroon = p.red.bright,
        pink = p.pink.base,
        rosewater = p.orange.bright,
        flamingo = p.orange.base,
      }
    end
  end
  return require('catppuccin.palettes').get_palette(M.flavour())
end

return M
