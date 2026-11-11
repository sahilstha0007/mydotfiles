-- Test: Hyprland active-window resize uses `hyprctl eval hl.dsp.window.resize(...)`
-- on Hyprland 0.57.1+, falls back to legacy `dispatch resizeactive` on non-zero exit,
-- caches the working form, and passes a live `hyprctl` probe when Hyprland is active.
--
-- Run: luajit tests/wezterm/check_hyprland.lua [<config-root>]
-- Exit: 0 = all checks passed, 1 = any failure

local _script_dir = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]+$')) or '.'
local root = dofile(_script_dir .. '/lib/resolve_root.lua')('check_hyprland.lua', arg)

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

local function sh_quote(s)
   return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local active_runner = nil
_G.wezterm = {
   home_dir = os.getenv('HOME') or os.getenv('TMPDIR') or '.',
   config_dir = root,
   os = 'Linux',
   target_triple = 'x86_64-unknown-linux-gnu',
   log_error = function() end,
   log_warn = function() end,
   log_info = function() end,
   run_child_process = function(argv)
      if active_runner then
         return active_runner(argv)
      end
      local quoted = {}
      for i, a in ipairs(argv) do
         quoted[i] = sh_quote(a)
      end
      local cmd = table.concat(quoted, ' ') .. ' >/dev/null 2>&1'
      local rc = os.execute(cmd)
      local ok = (rc == 0 or rc == true)
      return ok, '', ''
   end,
}
package.loaded['wezterm'] = _G.wezterm

local ok_mod, hyprland = pcall(require, 'utils.hyprland')
check('utils.hyprland loads cleanly', ok_mod, ok_mod and nil or hyprland)
if not ok_mod then
   os.exit(1)
end

-- Helper: execute a real stub `hyprctl` binary via temporary PATH directory
local function with_stub_hyprctl(stub_body, fn)
   local p = io.popen('mktemp -d', 'r')
   local tmp = p and p:read('*l')
   if p then
      p:close()
   end
   assert(tmp and tmp ~= '', 'mktemp failed')
   local stub_path = tmp .. '/hyprctl'
   local log_path = tmp .. '/calls.log'
   local f = assert(io.open(stub_path, 'w'))
   f:write('#!/bin/sh\n')
   f:write('printf "%s\\n" "$*" >> ' .. sh_quote(log_path) .. '\n')
   f:write(stub_body)
   f:close()
   os.execute('chmod +x ' .. sh_quote(stub_path))

   local orig_run = _G.wezterm.run_child_process
   active_runner = function(argv)
      local quoted = {}
      for i, a in ipairs(argv) do
         quoted[i] = sh_quote(a)
      end
      local path_env = tmp .. ':' .. (os.getenv('PATH') or '')
      local cmd = 'PATH='
         .. sh_quote(path_env)
         .. ' '
         .. table.concat(quoted, ' ')
         .. ' >/dev/null 2>&1'
      local rc = os.execute(cmd)
      return (rc == 0 or rc == true), '', ''
   end

   local ok_call, err_call = pcall(fn, log_path)
   active_runner = nil
   _G.wezterm.run_child_process = orig_run
   os.execute('rm -rf ' .. sh_quote(tmp))
   if not ok_call then
      error(err_call)
   end
end

local function read_lines(path)
   local lines = {}
   local f = io.open(path, 'r')
   if not f then
      return lines
   end
   for l in f:lines() do
      lines[#lines + 1] = l
   end
   f:close()
   return lines
end

-- Case 1: Eval command formatting & modern Hyprland path
hyprland.reset_cache()
with_stub_hyprctl('exit 0\n', function(log_path)
   local ok1, mode1 = hyprland.resize(50)
   local ok2, mode2 = hyprland.resize(-50)
   local calls = read_lines(log_path)
   check('eval mode succeeds on first call', ok1 == true and mode1 == 'eval', mode1)
   check('eval mode stays cached on second call', ok2 == true and mode2 == 'eval', mode2)
   check(
      'eval argv matches hl.dsp.window.resize Lua syntax',
      #calls == 2
         and calls[1] == 'eval hl.dsp.window.resize({ x=50, y=50, relative=true })'
         and calls[2] == 'eval hl.dsp.window.resize({ x=-50, y=-50, relative=true })',
      table.concat(calls, ' | ')
   )
end)

-- Case 2: Non-zero exit from `eval` falls back to legacy `dispatch resizeactive`, then caches legacy
hyprland.reset_cache()
with_stub_hyprctl('[ "$1" = "eval" ] && exit 7\nexit 0\n', function(log_path)
   local ok1, mode1 = hyprland.resize(40)
   local ok2, mode2 = hyprland.resize(-40)
   local calls = read_lines(log_path)
   check('eval non-zero exit triggers legacy fallback', ok1 == true and mode1 == 'legacy', mode1)
   check(
      'legacy mode stays cached (no wasted failing eval probe on call 2)',
      ok2 == true and mode2 == 'legacy',
      mode2
   )
   check(
      'fallback sequence tried eval -> legacy, then direct legacy',
      #calls == 3
         and calls[1] == 'eval hl.dsp.window.resize({ x=40, y=40, relative=true })'
         and calls[2] == 'dispatch resizeactive 40 40'
         and calls[3] == 'dispatch resizeactive -40 -40',
      table.concat(calls, ' | ')
   )
end)

-- Case 3: Both failing still returns false cleanly without throwing
hyprland.reset_cache()
with_stub_hyprctl('exit 1\n', function()
   local ok_fail, mode_fail = hyprland.resize(10)
   check(
      'both modes failing returns false cleanly',
      ok_fail == false and mode_fail == 'none',
      mode_fail
   )
end)

-- Case 4: Live Hyprland probe when running inside an active Hyprland session
if os.getenv('HYPRLAND_INSTANCE_SIGNATURE') then
   hyprland.reset_cache()
   local ok_live, mode_live = hyprland.resize(0)
   check(
      'live hyprctl zero-delta resize probe succeeds (' .. tostring(mode_live) .. ')',
      ok_live == true and mode_live == 'eval',
      tostring(ok_live) .. '/' .. tostring(mode_live)
   )
end

print(string.format('hyprland resize checks: %d pass, %d fail', pass, fail))
os.exit(fail == 0 and 0 or 1)
