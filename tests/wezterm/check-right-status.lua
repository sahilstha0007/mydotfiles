-- Test: every right-status segment color must be a #rrggbb that clears WCAG
-- AA (4.5:1) on the background it actually paints on.
--
-- This file exists because the right-status used to hardcode fixed catppuccin
-- hue pairs with a comment saying "re-check before editing a light hex here"
-- -- a manual obligation nothing enforced. One light-mode pair (#c96a0a at
-- 3.39:1) had already shipped through that gap once. The colors are now
-- derived from the guard()-checked palette tokens, but the derived values
-- still need a gate: the guard walks tokens against colors.background, while
-- the segments actually paint on glass (rgba(0,0,0,0.4)) composited over that
-- background, which is a DIFFERENT background -- and one token in the set
-- (overlay0, the separator) is carried raw, not walked.
--
-- The check loads the real events.right-status through the real require chain
-- (utils.cells -> utils.tokens -> colors.custom -> the live matugen.lua), so
-- it asserts against the palette actually in use, the same "live is the
-- regression lock" rule the zsh sync check uses.
--
-- Run: luajit tests/check-right-status.lua <config-root>
-- Exit: 0 = all segments legible, 1 = one or more failed

local root = assert(arg[1], 'usage: check-right-status.lua <config-root>')

local pass, fail = 0, 0
local function check(name, ok, detail)
   if ok then
      pass = pass + 1
      print('  PASS  ' .. name)
   else
      fail = fail + 1
      print('  FAIL  ' .. name .. (detail and ('  <- ' .. tostring(detail)) or ''))
   end
end

package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

-- Minimal wezterm surface: the load-time requires of events.right-status
-- (Cells, tokens, colors.custom) plus the log stubs. Same stub set as
-- check_border.lua -- module loading must not touch the GPU or the wallpaper
-- library.
_G.wezterm = {
   home_dir = root,
   config_dir = root,
   os = 'Linux',
   target_triple = 'x86_64-unknown-linux-gnu',
   log_error = function() end,
   log_error_at = function() end,
   log_warn = function() end,
   log_info = function() end,
   on = function() end,
   nerdfonts = setmetatable({}, { __index = function() return '' end }),
   action_callback = function(fn) return fn end,
   format = function(t) return t end,
   action = setmetatable({}, { __index = function() return function() end end }),
   gui = {
      enumerate_gpus = function() return {} end,
      get_guids = function() return {} end,
   },
}
package.loaded['wezterm'] = _G.wezterm

-- ---- the module under test ------------------------------------------------
local ok_load, right_status = pcall(require, 'events.right-status')
check('events.right-status loads through the real chain', ok_load,
      ok_load and nil or right_status)
if not ok_load then
   os.exit(1)
end

local colors = right_status.colors
check('derived colors exposed for this check', type(colors) == 'table')

-- ---- contrast maths (WCAG relative luminance) ------------------------------
local function chan(c)
   c = c / 255
   return c <= 0.04045 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
end
local function luminance(hex)
   local r = tonumber(hex:sub(2, 3), 16)
   local g = tonumber(hex:sub(4, 5), 16)
   local b = tonumber(hex:sub(6, 7), 16)
   return 0.2126 * chan(r) + 0.7152 * chan(g) + 0.0722 * chan(b)
end
local function contrast(a, b)
   local la, lb = luminance(a), luminance(b)
   return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- ---- the background the segments actually paint on -------------------------
-- glass is rgba(0, 0, 0, <alpha>) composited over colors.background; the
-- composite, not the raw background, is the reference surface.
local tokens = require('utils.tokens')
local colorscheme = require('colors.custom')

local alpha = 0.4
do
   local a = tostring(tokens.glass):match('rgba%b()')
   if a then
      local n = tostring(tokens.glass):match('([%d%.]+)%s*%)%s*$')
      if n then
         alpha = tonumber(n) or alpha
      end
   end
end

local bg_hex = colorscheme.background
local function composite(hex, a)
   local r = math.floor(tonumber(hex:sub(2, 3), 16) * (1 - a) + 0.5)
   local g = math.floor(tonumber(hex:sub(4, 5), 16) * (1 - a) + 0.5)
   local b = math.floor(tonumber(hex:sub(6, 7), 16) * (1 - a) + 0.5)
   return string.format('#%02x%02x%02x', r, g, b)
end
local eff_bg = composite(bg_hex, alpha)

-- ---- assertions ------------------------------------------------------------
local MIN_CONTRAST = 4.5
local SEGMENTS = { 'date', 'host', 'uptime', 'cpu', 'mem', 'battery', 'separator' }

for _, name in ipairs(SEGMENTS) do
   local seg = colors and colors[name]
   if not seg or not seg.fg then
      check(name .. ': segment exists', false)
   else
      local fg = seg.fg
      check(name .. ': fg is #rrggbb', fg:match('^#%x%x%x%x%x%x$') ~= nil, fg)
      if fg:match('^#%x%x%x%x%x%x$') then
         local ratio = contrast(fg, eff_bg)
         check(string.format('%s: %.2f:1 on glass composite %s (needs %.1f)',
                             name, ratio, eff_bg, MIN_CONTRAST),
               ratio >= MIN_CONTRAST)
      end
   end
end

print(string.format('right-status segments: %d pass, %d fail (bg %s, glass alpha %s)',
                    pass, fail, eff_bg, tostring(alpha)))
os.exit(fail == 0 and 0 or 1)
