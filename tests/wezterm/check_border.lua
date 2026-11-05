-- Test: the window must have no titlebar and no border.
--
-- This file exists because the obvious way to remove the border was wrong and
-- nothing caught it. `window_decorations` was set in exactly ONE place,
-- config/border.lua. Deleting that file's :append line from wezterm.lua to
-- remove the accent rule also deleted the only writer of `window_decorations`,
-- so the key silently reverted to its default, 'TITLE | RESIZE' -- which draws
-- a titlebar AND a resize border. The border was still there, and the diff
-- looked like a clean removal.
--
-- So the load-bearing invariant is not "the file is gone" but "the key is
-- still set, and set to NONE". That is what this asserts, by reading the real
-- effective config rather than grepping source: a grep test would pass on the
-- broken version too, since border.lua was deleted, not edited.
--
-- Run: luajit tests/check_border.lua <config-root>

local root = assert(arg[1], 'usage: check_border.lua <config-root>')

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

-- Minimal wezterm surface: appearance.lua is the only file under test, and it
-- reads gpu-adapter (GPU enumeration) plus tokens. Stub what they need.
_G.wezterm = {
   home_dir = root,
   config_dir = root,
   os = 'Linux',
   -- utils/platform.lua does string.find(wezterm.target_triple, ...) at load
   -- time, so this has to be a real string or the require chain dies.
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

-- config/init.lua does `require('wezterm')` at load time. Assigning to _G
-- alone is not enough -- it has to be in package.loaded, or the require
-- fails and the whole chain errors out.
package.loaded['wezterm'] = _G.wezterm

-- ---- load the REAL chain --------------------------------------------------
-- Load the actual wezterm.lua, not a hand-rolled subset of it. An earlier
-- version of this test appended only config/appearance -- and therefore
-- passed clean even when border.lua had been re-appended to the real chain,
-- because the mutation was in a file the test never read. The chain IS the
-- thing under test; anything less tests a fiction.
--
-- wezterm.lua also scans wallpapers, globs, and sets up event handlers at
-- load time, so stub the filesystem-facing surface: the point is the merge
-- result, not the wallpaper library.
_G.wezterm.glob = function() return {} end
_G.wezterm.config_dir = root
_G.wezterm.cli = { get_working_dir = function() return root end }
_G.wezterm.show = setmetatable({}, { __index = function() return function() end end })
_G.wezterm.wait = function() end
_G.wezterm.background_child_process = function() return 0 end
_G.wezterm.run_child_process = function() return 0 end
_G.wezterm.open_with = function() end
_G.wezterm.to_notification = function(_, a, b, c) return { title = a, body = b, timeout = c } end
_G.wezterm.column_width = function(s) return #s end
_G.wezterm.truncate_right = function(s) return s end
-- events/tab-title.lua gates a feature on wezterm.version at load time.
_G.wezterm.version = '20260716-102532-2ef4bef4'
_G.wezterm.font_with_fallback = function(t) return t end
-- events/right-status.lua concatenates nerdfont glyphs at load time
-- (local ICON_DATE = nf.fa_calendar), so each lookup must yield a STRING --
-- an empty table here fails the concat, not just the value.
_G.wezterm.nerdfonts = setmetatable({}, { __index = function() return '' end })

local ok_chain, chain = pcall(function()
   -- wezterm.lua's last link in the chain is `.options`, so dofile already
   -- hands back the merged table -- no `.options` on top of it.
   return dofile(root .. '/wezterm.lua')
end)

check('real wezterm.lua chain loads', ok_chain, chain)
if not ok_chain then
   print(('\n%d passed, %d failed'):format(pass, fail))
   os.exit(1)
end

-- ---- the invariant --------------------------------------------------------
local deco = chain.window_decorations

-- 1. The key must be EXPLICITLY set. nil is the broken state: it means no
--    file in the chain writes the key, so wezterm substitutes its default.
check(
   'window_decorations is explicitly set somewhere in the chain',
   deco ~= nil,
   'nil means wezterm falls back to its default TITLE|RESIZE and the border returns'
)

-- 2. And it must be NONE -- the whole point.
check(
   "window_decorations == 'NONE'",
   deco == 'NONE',
   'got ' .. tostring(deco)
)

-- 3. Guard the specific failure this test was written for: 'TITLE' is what a
--    half-removal leaves behind, and it is the value that still draws a bar.
check(
   "window_decorations is not 'TITLE' (the half-removal value)",
   deco ~= 'TITLE',
   "'TITLE' still draws a titlebar"
)

-- 4. border.lua must stay out of the chain. :append() keeps the FIRST value
--    for a duplicate key rather than clobbering, so re-appending border.lua
--    would leave 'NONE' intact and this is the only assertion that notices.
check(
   'config/border.lua is NOT appended in the chain',
   chain.window_frame == nil,
   'window_frame present -- border.lua is back in the chain'
)

-- 5. The load-bearing check, and the one a filename cannot make. Assert 4
--    only fails when border.lua is appended *under its own name*; rename it,
--    inline its contents into another module, or restore it from upstream and
--    assert 4 still passes while a titlebar is back on screen. So scan the
--    source for the VALUE, across every file that can end up in the chain.
--    There is exactly one legitimate writer of this key (config/appearance.lua,
--    and it writes 'NONE'), so any 'TITLE' anywhere is a loaded gun whether or
--    not it is currently reachable -- and config/border.lua is exactly such a
--    file right now: never required, still armed.
--
--    Plain Lua, no shell. Two false readings while writing this, and a test
--    that reports a healthy config as broken (or a broken one as healthy) is
--    worse than no test:
--      * `grep -q` on a %q'd BRE makes the SPACE before the quote significant,
--        so `= 'TITLE'` never matched while `=nil` did (it contains "nil") --
--        33 unrelated hits.
--      * hand-rolled quoting for an ERE containing `(` produced a shell syntax
--        error that made every scan report zero hits, so the check PASSED on
--        the very tree it exists to catch.
--    Matching is per-line and whitespace-normalised, so indentation and quote
--    style cannot hide a writer either.
-- Only files that can actually reach the merged config. tests/ is excluded on
-- purpose: this file quotes the pattern it is searching for, so scanning
-- itself makes the test assert on its own source and match only itself.
local SCAN_DIRS = { 'config', 'colors', 'events', 'utils' }

---Every assignment-shaped source line assigning `key`, normalised so
---indentation and quote style cannot hide a writer.
---@return {file: string, line: string}[]
local function writers_of(key)
   local hits = {}
   -- Pattern, not plain find. `norm:find(key .. '=')` -- with no space before
   -- the `=` -- silently matched nothing against the real
   -- `window_decorations = 'NONE',`, so the scan reported zero writers on a
   -- tree that has one and the anti-vacuity check caught it. Match the actual
   -- shape: optional indent, the key, optional spaces, `=`.
   local assign = '^ *' .. key .. ' *='
   local function scan_file(rel)
      local f = io.open(rel, 'r')
      if not f then
         return
      end
      for line in f:lines() do
         local norm = line:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', '')
         -- Only assignment-shaped lines. A comment that says
         -- "window_decorations = 'TITLE'" is documentation, not a writer, and
         -- the tombstone in config/border.lua is allowed to name the value.
         if norm:sub(1, 3) ~= '-- ' and norm:match(assign) then
            table.insert(hits, { file = rel, line = norm })
         end
      end
      f:close()
   end

   scan_file(root .. '/wezterm.lua')
   for _, d in ipairs(SCAN_DIRS) do
      local listing = io.popen(('ls -1 %s 2>/dev/null'):format(("%q"):format(root .. '/' .. d)))
      if listing then
         for name in listing:lines() do
            local rel = root .. '/' .. d .. '/' .. name
            if rel:sub(-4) == '.lua' then
               scan_file(rel)
            end
         end
         listing:close()
      end
   end
   return hits
end

---Writers whose value is exactly `expected`.
---The assignment is anchored so a PROSE mention cannot match: the line must
---START with the key. config/appearance.lua carries
---`-- the ONLY place \`window_decorations\` was set, ...`, and an unanchored
---`find(key .. '=')` matched it and then reported "no 'NONE' writer" for a
---tree that has one.
local function writers_with_value(expected)
   local out = {}
   for _, hit in ipairs(writers_of('window_decorations')) do
      -- hit.line is already whitespace-normalised, so it has NO leading
      -- space. Anchor with ' *' anyway: tolerating leading whitespace is free,
      -- and '^-' alone would fail if normalisation ever changes.
      local assignment = hit.line:match('^ *(window_decorations *= *.+)$')
      if assignment and assignment:find(expected, 1, true) then
         table.insert(out, hit)
      end
   end
   return out
end

local function report(hits)
   if #hits == 0 then
      return 'none'
   end
   local lines = {}
   for _, h in ipairs(hits) do
      table.insert(lines, h.file .. ': ' .. h.line)
   end
   return table.concat(lines, '\n')
end

local title_writers = writers_with_value("'TITLE'")
check(
   "no file writes window_decorations = 'TITLE'",
   #title_writers == 0,
   report(title_writers)
)

-- 6. And the inverse, stated positively: the one legitimate writer must still
--    be there. Without this, deleting config/appearance.lua's line turns checks
--    1-4 red but for the wrong reason, and a "fix" that satisfied them by
--    stripping every mention of the key would look green.
local none_writers = writers_with_value("'NONE'")
local appearance_writes_none = false
for _, hit in ipairs(none_writers) do
   -- plain find, so no %-escaping: find('config/appearance.lua', ..., true)
   if hit.file:find('config/appearance.lua', 1, true) then
      appearance_writes_none = true
   end
end
check(
   "config/appearance.lua still writes window_decorations = 'NONE'",
   appearance_writes_none,
   #none_writers == 0 and 'no writer of the key at all -- it was stripped' or report(none_writers)
)

-- 7. The scan has to be capable of failing. Assert 5 passes on a tree with an
--    armed 'TITLE' writer only if the scan actually finds armed writers, so
--    prove it finds this one: it is still sitting in config/border.lua, which
--    is never required. If this ever reports "none" while check 5 also
--    reports "none", the scan is broken and check 5 is vacuous.
check(
   'the source scan is not vacuous (it can still see an armed writer)',
   #writers_of('window_decorations') >= 1,
   'scan found no mentions of window_decorations at all'
)

print(('\n%d passed, %d failed'):format(pass, fail))
os.exit(fail == 0 and 0 or 1)
