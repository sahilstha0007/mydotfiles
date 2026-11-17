-- Active theme flavour for plugins that read the theme palette directly
-- (gitsigns, bufferline, lualine-theme, snacks dashboard).
-- When in Kitty: uses Kanagawa palette (wave).
-- When in WezTerm: uses Catppuccin palette (terminal-colors with wallpaper overrides).

local M = {}

--- Active catppuccin flavour, derived from the background direction set by
--- terminal-colors (light background -> 'latte', otherwise 'mocha').
function M.flavour()
  return vim.o.background == 'light' and 'latte' or 'mocha'
end

--- Live theme palette for the active scheme and profile.
function M.palette()
  if vim.g.colors_name == 'kanagawa' then
    local ok, kcolors = pcall(require, 'kanagawa.colors')
    if ok and kcolors then
      local p = kcolors.setup({ theme = 'wave' }).palette
      return {
        base = p.sumiInk3,
        text = p.fujiWhite,
        surface0 = p.sumiInk4,
        surface1 = p.sumiInk5,
        surface2 = p.sumiInk6,
        overlay0 = p.fujiGray,
        overlay1 = p.fujiGray,
        overlay2 = p.springViolet1,
        subtext0 = p.oldWhite,
        subtext1 = p.fujiWhite,
        crust = p.sumiInk0,
        mantle = p.sumiInk1,
        blue = p.crystalBlue,
        green = p.springGreen,
        red = p.autumnRed,
        yellow = p.carpYellow,
        teal = p.waveAqua2,
        sky = p.springBlue,
        sapphire = p.crystalBlue,
        lavender = p.oniViolet2,
        mauve = p.oniViolet,
        peach = p.surimiOrange,
        maroon = p.samuraiRed,
        pink = p.sakuraPink,
        rosewater = p.carpYellow,
        flamingo = p.surimiOrange,
      }
    end
  end
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
