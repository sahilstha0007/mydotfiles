-- Test: tab-title's cwd parsing and title composition, plus the zoom marker
-- path's guard behavior.
--
-- This exists because the title is where the "which project is this tab"
-- signal now lives, and the interesting failures are all in the PARSING:
-- wezterm reports the cwd as a "file://host/path" URL, $HOME must collapse to
-- "~", and a pane that never reported OSC 7 must fall back to the old
-- "process ~ title" form instead of rendering an empty segment or crashing.
-- A live-window check cannot see any of that without attaching a client; a
-- unit check on the pure functions can.
--
-- Run: luajit tests/check-tab-title.lua <config-root>
-- Exit: 0 = composition behaves, 1 = a case failed

local root = assert(arg[1], 'usage: check-tab-title.lua <config-root>')

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

local HOME_DIR = os.getenv('HOME') or '/home/sahil'
_G.wezterm = {
   home_dir = HOME_DIR,
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
   column_width = function(s) return #s end,
   truncate_right = function(s, n) return s:sub(1, n) end,
   gui = {
      enumerate_gpus = function() return {} end,
      get_guids = function() return {} end,
   },
}
package.loaded['wezterm'] = _G.wezterm

local ok_load, tab_title = pcall(require, 'events.tab-title')
check('events.tab-title loads through the real chain', ok_load,
      ok_load and nil or tab_title)
if not ok_load then
   os.exit(1)
end

local compose = tab_title.compose_title
check('compose_title exposed for this check', type(compose) == 'function')

-- ---- cases -----------------------------------------------------------------
-- cwd URL -> basename leads, process dropped (it lives in the hud badge)
check('cwd url: basename leads',
      compose('nvim', 'file://e810e2b3f0b4/home/sahil/Documents/Notes/Atlas',
              'Terminal Stack Home.md') == 'Atlas ~ Terminal Stack Home.md')

-- $HOME collapses
check('home-relative dir shows its basename',
      compose('zsh', 'file://host' .. HOME_DIR .. '/docs', 'readme.md')
         == 'docs ~ readme.md',
      compose('zsh', 'file://host' .. HOME_DIR .. '/docs', 'readme.md'))

-- the exact HOME path (not a child of it)
check('exact home dir -> "~"',
      compose('zsh', 'file://host' .. HOME_DIR, 'init.lua') == '~ ~ init.lua',
      compose('zsh', 'file://host' .. HOME_DIR, 'init.lua'))

-- no cwd -> old process-prefixed form
check('nil cwd falls back to process',
      compose('nvim', nil, 'main.rs') == 'nvim ~ main.rs')
check('empty cwd falls back to process',
      compose('nvim', '', 'main.rs') == 'nvim ~ main.rs')

-- no process and no cwd -> bare title (locked-title path)
check('no process, no cwd -> bare title',
      compose('', nil, 'my session') == 'my session')

-- a cwd with a trailing slash keeps a usable base
check('trailing-slash cwd',
      compose('zsh', 'file://host/home/sahil/work/', 'x') == 'work ~ x',
      compose('zsh', 'file://host/home/sahil/work/', 'x'))

-- gsub edge: cwd that is only "file://host" (no path) -> process fallback
check('pathless cwd url falls back to process',
      compose('nvim', 'file://e810e2b3f0b4', 'notes.md') == 'nvim ~ notes.md',
      compose('nvim', 'file://e810e2b3f0b4', 'notes.md'))

-- ---- PaneInformation field reads ------------------------------------------
-- Regression: `tab.active_pane` is a PaneInformation snapshot whose cwd and
-- zoom state are FIELDS (current_working_dir / is_zoomed). The code called
-- them as methods, which raised "unknown field" on every tab re-render, so the
-- project prefix and zoom marker never drew. These cases lock the field path.
local pane_cwd = tab_title.pane_cwd
local pane_zoomed = tab_title.pane_zoomed
check('pane_cwd exposed for this check', type(pane_cwd) == 'function')
check('pane_zoomed exposed for this check', type(pane_zoomed) == 'function')

check('pane_cwd reads the current_working_dir FIELD',
      pane_cwd({ current_working_dir = 'file://host/home/sahil/work' })
         == 'file://host/home/sahil/work')
check('pane_cwd ignores a non-string field',
      pane_cwd({ current_working_dir = function() end }) == nil)
check('pane_cwd tolerates a nil pane', pane_cwd(nil) == nil)
check('pane_cwd falls back to the method spelling',
      pane_cwd({ get_current_working_dir = function() return 'file://h/x' end })
         == 'file://h/x')

check('pane_zoomed reads the is_zoomed FIELD',
      pane_zoomed({ is_zoomed = true }) == true)
check('pane_zoomed false field stays false',
      pane_zoomed({ is_zoomed = false }) == false)
check('pane_zoomed tolerates a nil pane', pane_zoomed(nil) == false)
-- Method-spelling fallback: no boolean field, only a callable is_zoomed.
check('pane_zoomed falls back to the method spelling',
      pane_zoomed(setmetatable({}, {
         __index = function(_, k)
            if k == 'is_zoomed' then
               return function() return true end
            end
         end,
      })) == true)

-- ---- attention slot: bell outranks unseen, active tab shows nothing -------
local attn = tab_title.attention_icon
check('attention_icon exposed for this check', type(attn) == 'function')

check('bell outranks unseen dot',
      attn(false, true, 'dot', '!') == '!')
check('bell alone fills the slot',
      attn(false, true, nil, '!') == '!')
check('no bell: unseen dot survives',
      attn(false, nil, 'dot', '!') == 'dot')
check('nothing to show: empty slot',
      attn(false, nil, nil, '!') == nil)
check('active tab shows neither',
      attn(true, true, 'dot', '!') == nil)

print(string.format('tab-title composition: %d pass, %d fail', pass, fail))
os.exit(fail == 0 and 0 or 1)
