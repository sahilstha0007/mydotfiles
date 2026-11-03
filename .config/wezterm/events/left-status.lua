local wezterm = require('wezterm')
local Cells = require('utils.cells')
local tokens = require('utils.tokens')

local attr = Cells.attr

local M = {}

-- LEFT STATUS — the wezterm-scoped signal only.
--
-- 2026-10-12: this used to fork `tmux display-message` once per second to read
-- the tmux pane mode (COPY / V / W / m) and render it as a pill. That was the
-- same fact tmux's OWN status-left already prints two lines below (the
-- `#{?pane_in_copy_mode,…%M…%W…%m}` segment), and the active wezterm key table
-- is already shown as a pill by events/hud.lua on the right. So the left pill
-- duplicated two other indicators AND paid a process fork every second to do
-- it. Removed.
--
-- One owner per signal: tmux reports its own mode; hud.lua reports wezterm's
-- key table. What is left for THIS surface is state that exists only in
-- wezterm and nowhere else: the active WORKSPACE. It is silent on the default
-- workspace (the common case), and names the workspace the moment you switch
-- to a named one — so it earns the left edge without adding idle noise.

-- Nerd-font half-circle glyphs with ASCII fallbacks, so the module still
-- loads on a build without the nf table.
local nf = wezterm.nerdfonts
local GLYPH_SEMI_CIRCLE_LEFT = (nf and nf.ple_left_half_circle_thick) or '<'
local GLYPH_SEMI_CIRCLE_RIGHT = (nf and nf.ple_right_half_circle_thick) or '>'

---@type table<string, Cells.SegmentColors>
local colors = {
   pill = { bg = tokens.pill, fg = tokens.pill_fg },
   scircle = { bg = tokens.glass, fg = tokens.pill },
}

local cells = Cells:new()

cells
   :add_segment(1, GLYPH_SEMI_CIRCLE_LEFT, colors.scircle, attr(attr.intensity('Bold')))
   :add_segment(2, '', colors.pill, attr(attr.intensity('Bold')))
   :add_segment(3, GLYPH_SEMI_CIRCLE_RIGHT, colors.scircle, attr(attr.intensity('Bold')))

---Active workspace name, or nil on the default workspace (the common case).
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

M.setup = function()
   wezterm.on('update-status', function(window, _pane)
      local ws = workspace_label(window)
      if not ws then
         -- Default workspace: nothing to say on the left. An empty status
         -- costs no columns and beats printing a constant "default".
         window:set_left_status('')
         return
      end

      cells:update_segment_text(2, ' ' .. ws .. ' ')
      window:set_left_status(wezterm.format(cells:render({ 1, 2, 3 })))
   end)
end

return M
