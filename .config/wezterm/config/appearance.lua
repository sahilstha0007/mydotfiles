local colors = require('colors.custom')
local wezterm = require('wezterm')

---@type Config
return {
   max_fps = 120, -- high-refresh 120Hz cap for fluid scrolling & animations
   front_end = 'WebGpu', ---@type 'WebGpu' | 'OpenGL' | 'Software'
   -- LowPower power preference: uses efficient integrated GPU, eliminating continuous battery drain
   webgpu_power_preference = 'LowPower',
   -- Battery fallback: on laptops, flip to LowPower when on battery to reduce
   -- power draw. The Vega iGPU is fast enough at LowPower for a terminal;
   -- the tradeoff is slightly lower clocks, which is invisible at 60fps.
   -- Uncomment the block below to enable. Requires platform.is_battery()
   -- (add to utils/platform.lua) or an env var check.
   --
   -- if platform.is_linux and os.execute('on_ac_power 2>/dev/null || exit 1') == 0 then
   --    webgpu_power_preference = 'HighPerformance'
   -- else
   --    webgpu_power_preference = 'LowPower'
   -- end
   -- GPU adapter is left to wezterm's own selection. The explicit
   -- enumerate_gpus() probe cost ~55ms at every config load.
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 120, -- high-refresh cursor animation
   default_cursor_style = 'SteadyBar',
   cursor_blink_rate = 0,
   cursor_blink_ease_in = 'EaseInOut',
   cursor_blink_ease_out = 'EaseInOut',

   -- color scheme
   colors = colors,

   -- pane-select overlay (SUPER+CTRL+p): the number chips reuse the active
   -- tab language — wallpaper-synced accent pill (colorscheme ansi[5], same
   -- token the custom tab bar and tmux pill use). The label follows the
   -- theme: accent is bright on dark wallpapers (dark label) but dark on
   -- light wallpapers (light label = colors.background), so it can never
   -- paint dark-on-dark or light-on-light.
   pane_select_fg_color = colors.background,
   pane_select_bg_color = colors.ansi[5],

   -- Solid background: no backdrop image, no window alpha. colors.background
   -- is the default terminal bg and wezterm defaults to 1.0 opacity.
   -- Edge layers (image, wash, opacity) were stripped to cut config load time.

   -- scrollbar (disabled for clean, distraction-free zero-mouse keyboard terminal)
   enable_scroll_bar = false,

   -- tab bar
   enable_tab_bar = true,
   -- MUST stay false: the right-status readout and the contextual HUD
   -- (events/hud.lua — key-table badge, remote-host alarm) are painted INTO
   -- this bar. WezTerm has no other surface for a right status, so hiding the
   -- bar with a single tab open makes both invisible. That is not a cosmetic
   -- regression; the HUD cannot render anywhere else. The bar also carries tab
   -- titles / progress / unseen-count, which only cost one line.
   hide_tab_bar_if_only_one_tab = false,
   use_fancy_tab_bar = false,
   tab_max_width = 32,
   switch_to_last_active_tab_when_closing_tab = true,

   -- command palette — adopts the colorscheme (wallpaper-synced) instead of
   -- pinned mocha hexes
   command_palette_fg_color = colors.foreground,
   command_palette_bg_color = colors.background,
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   -- No titlebar, no resize border. This used to live in config/border.lua,
   -- which was removed from the chain in wezterm.lua on 2026-09-27 to kill
   -- the accent rule under the titlebar. Deleting that :append also deleted
   -- the ONLY place `window_decorations` was set, so the key silently fell
   -- back to its default, 'TITLE | RESIZE' — which draws a titlebar AND a
   -- resize border, the opposite of the intent. The key therefore has to be
   -- set here, where it is a plain appearance setting.
   --
   -- 'RESIZE' is the flag wezterm's docs say to keep, but this window is
   -- tiled under Hyprland: resize_on_border is a compositor-side interaction
   -- and SUPER+SHIFT+arrows already resize. Dropping it is what makes the
   -- window genuinely borderless. Re-add 'RESIZE' if keyboard resizing stops
   -- working.
   window_decorations = 'NONE',

   window_padding = {
      left = 8,
      right = 8,
      top = 8,
      bottom = 8,
   },
   -- There is no `show_window_title` key in wezterm's Config -- that was an
   -- invented field, and it only ever produced a startup warning. With
   -- `window_decorations = 'NONE'` no in-window titlebar is drawn, while the
   -- `format-window-title` event at the bottom of this file still provides the
   -- active pane title (or `'wezterm'`) for Wayland/Hyprland overviews.

   adjust_window_size_when_changing_font_size = false,
   use_resize_increments = true,
   window_close_confirmation = 'NeverPrompt',
   -- Subtle dimming on inactive panes so active focus pops without hiding the wallpaper
   inactive_pane_hsb = {
      saturation = 0.9,
      brightness = 0.85,
   },

   visual_bell = {
      fade_in_function = 'EaseIn',
      fade_in_duration_ms = 250,
      fade_out_function = 'EaseOut',
      fade_out_duration_ms = 250,
      target = 'CursorColor',
   },

   -- Window title formatter for window managers and taskbars.
   -- With window_decorations = 'NONE', no in-window title bar is drawn,
   -- but Wayland compositors (Hyprland), overview menus, and status bars
   -- read this title to identify the window.
   wezterm.on('format-window-title', function(tab)
      if tab and tab.active_pane and tab.active_pane.title and #tab.active_pane.title > 0 then
         return tab.active_pane.title
      end
      return 'wezterm'
   end),
}
