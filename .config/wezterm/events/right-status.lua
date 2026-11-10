local wezterm = require('wezterm')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')
local tokens = require('utils.tokens')
local battery = require('config.battery')

local nf = wezterm.nerdfonts
local attr = Cells.attr

---@alias Event.RightStatusOptionsInput { date_format?: string, time_format?: string }

---@alias Event.RightStatusOptions { date_format: string, time_format: string }

---Setup options for the right status bar
---@type OptsValidator
local EVENT_OPTS = OptsValidator:new({
   {
      name = 'date_format',
      type = 'string',
      default = '%a %d %b',
   },
   {
      name = 'time_format',
      type = 'string',
      default = '%H:%M:%S',
   },
})

local M = {}

local ICON_SEPARATOR = nf.oct_dash
local ICON_DATE = nf.fa_calendar
local ICON_CPU = nf.md_cpu_64_bit or nf.fa_microchip or 'CPU'
local ICON_MEM = nf.md_memory or nf.fa_memory or 'RAM'
local ICON_CLOCK = nf.md_clock_outline or nf.fa_clock_o or 'T'

---@type table<string, Cells.SegmentColors>
-- Palette-derived (2026-10-10): the segments follow the wallpaper through the
-- same guard()-checked ANSI tokens the tab pills, pane-select chips and tmux
-- pill use, replacing the fixed catppuccin hue pairs that lived here. Those
-- tokens are already WCAG-repaired once in colors/custom.lua — a token that
-- misses 4.5:1 on the resolved background gets its lightness walked toward
-- passing, and only an unrepairable one falls back to the catppuccin base —
-- so the light/dark legibility guarantee the old hex table's comment
-- documented is inherited here, not reimplemented.
--
-- Segment roles: the most-read pair (clock) takes the accent; host/uptime take
-- the secondary/tertiary tokens; battery takes success. On wallpapers where
-- matugen resolves secondary == tertiary (this one), host and uptime share a
-- hue — icon + position keep them apart.
-- ponytail: hue collision on low-diversity wallpapers; add a per-segment
-- lightness ladder in tokens.lua if the bar ever reads ambiguously.
local colors = {
   date      = { fg = tokens.accent, bg = tokens.glass },
   -- host and uptime remain in M.colors because tests/wezterm/check-right-status.lua checks them.
   host      = { fg = tokens.pink,   bg = tokens.glass },
   uptime    = { fg = tokens.muted,  bg = tokens.glass },
   cpu       = { fg = tokens.cyan,   bg = tokens.glass },
   mem       = { fg = tokens.green,  bg = tokens.glass },
   battery   = { fg = tokens.yellow, bg = tokens.glass },
   separator = { fg = tokens.muted,  bg = tokens.glass },
}

-- Exposed for tests/check-right-status.lua, which asserts the derived values
-- without a live window. Read-only by convention.
M.colors = colors

-- The right status owns ONLY the persistent info slab (date / host / uptime /
-- battery / clock). Intelligent signals (key table, remote host, pane command,
-- disk, sync) live in events/hud.lua as pills and are rendered via
-- hud_items() which this module calls. This keeps ONE owner per signal and ONE
-- consistent pill style across all intelligent additions.
--
-- Right side layout, left-to-right:
--   [HUD pills: keytable | remote | command | disk | sync]   date-icon  date  sep  host-icon  host  sep  uptime-icon  uptime  sep  battery-icon  battery  sep  clock-icon  clock
--
-- HUD pills are prepended by hud_items() and only appear when they have
-- something to say, so the bar never bloats with always-on chips.

local cells = Cells:new()

cells
   :add_segment('date_icon', ICON_DATE .. '  ', colors.date, attr(attr.intensity('Bold')))
   :add_segment('date_text', '', colors.date, attr(attr.intensity('Bold')))
   :add_segment('separator', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('cpu_icon', ICON_CPU .. '  ', colors.cpu, attr(attr.intensity('Bold')))
   :add_segment('cpu_text', '', colors.cpu, attr(attr.intensity('Bold')))
   :add_segment('mem_icon', '   ' .. ICON_MEM .. '  ', colors.mem, attr(attr.intensity('Bold')))
   :add_segment('mem_text', '', colors.mem, attr(attr.intensity('Bold')))
   :add_segment('sep_cpu_bat', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('battery_icon', '', colors.battery)
   :add_segment('battery_text', '', colors.battery, attr(attr.intensity('Bold')))
   :add_segment('sep_bat_clock', ' ' .. ICON_SEPARATOR .. '  ', colors.separator)
   :add_segment('clock_icon', ICON_CLOCK .. '  ', colors.separator)
   :add_segment('clock_text', '', colors.date, attr(attr.intensity('Bold')))

local battery_info = battery.info

-- Live system load, read straight from /proc with a short cache so the
-- frequent update-status events never fork a process. CPU is a utilisation
-- delta (idle+iowait vs total, from consecutive samples); memory is
-- MemTotal - MemAvailable. Both are pure file reads, unlike `df` in hud.lua.
---@type { t: number, cpu: string, mem: string, prev_idle: number?, prev_total: number? }
local sys = { t = 0, cpu = '', mem = '' }

---@return string cpu CPU utilisation as `NN%`, or '' before the first delta
---@return string mem Used memory as `N.NG` GiB
local function cpu_mem()
   local now = os.time()
   if sys.t > 0 and (now - sys.t) < 2 then
      return sys.cpu, sys.mem
   end
   sys.t = now

   local f = io.open('/proc/stat', 'r')
   if f then
      local line = f:read('*l') or ''
      f:close()
      local v = {}
      for n in line:gmatch('(%d+)') do
         v[#v + 1] = tonumber(n)
      end
      if #v >= 4 then
         local idle = (v[4] or 0) + (v[5] or 0) -- idle + iowait
         local total = 0
         for i = 1, math.min(#v, 8) do
            total = total + (v[i] or 0)
         end
         if sys.prev_idle and sys.prev_total then
            local d_idle = idle - sys.prev_idle
            local d_total = total - sys.prev_total
            if d_total > 0 then
               local pct = math.floor((1 - d_idle / d_total) * 100 + 0.5)
               sys.cpu = tostring(math.max(0, math.min(100, pct))) .. '%'
            end
         end
         sys.prev_idle, sys.prev_total = idle, total
      end
   end

   local m = io.open('/proc/meminfo', 'r')
   if m then
      local total, avail
      for l in m:lines() do
         total = total or tonumber(l:match('^MemTotal:%s+(%d+)'))
         avail = avail or tonumber(l:match('^MemAvailable:%s+(%d+)'))
         if total and avail then
            break
         end
      end
      m:close()
      if total and avail then
         sys.mem = string.format('%.1fG', (total - avail) / 1024 / 1024)
      end
   end

   return sys.cpu, sys.mem
end

---@param opts? Event.RightStatusOptionsInput Default: {date_format = '%a %H:%M:%S'}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   ---@cast valid_opts Event.RightStatusOptions

   wezterm.on('update-status', function(window, pane)
      local battery_text, battery_icon = battery_info()
      local cpu_text, mem_text = cpu_mem()
      -- Date and clock are DISTINCT segments. They both used to be fed the
      -- same date_format string, so the bar rendered the clock twice and the
      -- date never appeared. date_format now names the date, time_format the
      -- clock.
      local date = wezterm.strftime(valid_opts.date_format)
      local clock = wezterm.strftime(valid_opts.time_format)

      -- Update the persistent info slab. The info slab is ALWAYS visible
      -- (never empty) so the user can always see the right side is alive,
      -- even in idle. The HUD pills (key table, remote, pane command, disk,
      -- sync) are owned by hud.lua and rendered via hud_items() below — they
      -- only appear when they have something to say.
      cells
         :update_segment_text('date_text', date)
         :update_segment_text('cpu_text', cpu_text)
         :update_segment_text('mem_text', mem_text)
         :update_segment_text('battery_icon', battery_icon)
         :update_segment_text('battery_text', battery_text)
         :update_segment_text('clock_text', clock)

      -- Build the render list: persistent slab only. Intelligent signals
      -- (key table, remote, pane command, disk, sync) are owned by hud.lua
      -- and rendered via hud_items() which is called below.
      local render_ids = {
         'date_icon',
         'date_text',
         'separator',
         'cpu_icon',
         'cpu_text',
         'mem_icon',
         'mem_text',
         'sep_cpu_bat',
      }
      if battery_text ~= '' then
         table.insert(render_ids, 'battery_icon')
         table.insert(render_ids, 'battery_text')
         table.insert(render_ids, 'sep_bat_clock')
      end
      table.insert(render_ids, 'clock_icon')
      table.insert(render_ids, 'clock_text')

      -- One wezterm.format over ONE combined FormatItem list: the HUD pills,
      -- then the right-side readout. Formatted separately and joined with
      -- `..` would not work — a formatted string is an opaque escaped token
      -- — and wezterm.concat does not exist in this build. See events/hud.lua.
      local items = require('events.hud').hud_items(window, pane)

      for _, item in ipairs(cells:render(render_ids)) do
         table.insert(items, item)
      end

      window:set_right_status(wezterm.format(items))
   end)

   -- config-file-reloaded handler removed: window:update_status() is not
   -- available in this wezterm build, and the update-status handler already
   -- fires on every focus/pane/title/resize, so the status stays current.
end

return M
