-- Contextual HUD: the extra signals that sit in front of the existing
-- right-status readout (date / user@host / uptime / battery).
--
-- This does NOT replace right-status.lua. That module keeps ownership of the
-- right status and calls hud_prefix() here, then concatenates the two. Two
-- independent update-* handlers both calling set_right_status would race, and
-- the loser would silently win -- so exactly one module may write, and this one
-- only produces a prefix string.
--
-- Two signals, most alarming first:
--
--  1. KEY TABLE badge -- a bright pill naming the key table you are currently
--     inside ("LEADER", "RESIZE_PANE", ...). Without it you can be stranded in
--     a sub-map pressing keys that do nothing. This is the load-bearing piece:
--     it exists because WezTerm exposes window:active_key_table().
--
--  2. REMOTE host badge -- shown ONLY when the pane is on a different machine
--     than the one running WezTerm. wezterm.hostname() is the LOCAL hostname and
--     is useless for this, so the remote name comes from the pane's OSC 1337
--     data, which is what sets over SSH. Invisible locally, loud remotely.
--
-- Styling reuses utils/tokens so the HUD follows the matugen wallpaper palette
-- and survives light/dark flips, the same contract every other chrome module
-- in this config keeps.
--
-- FormatItem shape (the thing that is easy to get wrong -- see utils/cells.lua
-- add_segment for the canonical builder): an item is ONE of
--   { Background = { Color = ... } }
--   { Foreground = { Color = ... } }
--   { Attribute  = { Intensity = ... } }
--   { Text = '...' }
--   'ResetAttributes'
-- It is NOT {fg=,bg=,text=}, NOT {Color=...}, and NOT a bare Lua string in a
-- mixed list. Attributes are stateful and carry forward, so every pill sets,
-- emits, then resets -- otherwise the red bleeds into the date readout.

local wezterm = require('wezterm')
local tokens = require('utils.tokens')
local attr = require('utils.cells').attr

local nf = wezterm.nerdfonts

local M = {}

---One pill as a FormatItem list.
---@param text string
---@param fg string
---@param bg string
---@return FormatItem[]
local function pill(text, fg, bg)
   return {
      { Background = { Color = bg } },
      { Foreground = { Color = fg } },
      attr.intensity('Bold'),
      { Text = '  ' },
      { Text = nf.md_circle_small .. ' ' },
      { Text = text },
      { Text = ' ' },
      'ResetAttributes',
   }
end

---Remote hostname for this pane, or nil when it is the local machine.
---Reads the pane's OSC 1337 data -- the channel an SSH session updates. The
---pcall matters because get_osc_data is not present on every pane/WezTerm
---version, and a bare error here would kill the whole status update.
---@param pane Pane
---@return string?
local function remote_host(pane)
   local ok, data = pcall(function()
      return pane:get_osc_data()
   end)
   if not ok or type(data) ~= 'table' then
      return nil
   end

   local remote = data.Hostname
   if type(remote) ~= 'string' or remote == '' then
      return nil
   end

   -- Same box over a loopback SSH, or an ssh-into-self: not a remote target.
   if remote == wezterm.hostname() or remote:lower():match('^localhost') then
      return nil
   end

   return remote
end

-- NOTE (2026-10-12): the pane-command pill was removed here. tmux's own
-- status-left already renders #{pane_current_command} in @thm_maroon, so this
-- pill was the same fact printed twice, one line apart. One owner per signal:
-- tmux reports pane command; the HUD keeps only wezterm-level state (key table,
-- remote host, disk, sync, pane count).

---Disk free on the HOME partition, as "12G"/"850M", or nil when above the
---threshold. Cached for 60s to avoid forking df on every update-status.
---
---@type {value: string|'', age: number}
local disk_cache = { value = '', age = 0 }

---@param threshold_gb number
---@return string?
local function disk_free_badge(threshold_gb)
   threshold_gb = threshold_gb or 10
   local now = os.time()

   if disk_cache.age > 0 and (now - disk_cache.age) < 60 then
      if disk_cache.value == '' then
         return nil
      end
      local gb = tonumber(disk_cache.value:match('^(%d+)')) or 0
      return gb < threshold_gb and disk_cache.value or nil
   end

   local home = os.getenv('HOME')
   if not home then
      disk_cache.value = ''
      disk_cache.age = now
      return nil
   end

   local f = io.popen('df -k "' .. home .. '" 2>/dev/null | tail -1')
   if not f then
      disk_cache.value = ''
      disk_cache.age = now
      return nil
   end

   local line = f:read('*l') or ''
   f:close()

   -- df -k columns: Filesystem 1024-blocks Used Available Capacity Mounted-on
   -- (tail -1 above in case a long filesystem name wraps). Field 4 is the
   -- AVAILABLE space. This line used to be
   --   tonumber(line:match('^(%S+)%s+%S+%s+(%S+)'))
   -- which (a) grabbed the USED field, not available, and (b) — the real crash
   -- — passed the second capture to tonumber as its BASE, because a two-capture
   -- match returns two values. Lua then threw "bad argument #2 to 'tonumber'
   -- (base out of range)" on every update-status. The disk pill therefore never
   -- rendered and the error spammed the log. Read the field explicitly.
   local available_kb
   local field_i = 0
   for field in line:gmatch('%S+') do
      field_i = field_i + 1
      if field_i == 4 then
         available_kb = tonumber(field)
         break
      end
   end
   if not available_kb then
      disk_cache.value = ''
      disk_cache.age = now
      return nil
   end

   local gb = available_kb / 1024 / 1024
   if gb < threshold_gb then
      local value = gb >= 1 and string.format('%dGB', math.floor(gb)) or string.format('%dMB', math.floor(gb * 1024))
      disk_cache.value = value
      disk_cache.age = now
      return value
   end

   disk_cache.value = ''
   disk_cache.age = now
   return nil
end

---Whether the active pane has pane_synchronized on.
---
---@param pane Pane
---@return boolean
local function pane_sync_on(pane)
   local ok, v = pcall(function()
      return pane:get_tmux_variable('pane_synchronized')
   end)
   return ok and v == 'on'
end

---Collect the active signals, in priority order (most alarming first).
---
---Pills sit at the FRONT of the right status so they're the first thing read
---and a long date string can never push them off a narrow window.
---
---Signals:
---   1. key table  — which key map is active (LEADER, RESIZE_PANE, copy, ...)
---   2. remote host — OSC 1337 Hostname on the pane (only when truly remote)
---   3. disk        — free space on HOME (only when below threshold)
---   4. sync        — pane_synchronized is on (only when active)
---   5. pane count  — wezterm tab has >1 panes (pane command is tmux's job)
---@param parts FormatItem[][]
---@param window Window
---@param pane Pane
-- Pane-count glyph: md_dock_window on patched fonts, ASCII otherwise.
local GLYPH_PANES = nf.md_dock_window or '#'

---Pane count of the active tab, as a string, shown only above 1. This is the
---one window-level state wezterm reports nowhere: tmux has #{window_panes}
---in its own mode pill, but plain wezterm splits are otherwise invisible
---state. Count (not layout) is the honest smallest signal.
---@param window Window
---@return string?
local function pane_count_badge(window)
   local ok, tab = pcall(function()
      return window:active_tab()
   end)
   if not ok or not tab then
      return nil
   end

   -- In this wezterm build `panes` is a METHOD (MuxTab:panes()), not a field,
   -- so `#tab.panes` raised "attempt to get length of a function value" on
   -- every update-status and the pill never rendered. Call it when it is a
   -- function, fall back to the field on builds that expose it as data.
   local ok2, panes = pcall(function()
      if type(tab.panes) == 'function' then
         return tab:panes()
      end
      return tab.panes
   end)
   if not ok2 or type(panes) ~= 'table' then
      return nil
   end

   local n = #panes
   if n <= 1 then
      return nil
   end
   return n .. ' ' .. GLYPH_PANES
end

local function add_signals(parts, window, pane)
   -- 1. remote host: red on a light-contrast pill so it reads as an alarm in
   -- either theme branch. (Active key table is owned exclusively by left-status.lua.)
   local host = remote_host(pane)
   if host then
      table.insert(parts, pill(string.upper(host), tokens.red, tokens.on_accent))
   end

   -- 2. disk: amber pill when free space on HOME is below threshold.
   local disk = disk_free_badge(10)
   if disk then
      table.insert(parts, pill(disk, tokens.yellow, tokens.glass))
   end

   -- 3. sync: amber pill when pane_synchronized is on.
   if pane_sync_on(pane) then
      table.insert(parts, pill('SYNC', tokens.yellow, tokens.glass))
   end

   -- 4. pane count: quiet surface pill, only when the active tab is split.
   local panes = pane_count_badge(window)
   if panes then
      table.insert(parts, pill(panes, tokens.cyan, tokens.glass))
   end
end

---HUD FormatItems, or an empty list when nothing needs showing.
---
---Returns raw FormatItems, NOT a formatted string, so the caller can append
---its own segments and call wezterm.format EXACTLY ONCE. That matters:
---wezterm.concat does not exist in this build (verified nil), and two
---separately-formatted strings cannot be joined with Lua `..` either -- a
---formatted string is an opaque, already-escaped token, so re-wrapping one
---inside another wezterm.format fails. One list, one format, no joining.
---@param window Window
---@param pane Pane
---@return FormatItem[]
M.hud_items = function(window, pane)
   local parts = {}
   add_signals(parts, window, pane)

   local items = {}
   for _, seg in ipairs(parts) do
      for _, item in ipairs(seg) do
         table.insert(items, item)
      end
   end
   if #items > 0 then
      table.insert(items, { Text = '   ' })
   end

   return items
end

return M
