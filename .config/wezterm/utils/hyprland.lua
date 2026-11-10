local wezterm = require('wezterm')

local M = {}

---@type 'eval'|'legacy'|nil
local cached_mode = nil

---Reset cached Hyprland resize dispatch mode (intended for unit tests).
M.reset_cache = function()
   cached_mode = nil
end

---Inspect current cached resize mode ('eval' | 'legacy' | nil).
---@return 'eval'|'legacy'|nil
M.mode = function()
   return cached_mode
end

---Build argv for Hyprland active-window resize under the requested mode.
---@param delta integer
---@param mode 'eval'|'legacy'
---@return string[]
M.resize_cmd = function(delta, mode)
   if mode == 'eval' then
      return {
         'hyprctl',
         'eval',
         string.format('hl.dsp.window.resize({ x=%d, y=%d, relative=true })', delta, delta),
      }
   end
   return {
      'hyprctl',
      'dispatch',
      'resizeactive',
      string.format('%d %d', delta, delta),
   }
end

---@param runner fun(argv: string[]): boolean?, string?, string?
---@param argv string[]
---@return boolean
local function run_ok(runner, argv)
   if not runner then
      return false
   end
   local ok, success = pcall(runner, argv)
   return ok and success == true
end

---Resize active floating window via Hyprland 0.50+ Lua `eval`, falling back to
---legacy `dispatch resizeactive` when `eval` exits non-zero. Detects once and
---caches the working form so subsequent keystrokes pay zero probe overhead.
---@param delta integer
---@param runner? fun(argv: string[]): boolean?, string?, string?
---@return boolean ok
---@return 'eval'|'legacy'|'none' used_mode
M.resize = function(delta, runner)
   local exec_fn = runner or wezterm.run_child_process
   if not exec_fn then
      return false, 'none'
   end

   if cached_mode ~= 'legacy' then
      if run_ok(exec_fn, M.resize_cmd(delta, 'eval')) then
         cached_mode = 'eval'
         return true, 'eval'
      end
   end

   if run_ok(exec_fn, M.resize_cmd(delta, 'legacy')) then
      cached_mode = 'legacy'
      return true, 'legacy'
   end

   return false, cached_mode or 'none'
end

return M
