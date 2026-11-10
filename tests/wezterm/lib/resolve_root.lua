-- Shared config-root resolver for standalone WezTerm Lua test scripts.
-- Falls back to the repo's `.config/wezterm` when <config-root> is omitted;
-- prints usage to stderr and exits 2 on invalid arguments or missing config.
local function is_readable(path)
   local fh = io.open(path, 'r')
   if not fh then
      return false
   end
   fh:close()
   return true
end

local THIS_SRC = debug.getinfo(1, 'S')
local LIB_DIR = THIS_SRC and THIS_SRC.source:match('^@(.+)[/\\][^/\\]+$')

local function script_dir_from(args)
   local info = debug.getinfo(3, 'S')
   local src = info and info.source or ''
   local dir = src:match('^@(.+)[/\\][^/\\]+$')
   if not dir and args and args[0] then
      dir = args[0]:match('^(.*)[/\\][^/\\]+$')
   end
   return dir or '.'
end

return function(script_name, args)
   args = args or arg or {}
   local first = args[1]

   local function fail_usage(msg)
      if msg then
         io.stderr:write(script_name .. ': ' .. msg .. '\n')
      end
      io.stderr:write(
         string.format('usage: luajit tests/wezterm/%s [<config-root>]\n', script_name)
      )
      os.exit(2)
   end

   if #args > 1 then
      fail_usage('unexpected argument: ' .. tostring(args[2]))
   end
   if first == '-h' or first == '--help' then
      fail_usage(nil)
   end
   if first and first:sub(1, 1) == '-' then
      fail_usage('unknown option: ' .. first)
   end

   if first then
      local trimmed = first:gsub('/+$', '')
      if not is_readable(trimmed .. '/wezterm.lua') then
         fail_usage('config root missing wezterm.lua: ' .. first)
      end
      return trimmed
   end

   local dir = script_dir_from(args)
   local candidates = {
      dir .. '/../../.config/wezterm',
      dir .. '/../.config/wezterm',
   }
   if LIB_DIR then
      candidates[#candidates + 1] = LIB_DIR .. '/../../../.config/wezterm'
   end
   for _, cand in ipairs(candidates) do
      if is_readable(cand .. '/wezterm.lua') then
         return cand
      end
   end
   fail_usage('could not locate default .config/wezterm (pass <config-root>)')
end
