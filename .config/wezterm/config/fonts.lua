local wezterm = require('wezterm')
local platform = require('utils.platform')

-- local font_family = 'Maple Mono NF'
local font_family = 'JetBrainsMono Nerd Font'
-- local font_family = 'CartographCF Nerd Font'

local font_size = platform.is_mac and 12 or 9.75

---@type Config
return {
   -- Primary: the Nerd Font (icons for nvim/tmux status all inherit this).
   -- Fallbacks stop tofu boxes: CJK glyphs land in Noto Sans CJK, emoji in
   -- Noto Color Emoji, and anything else the Nerd Font lacks falls back
   -- before wezterm gives up and draws a box. Missing families are skipped.
   font = wezterm.font_with_fallback({
      { family = font_family, weight = 'Medium' },
      'Noto Sans Mono CJK SC',
      'Noto Sans CJK SC',
      'Noto Sans CJK JP',
      'Noto Color Emoji',
   }),
   font_size = font_size,
   -- Slight vertical breathing room at 9.75pt (wezterm defaults line_height to
   -- 1.0, tight for JetBrainsMono at this size). 1.1 is denser than 1.2 but
   -- easier to scan than the default; A/B with SUPER+k/j if it feels loose.
   line_height = 1.1,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
