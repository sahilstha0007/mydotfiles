-- Battery monitor module for WezTerm status bar.
-- Uses wezterm.battery_info() with state-of-charge clamping and Nerdfont icons.
local wezterm = require('wezterm')
local umath = require('utils.math')

local nf = wezterm.nerdfonts
local M = {}

local discharging_icons = {
   (nf and nf.md_battery_10) or '!',
   (nf and nf.md_battery_20) or '!',
   (nf and nf.md_battery_30) or '=',
   (nf and nf.md_battery_40) or '=',
   (nf and nf.md_battery_50) or '=',
   (nf and nf.md_battery_60) or '=',
   (nf and nf.md_battery_70) or '=',
   (nf and nf.md_battery_80) or '=',
   (nf and nf.md_battery_90) or '=',
   (nf and nf.md_battery) or '#',
}

local charging_icons = {
   (nf and nf.md_battery_charging_10) or '+',
   (nf and nf.md_battery_charging_20) or '+',
   (nf and nf.md_battery_charging_30) or '+',
   (nf and nf.md_battery_charging_40) or '+',
   (nf and nf.md_battery_charging_50) or '+',
   (nf and nf.md_battery_charging_60) or '+',
   (nf and nf.md_battery_charging_70) or '+',
   (nf and nf.md_battery_charging_80) or '+',
   (nf and nf.md_battery_charging_90) or '+',
   (nf and nf.md_battery_charging) or '+#',
}

---Get current battery charge string and status icon
---@return string charge Formatted percentage e.g. "85%" (or "" if no battery)
---@return string icon Nerd font glyph (or "" if no battery)
function M.info()
   local ok, batteries = pcall(wezterm.battery_info)
   if not ok or not batteries or #batteries == 0 then
      return '', ''
   end

   local charge = ''
   local icon = ''

   for _, b in ipairs(batteries) do
      local soc = b.state_of_charge or 0
      local idx = umath.clamp(umath.round(soc * 10), 1, 10)
      charge = string.format('%.0f%%', soc * 100)

      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end

   return charge, icon .. ' '
end

return M
