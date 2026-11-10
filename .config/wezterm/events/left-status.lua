local wezterm = require('wezterm')
local tokens = require('utils.tokens')

local M = {}

-- LEFT STATUS — Modal Key-Table Indicator & Workspace Identity
--
-- Displays:
--   1. Active Key Table (e.g. WORKSPACES, RESIZE, COPY) with prominent alert styling
--      so you never type into a modal key table accidentally.
--   2. Active Workspace (when not 'default').

local nf = wezterm.nerdfonts
local GLYPH_SEMI_CIRCLE_LEFT = (nf and nf.ple_left_half_circle_thick) or '<'
local GLYPH_SEMI_CIRCLE_RIGHT = (nf and nf.ple_right_half_circle_thick) or '>'
local ICON_KEYBOARD = (nf and nf.md_keyboard) or 'KT'
local ICON_WORKSPACE = (nf and nf.md_view_dashboard_outline) or 'WS'

---@type table<string, Cells.SegmentColors>
local colors = {
   kt_pill = { bg = tokens.accent, fg = tokens.on_accent },
   kt_edge = { bg = tokens.glass, fg = tokens.accent },
   ws_pill = { bg = tokens.pill, fg = tokens.pill_fg },
   ws_edge = { bg = tokens.glass, fg = tokens.pill },
}

---Active workspace name, or nil on the default workspace.
---@param window wezterm.Window
---@return string?
local function workspace_label(window)
   local ok, ws = pcall(function()
      return window:active_workspace()
   end)
   if not ok or type(ws) ~= 'string' or ws == '' or ws == 'default' then
      return nil
   end
   return ws
end

---Active key table name, or nil if none.
---@param window wezterm.Window
---@return string?
local function active_key_table(window)
   local ok, kt = pcall(function()
      return window:active_key_table()
   end)
   if ok and type(kt) == 'string' and kt ~= '' then
      return kt
   end
   return nil
end

M.setup = function()
   wezterm.on('update-status', function(window, _pane)
      local kt = active_key_table(window)
      local ws = workspace_label(window)

      if not kt and not ws then
         window:set_left_status('')
         return
      end

      local items = {}

      if kt then
         table.insert(items, { Background = { Color = colors.kt_edge.bg } })
         table.insert(items, { Foreground = { Color = colors.kt_edge.fg } })
         table.insert(items, { Text = GLYPH_SEMI_CIRCLE_LEFT })

         table.insert(items, { Background = { Color = colors.kt_pill.bg } })
         table.insert(items, { Foreground = { Color = colors.kt_pill.fg } })
         table.insert(items, { Attribute = { Intensity = 'Bold' } })
         table.insert(items, { Text = ' ' .. ICON_KEYBOARD .. ' ' .. kt:upper() .. ' ' })

         table.insert(items, { Background = { Color = colors.kt_edge.bg } })
         table.insert(items, { Foreground = { Color = colors.kt_edge.fg } })
         table.insert(items, { Text = GLYPH_SEMI_CIRCLE_RIGHT })
         table.insert(items, { Text = ' ' })
      end

      if ws then
         table.insert(items, { Background = { Color = colors.ws_edge.bg } })
         table.insert(items, { Foreground = { Color = colors.ws_edge.fg } })
         table.insert(items, { Text = GLYPH_SEMI_CIRCLE_LEFT })

         table.insert(items, { Background = { Color = colors.ws_pill.bg } })
         table.insert(items, { Foreground = { Color = colors.ws_pill.fg } })
         table.insert(items, { Attribute = { Intensity = 'Bold' } })
         table.insert(items, { Text = ' ' .. ICON_WORKSPACE .. ' ' .. ws .. ' ' })

         table.insert(items, { Background = { Color = colors.ws_edge.bg } })
         table.insert(items, { Foreground = { Color = colors.ws_edge.fg } })
         table.insert(items, { Text = GLYPH_SEMI_CIRCLE_RIGHT })
      end

      window:set_left_status(wezterm.format(items))
   end)
end

return M
