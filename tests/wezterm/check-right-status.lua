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

local _script_dir = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]+$')) or '.'
local root = dofile(_script_dir .. '/lib/resolve_root.lua')('check-right-status.lua', arg)

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
   nerdfonts = setmetatable({}, {
      __index = function()
         return ''
      end,
   }),
   action_callback = function(fn)
      return fn
   end,
   format = function(t)
      return t
   end,
   action = setmetatable({}, {
      __index = function()
         return function() end
      end,
   }),
   gui = {
      enumerate_gpus = function()
         return {}
      end,
      get_guids = function()
         return {}
      end,
   },
}
package.loaded['wezterm'] = _G.wezterm

-- ---- the module under test ------------------------------------------------
local ok_load, right_status = pcall(require, 'events.right-status')
check('events.right-status loads through the real chain', ok_load, ok_load and nil or right_status)
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
-- glass is rgba(r, g, b, <alpha>) (matching tab_bar.background) composited over
-- colors.background; the composite, not the raw background, is the reference
-- surface.
local tokens = require('utils.tokens')
local colorscheme = require('colors.custom')

local glass_r, glass_g, glass_b, alpha = 0, 0, 0, 0.4
do
   local glass_str = tostring(tokens.glass)
   local rs, gs, bs, as =
      glass_str:match('rgba%(%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*%)')
   if rs then
      glass_r = tonumber(rs) or 0
      glass_g = tonumber(gs) or 0
      glass_b = tonumber(bs) or 0
      alpha = tonumber(as) or alpha
   else
      local a = glass_str:match('rgba%b()')
      if a then
         local n = glass_str:match('([%d%.]+)%s*%)%s*$')
         if n then
            alpha = tonumber(n) or alpha
         end
      end
   end
end

local bg_hex = colorscheme.background
local function composite(hex, a, sr, sg, sb)
   sr, sg, sb = sr or 0, sg or 0, sb or 0
   local r = math.floor(sr * a + tonumber(hex:sub(2, 3), 16) * (1 - a) + 0.5)
   local g = math.floor(sg * a + tonumber(hex:sub(4, 5), 16) * (1 - a) + 0.5)
   local b = math.floor(sb * a + tonumber(hex:sub(6, 7), 16) * (1 - a) + 0.5)
   return string.format('#%02x%02x%02x', r, g, b)
end
local eff_bg = composite(bg_hex, alpha, glass_r, glass_g, glass_b)

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
         check(
            string.format(
               '%s: %.2f:1 on glass composite %s (needs %.1f)',
               name,
               ratio,
               eff_bg,
               MIN_CONTRAST
            ),
            ratio >= MIN_CONTRAST
         )
      end
   end
end

-- Optional-signal rendering gate: empty values must emit neither icons nor
-- duplicate/adjacent separators (e.g., cpu_text == '' on tick 1).
local build_ids = right_status and right_status.build_render_ids
check('build_render_ids exported', type(build_ids) == 'function')

if type(build_ids) == 'function' then
   local function join_ids(list)
      return table.concat(list, ',')
   end
   local function has_id(list, target)
      for _, v in ipairs(list) do
         if v == target then
            return true
         end
      end
      return false
   end
   local function is_sep(id)
      return id == 'separator' or id == 'sep_cpu_bat' or id == 'sep_bat_clock'
   end
   local function has_adjacent_sep(list)
      for i = 1, #list - 1 do
         if is_sep(list[i]) and is_sep(list[i + 1]) then
            return true
         end
      end
      return is_sep(list[1]) or is_sep(list[#list])
   end

   local none = build_ids('', '', '')
   check(
      'render_ids(all empty): omits cpu/mem/battery and has single separator',
      join_ids(none) == 'date_icon,date_text,separator,clock_icon,clock_text',
      join_ids(none)
   )
   check(
      'render_ids(all empty): no adjacent/edge separators',
      not has_adjacent_sep(none),
      join_ids(none)
   )

   local tick1_mem = build_ids('', '4.2G', '')
   check(
      'render_ids(tick1 mem only): omits cpu_icon',
      not has_id(tick1_mem, 'cpu_icon'),
      join_ids(tick1_mem)
   )
   check(
      'render_ids(tick1 mem only): includes mem_icon & mem_text',
      has_id(tick1_mem, 'mem_icon') and has_id(tick1_mem, 'mem_text'),
      join_ids(tick1_mem)
   )
   check(
      'render_ids(tick1 mem only): no adjacent/edge separators',
      not has_adjacent_sep(tick1_mem),
      join_ids(tick1_mem)
   )

   local only_cpu = build_ids('12%', '', '')
   check(
      'render_ids(cpu only): includes cpu_icon/text and omits mem/bat',
      has_id(only_cpu, 'cpu_icon')
         and not has_id(only_cpu, 'mem_icon')
         and not has_id(only_cpu, 'battery_icon'),
      join_ids(only_cpu)
   )
   check(
      'render_ids(cpu only): no adjacent/edge separators',
      not has_adjacent_sep(only_cpu),
      join_ids(only_cpu)
   )

   local only_bat = build_ids('', '', '80%')
   check(
      'render_ids(bat only): omits cpu/mem and includes battery_icon',
      not has_id(only_bat, 'cpu_icon')
         and not has_id(only_bat, 'mem_icon')
         and has_id(only_bat, 'battery_icon'),
      join_ids(only_bat)
   )
   check(
      'render_ids(bat only): no adjacent/edge separators',
      not has_adjacent_sep(only_bat),
      join_ids(only_bat)
   )

   local all_pop = build_ids('12%', '4.2G', '80%')
   local want_all = 'date_icon,date_text,separator,cpu_icon,cpu_text,'
      .. 'sep_cpu_mem,mem_icon,mem_text,sep_cpu_bat,'
      .. 'battery_icon,battery_text,sep_bat_clock,clock_icon,clock_text'
   check(
      'render_ids(all populated): renders full order with separators',
      join_ids(all_pop) == want_all,
      join_ids(all_pop)
   )
   check(
      'render_ids(all populated): no adjacent/edge separators',
      not has_adjacent_sep(all_pop),
      join_ids(all_pop)
   )
end

print(
   string.format(
      'right-status segments: %d pass, %d fail (bg %s, glass alpha %s)',
      pass,
      fail,
      eff_bg,
      tostring(alpha)
   )
)
os.exit(fail == 0 and 0 or 1)
