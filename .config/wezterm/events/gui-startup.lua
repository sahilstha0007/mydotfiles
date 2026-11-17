local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()
      -- Wallpaper image cache warming and the post-start palette cascade were
      -- removed with dynamic wallpaper theming. Nothing to sync on startup.
   end)
end

return M
