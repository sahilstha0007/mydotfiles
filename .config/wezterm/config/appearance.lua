local gpu_adapters = require('utils.gpu-adapter')
local backdrops = require('utils.backdrops')
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
   webgpu_preferred_adapter = gpu_adapters:pick_best(),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Dx12', 'IntegratedGpu'),
   -- webgpu_preferred_adapter = gpu_adapters:pick_manual('Gl', 'Other'),
   underline_thickness = '1.5pt',

   -- cursor
   animation_fps = 120, -- high-refresh cursor animation
   -- kitty-style blink, but GLIDED: eased on/off (EaseInOut) instead of a
   -- hard toggle — the fade is what reads as smooth. 650ms half-period.
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,
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

   -- background: pass in `true` if you want wezterm to start with focus mode on (no bg images)
   background = backdrops:initial_options({ no_img = false, }),
   -- Baseline window alpha. Read from the BackDrops singleton, which loads
   -- ~/.cache/wezterm-opacity at init (falling back to 1.0 when there is no
   -- cache yet). It has to come from there, not a literal: this is the ONLY
   -- thing that applies opacity to the first window — from_cache_or_random()
   -- runs without a Window and so never calls _apply — so a hardcoded 1.0
   -- here silently discarded the saved choice and every restart came back
   -- solid no matter what the user had set with SUPER+y / SUPER+Shift+y.
   -- 1.0 = solid, lower = fades toward whatever the COMPOSITOR has behind
   -- the window (Hyprland's background, not wezterm's background.image).
   -- awww-daemon is the wallpaper backend here (NOT hyprpaper — ml4w sets
   -- wallpapers through awww, and `awww query` confirms one is set on eDP-1),
   -- so lowering this genuinely reveals the desktop artwork. Artwork alpha
   -- inside the window is a separate lever: the frost wash, SUPER+u. tmux
   -- and nvim have no window-level alpha of their own, so any window-wide
   -- translucency comes from this setting.
   window_background_opacity = backdrops.opacity,

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
   tab_max_width = 23,
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
      left = 0,
      right = 0,
      top = 10,
      bottom = 7.5,
   },
   -- No window title text. There is no `show_window_title` key in wezterm's
   -- Config -- that was an invented field, and it only ever produced a startup
   -- warning. The supported way to blank the title is to make the
   -- format-window-title event return an empty string; see the event at the
   -- bottom of this file.

   adjust_window_size_when_changing_font_size = false,
   use_resize_increments = true,
   window_close_confirmation = 'NeverPrompt',
   -- No dimming on inactive panes/partitions: wallpaper stays uniform and seamless
   inactive_pane_hsb = {
      saturation = 1.0,
      brightness = 1.0,
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
