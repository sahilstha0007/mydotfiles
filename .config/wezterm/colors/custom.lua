-- Static Apple Dark Glass colorscheme (committed). Every hex comes from
-- ~/.config/kitty/themes/apple-glass.conf; nothing is derived from a wallpaper
-- or from matugen. This is the single source for wezterm chrome and the tokens
-- in utils/tokens.lua (status bars, tab pills, pane-select chips).
-- stylua: ignore

return {
   foreground = '#f5f5f7',
   background = '#1c1c1e',

   cursor_bg = '#2dd4bf',
   cursor_border = '#2dd4bf',
   cursor_fg = '#1c1c1e',

   selection_bg = '#2dd4bf',
   selection_fg = '#ffffff',

   -- ANSI slots: color0..color7 from apple-glass.conf, in wezterm order.
   ansi = {
      '#3a3a3c', -- black
      '#ff6b6b', -- red
      '#7dce8b', -- green
      '#f2d97a', -- yellow
      '#2dd4bf', -- blue (accent)
      '#cba6f0', -- magenta
      '#64d2ff', -- cyan
      '#ebebf5', -- white
   },
   -- Bright slots: color8..color15 from apple-glass.conf.
   brights = {
      '#6e6e73',
      '#ff8a80',
      '#a3e5ae',
      '#f7e6a3',
      '#5eead4',
      '#dcb8f5',
      '#9fdcf5',
      '#f5f5f7',
   },

   tab_bar = {
      background = '#1c1c1e',
      active_tab = { bg_color = '#2dd4bf', fg_color = '#ffffff' },
      inactive_tab = { bg_color = '#2c2c2e', fg_color = '#a1a1a6' },
      inactive_tab_hover = { bg_color = '#3a3a3c', fg_color = '#ebebf5' },
      new_tab = { bg_color = '#1c1c1e', fg_color = '#f5f5f7' },
      new_tab_hover = { bg_color = '#2c2c2e', fg_color = '#f5f5f7', italic = true },
   },

   visual_bell = '#ff9f0a',
   indexed = {
      [16] = '#ff9f0a',
      [17] = '#ff375f',
   },
   scrollbar_thumb = '#2dd4bf',
   split = '#3a3a3c',
   compose_cursor = '#2dd4bf',

   -- ColorSpec tables are required for quick_select_* on this wezterm version.
   quick_select_label_bg = { Color = '#2c2c2e' },
   quick_select_label_fg = { Color = '#f5f5f7' },
   quick_select_match_bg = { Color = '#f2d97a' },
   quick_select_match_fg = { Color = '#1c1c1e' },
}
