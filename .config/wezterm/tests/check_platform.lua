-- Test: utils/platform.lua must never be the thing that kills the config.
--
-- platform.lua is required by config/launch.lua, config/bindings.lua,
-- config/fonts.lua, config/domains.lua and utils/gpu-adapter.lua, all at
-- module load, and it used to end in a bare `error('Unknown platform')` when
-- wezterm.target_triple matched none of windows/linux/apple.
--
-- The consequence is total and there is no degraded mode: the error propagates
-- out of the require in wezterm.lua, so a target triple we did not anticipate
-- takes down every key binding, font and launch entry along with the colour
-- scheme. There is no `on('fail')` handler to catch it either.
--
-- It is a low-probability path and a low-probability fix, which is exactly
-- why it needs a test: nothing else exercises it, so nothing else would notice
-- it regressing.
--
-- The degraded answer has to be USABLE, not just non-fatal. Every consumer
-- branches on is_win / is_mac / is_linux, so an unknown platform has to
-- resolve to one of them rather than to all-false -- otherwise
-- config/launch.lua silently produces an empty default_prog and no launch
-- menu, which is a worse failure than picking the wrong branch. This config is
-- developed on Linux, so Linux is the documented fallback.
--
-- Run: luajit tests/check_platform.lua <config-root>

local root = assert(arg[1], 'usage: check_platform.lua <config-root>')

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

---Load utils/platform.lua with wezterm.target_triple reporting `triple`.
---@return table? platform module, or nil plus the load error
local function platform_for(triple)
   _G.wezterm = {
      target_triple = triple,
      home_dir = root,
      config_dir = root,
      log_error = function() end,
      log_warn = function() end,
      log_info = function() end,
      on = function() end,
   }
   package.loaded['wezterm'] = _G.wezterm
   package.loaded['utils.platform'] = nil
   local ok, res = pcall(require, 'utils.platform')
   if not ok then
      return nil, res
   end
   return res
end

-- 1. The three known triples still classify. This is the regression guard on
--    whatever fallback the unknown branch gets.
for _, case in ipairs({
   { triple = 'x86_64-pc-windows-msvc', os = 'windows', flag = 'is_win' },
   { triple = 'aarch64-apple-darwin', os = 'mac', flag = 'is_mac' },
   { triple = 'x86_64-unknown-linux-gnu', os = 'linux', flag = 'is_linux' },
}) do
   local p, err = platform_for(case.triple)
   check(case.triple .. ' -> ' .. case.os, p ~= nil and p.os == case.os, p and p.os or err)
   check(
      case.triple .. ' sets ' .. case.flag .. ' and only that',
      p ~= nil and p[case.flag] == true,
      p and case.flag .. '=' .. tostring(p[case.flag]) or err
   )
end

-- 2. An unrecognised triple must NOT throw. This is the whole point: the
--    error used to propagate out of the require and take the config with it.
do
   local p, err = platform_for('powerpc-unknown-none-elf')
   check('an unknown triple loads instead of erroring', p ~= nil, err)
end

-- 3. ...and it must resolve to a real platform, not to all-false. Every
--    consumer branches on these three flags, so an unknown triple that clears
--    all of them leaves config/launch.lua with default_prog = {} and an empty
--    launch_menu -- a silent misconfiguration, which is the failure mode this
--    file is meant to remove.
do
   local p = platform_for('powerpc-unknown-none-elf')
   if p then
      local flags = { p.is_win, p.is_mac, p.is_linux }
      local set = 0
      for _, v in ipairs(flags) do
         if v then
            set = set + 1
         end
      end
      check('an unknown triple resolves to exactly one platform', set == 1, 'os=' .. tostring(p.os))
      check('an unknown triple falls back to linux', p.os == 'linux', 'os=' .. tostring(p.os))
   end
end

-- 4. And the reason has to survive into the log, or an unexpected fallback is
--    just as invisible as the error it replaced. utils/platform.lua logs
--    through wezterm, so the stub records what it was told.
do
   local logged = {}
   _G.wezterm = {
      target_triple = 'powerpc-unknown-none-elf',
      home_dir = root,
      config_dir = root,
      log_error = function(...)
         table.insert(logged, 'error: ' .. table.concat({ ... }, ' '))
      end,
      log_warn = function(...)
         table.insert(logged, 'warn: ' .. table.concat({ ... }, ' '))
      end,
      log_info = function() end,
      on = function() end,
   }
   package.loaded['wezterm'] = _G.wezterm
   package.loaded['utils.platform'] = nil
   require('utils.platform')
   local said_something = false
   for _, line in ipairs(logged) do
      if line:find('powerpc%-unknown%-none%-elf') or line:find('platform', 1, true) then
         said_something = true
      end
   end
   check('the fallback is logged, naming the triple', said_something, #logged .. ' messages')
end

print(('\n%d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
