local Config = require('config')

require('utils.backdrops')
   :set_images_dir(require('wezterm').home_dir .. '/Pictures/wallpaper/')
   :scan_images_dir()
   :exclude_files({
      'wallhaven-x1elzo_1920x1080.png',
      'Generated Image September 16, 2025 - 11_32PM.png',
   })
   :from_cache_or_random()

-- events.fail writes a load marker as its first statement and removes it at
-- the very end of wezterm.lua, once every module has resolved. If a require
-- below dies, the marker survives and scripts/check-config.sh says the config
-- did not load. First and last are both load-bearing: move this require down
-- and it no longer covers the requires above it.
require('events.fail').setup()

require('events.left-status').setup()
require('events.right-status').setup({ date_format = '%a %d %b', time_format = '%H:%M' })
require('events.tab-title').setup({
   hide_active_tab_unseen = true,
   unseen_icon = 'numbered_box',
   show_progress = true,
})
require('events.new-tab-button').setup()
require('events.gui-startup').setup()

local config = Config:init()
   :append(require('config.appearance'))
   -- Border removed 2026-09-27. config/border.lua is a tombstone now, not a
   -- module: it carries window_decorations = 'TITLE' and is deliberately NOT
   -- appended here. Do not append it -- Config:append is first-wins, so
   -- appending it ahead of config.appearance puts the titlebar straight back
   -- with a clean diff and only a log_warn. To bring the accent rule back,
   -- write it into config/appearance.lua, which owns the key. See
   -- tests/check_border.lua, which asserts on the value rather than the
   -- filename.
   --
   -- Hyprland's side is already borderless: `wezterm-noborder` in
   -- ~/.config/ml4w/hypr/custom.lua sets border_size = 0 for this class, so
   -- nothing draws a perimeter around the window. what was left was
   -- wezterm's own titlebar and nothing else.
   :append(require('config.bindings'))
   :append(require('config.domains'))
   :append(require('config.fonts'))
   :append(require('config.general'))
   :append(require('config.launch')).options

-- Last statement. Every module above resolved and the table is built, so the
-- config loaded. Anything that fails after this point has already broken the
-- window, which is a different problem with a different symptom.
require('events.fail').loaded()

return config
