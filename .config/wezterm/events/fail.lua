-- Startup diagnostics for a config that would not load.
--
-- There is no `wezterm.on('fail', ...)` event. It is not undocumented, it
-- does not exist: the full event list on wezterm.org for this build
-- (wezterm 20260716-102532-2ef4bef4) is augment-command-palette, bell,
-- format-tab-title, format-window-title, gui-attached, gui-startup,
-- mux-is-process-stateful, mux-startup, new-tab-button-click, open-uri,
-- update-right-status, update-status, user-var-changed,
-- window-config-reloaded, window-focus-changed, window-resized. A 'fail'
-- handler would register cleanly and never fire, which is worse than the
-- failure it looks like it fixes -- it reads as protection.
--
-- What wezterm actually does with a bad config, verified on this build:
--
--   1. the load fails, wezterm prints "Configuration Error: runtime error:
--      <file>:<line>: <message>" plus a stack trace to stderr, and falls back
--      to the LAST WORKING config;
--   2. it then opens a window with that last working config.
--
-- So the config on screen is not the config on disk, and the visible symptom
-- -- "my colours reverted and my binds stopped" -- reads as a theme bug, not a
-- load error. Nothing in this config's own handlers runs either, because the
-- whole module graph never evaluated.
--
-- What this file can and cannot do
--
-- It CANNOT name the error. wezterm exposes no API to read the last load's
-- error back, so there is no toast to raise and nothing to print into a
-- window. That part of the problem is not solvable from Lua.
--
-- What it can do is give a gate a signal it does not already have. A load that
-- never completes emits nothing wezterm reports on stderr: the error message
-- goes only to wezterm's own log, and the window that opens is drawn from the
-- PREVIOUS config. scripts/check-config.sh greps stderr for ERROR and, on a
-- healthy tree, sees none -- because there was no error this run, only a
-- failure one run ago. That gap is what this file closes.
--
-- So: a marker written as the very first statement of the load and removed as
-- the very last, and check-config.sh fails when the marker survives. Reaching
-- the end of the config IS the success signal, and unlike 'a window opened' it
-- is available headless, so the check does not depend on a GUI.
--
-- Honest limits, so nobody mistakes this for more than it is:
--   * the handler cannot run when the config fails to load, which is the case
--     it is about. Everything after the failure point is dead;
--   * a failure inside an event handler or callback rather than in the load
--     itself leaves the marker cleared, and this never fires;
--   * a panic in wezterm's own Rust, before Lua runs at all, also leaves the
--     marker in place and would be reported as a config failure. Check the
--     output before believing it.
--
-- To see a real error after any "my config changed and nothing happened":
--   wezterm --config-file ~/.config/wezterm/wezterm.lua ls-fonts 2>&1 | head

local wezterm = require('wezterm')

local M = {}

---Load marker. Must match the path in scripts/check-config.sh.
---@return string
local function marker_path()
   return wezterm.home_dir .. '/.cache/wezterm-config-loaded'
end

M.marker_path = marker_path

-- Written as the first statement of the load. The failure this exists to catch
-- is nearly always further down -- one of the ten module loads in wezterm.lua,
-- or any require under them -- so the marker has to be in place before they
-- start. 'w', not 'a': one marker per load, and a stale one must not survive
-- into this run.
local marker_fh = io.open(marker_path(), 'w')
if marker_fh then
   marker_fh:write(tostring(os.date('%Y-%m-%dT%H:%M:%S')) .. '\n')
   marker_fh:close()
end

-- Removed by `loaded()` below, once the config is known good end to end.
function M.loaded()
   os.remove(marker_path())
end

M.setup = function() end

return M
