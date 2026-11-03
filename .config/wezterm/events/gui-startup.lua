local wezterm = require('wezterm')
local mux = wezterm.mux

local M = {}

---Read the first line of a file under the home dir, or nil.
---@param rel string e.g. '/.cache/wezterm-wallpaper'
---@return string?
local function read_home(rel)
   local f = io.open(wezterm.home_dir .. rel, 'r')
   if not f then
      return nil
   end
   local s = f:read('*l')
   f:close()
   return s
end

M.setup = function()
   wezterm.on('gui-startup', function(cmd)
      local _, _, window = mux.spawn_window(cmd or {})
      window:gui_window():maximize()

      local backdrops = require('utils.backdrops')

      -- Warm the downscaled display cache in the background so wallpaper
      -- swaps/cycling decode fast from now on (no-op once warm).
      backdrops:ensure_display_cache()

      -- Theme the wallpaper AFTER load, not during it (spawning processes
      -- while the config file is being evaluated is unreliable, so text
      -- colors could lag the displayed image on boot). If the wallpaper we
      -- just showed has never been palette-synced — first boot, or wezterm
      -- quit before the last background sync finished — run the cascade now:
      -- matugen -> tmux tokens -> config reload, so text follows the image.
      local cache = read_home('/.cache/wezterm-wallpaper')
      local synced = read_home('/.cache/wezterm-wallpaper.synced')
      -- .synced only means "already themed" while the palette it produced is
      -- still on disk. Checking the image alone left a deleted or never-written
      -- palette permanently unrecoverable: the image matched, so sync never ran
      -- again and the theme stayed dead across every restart.
      local pal = io.open(wezterm.home_dir .. '/.config/wezterm/colors/matugen.lua', 'r')
      local has_palette = pal ~= nil
      if pal then
         pal:close()
      end
      if cache and (cache ~= synced or not has_palette) then
         backdrops:sync()
      end
   end)
end

return M
