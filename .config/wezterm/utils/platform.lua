local wezterm = require('wezterm')

local function is_found(str, pattern)
   return string.find(str, pattern) ~= nil
end

---@alias PlatformType 'windows' | 'linux' | 'mac'

---@return {os: PlatformType, is_win: boolean, is_linux: boolean, is_mac: boolean}
local function platform()
   local is_win = is_found(wezterm.target_triple, 'windows')
   local is_linux = is_found(wezterm.target_triple, 'linux')
   local is_mac = is_found(wezterm.target_triple, 'apple')
   local os

   if is_win then
      os = 'windows'
   elseif is_linux then
      os = 'linux'
   elseif is_mac then
      os = 'mac'
   else
      -- ponytail: assume Linux and say so. Ceiling: an unrecognised triple
      -- (a new arch, a musl/bsd build we do not know) gets Linux launch
      -- entries and Linux font sizing. Upgrade path if that ever bites: pick
      -- from wezterm.os, or let an env var override.
      --
      -- This used to be `error('Unknown platform')`, and that was not a
      -- cheap mistake. platform.lua is required at load by launch, bindings,
      -- fonts, domains and gpu-adapter, so the error propagated out of
      -- wezterm.lua and took every key binding, font and launch entry with
      -- it. Low probability, total consequence, no degraded mode.
      --
      -- The fallback has to resolve to a real platform rather than clearing
      -- all three flags: consumers branch on is_win/is_mac/is_linux, and an
      -- all-false platform leaves launch.lua with default_prog = {} and an
      -- empty launch menu -- a silent misconfiguration instead of an error.
      wezterm.log_error(
         'utils/platform: unknown target_triple ',
         wezterm.target_triple,
         ' -- assuming linux. Launch entries, fonts and key bindings will be the linux set.'
      )
      os = 'linux'
      -- The flags are derived from the triple, so on the fallback path they
      -- are all still false while `os` says linux -- and consumers read the
      -- FLAGS, not `os`. Correct them, or the fallback selects no launch
      -- entry, no font size and no platform branch, which is the silent
      -- misconfiguration this branch exists to avoid.
      is_win, is_linux, is_mac = false, true, false
   end

   return {
      os = os,
      is_win = is_win,
      is_linux = is_linux,
      is_mac = is_mac,
   }
end

local _platform = platform()

return _platform
