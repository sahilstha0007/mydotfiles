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

local _script_dir = (arg and arg[0] and arg[0]:match('^(.*)[/\\][^/\\]+$')) or '.'
local root = dofile(_script_dir .. '/lib/resolve_root.lua')('check-tab-title.lua', arg)

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
   column_width = function(s)
      return #s
   end,
   truncate_right = function(s, n)
      return s:sub(1, n)
   end,
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

local ok_load, tab_title = pcall(require, 'events.tab-title')
check('events.tab-title loads through the real chain', ok_load, ok_load and nil or tab_title)
if not ok_load then
   os.exit(1)
end

local compose = tab_title.compose_title
check('compose_title exposed for this check', type(compose) == 'function')

-- ---- cases -----------------------------------------------------------------
-- Signal ownership (C4): cwd belongs to OMP prompt, so reported OSC 7 cwd
-- keeps base_title without prepending a directory basename.
check(
   'cwd url: omits cwd prefix (owned by OMP)',
   compose('nvim', 'file://e810e2b3f0b4/home/sahil/Documents/Notes/Atlas', 'Terminal Stack Home.md')
      == 'Terminal Stack Home.md'
)

-- $HOME does not prepend a directory prefix either
check(
   'home-relative dir omits cwd prefix',
   compose('zsh', 'file://host' .. HOME_DIR .. '/docs', 'readme.md') == 'readme.md',
   compose('zsh', 'file://host' .. HOME_DIR .. '/docs', 'readme.md')
)

-- the exact HOME path (not a child of it)
check(
   'exact home dir -> base_title only',
   compose('zsh', 'file://host' .. HOME_DIR, 'init.lua') == 'init.lua',
   compose('zsh', 'file://host' .. HOME_DIR, 'init.lua')
)

-- no OSC 7 cwd -> minimal fallback keeps "process ~ base_title"
check('nil cwd falls back to process', compose('nvim', nil, 'main.rs') == 'nvim ~ main.rs')
check('empty cwd falls back to process', compose('nvim', '', 'main.rs') == 'nvim ~ main.rs')

-- no process and no cwd -> bare title (locked-title path)
check('no process, no cwd -> bare title', compose('', nil, 'my session') == 'my session')

-- a cwd with a trailing slash (valid OSC 7 path) still omits directory prefix
check(
   'trailing-slash cwd omits directory prefix',
   compose('zsh', 'file://host/home/sahil/work/', 'x') == 'x',
   compose('zsh', 'file://host/home/sahil/work/', 'x')
)

-- gsub edge: cwd that is only "file://host" (no path) -> process fallback
check(
   'pathless cwd url falls back to process',
   compose('nvim', 'file://e810e2b3f0b4', 'notes.md') == 'nvim ~ notes.md',
   compose('nvim', 'file://e810e2b3f0b4', 'notes.md')
)

-- ---- PaneInformation field reads ------------------------------------------
-- Regression: `tab.active_pane` is a PaneInformation snapshot whose cwd and
-- zoom state are FIELDS (current_working_dir / is_zoomed). The code called
-- them as methods, which raised "unknown field" on every tab re-render, so the
-- project prefix and zoom marker never drew. These cases lock the field path.
local pane_cwd = tab_title.pane_cwd
local pane_zoomed = tab_title.pane_zoomed
check('pane_cwd exposed for this check', type(pane_cwd) == 'function')
check('pane_zoomed exposed for this check', type(pane_zoomed) == 'function')

check(
   'pane_cwd reads the current_working_dir FIELD',
   pane_cwd({ current_working_dir = 'file://host/home/sahil/work' })
      == 'file://host/home/sahil/work'
)
check(
   'pane_cwd ignores a non-string field',
   pane_cwd({ current_working_dir = function() end }) == nil
)
check('pane_cwd tolerates a nil pane', pane_cwd(nil) == nil)
check('pane_cwd falls back to the method spelling', pane_cwd({
   get_current_working_dir = function()
      return 'file://h/x'
   end,
}) == 'file://h/x')

check('pane_zoomed reads the is_zoomed FIELD', pane_zoomed({ is_zoomed = true }) == true)
check('pane_zoomed false field stays false', pane_zoomed({ is_zoomed = false }) == false)
check('pane_zoomed tolerates a nil pane', pane_zoomed(nil) == false)
-- Method-spelling fallback: no boolean field, only a callable is_zoomed.
check('pane_zoomed falls back to the method spelling', pane_zoomed(setmetatable({}, {
   __index = function(_, k)
      if k == 'is_zoomed' then
         return function()
            return true
         end
      end
   end,
})) == true)

-- ---- attention slot: bell outranks unseen, active tab shows nothing -------
local attn = tab_title.attention_icon
check('attention_icon exposed for this check', type(attn) == 'function')

check('bell outranks unseen dot', attn(false, true, 'dot', '!') == '!')
check('bell alone fills the slot', attn(false, true, nil, '!') == '!')
check('no bell: unseen dot survives', attn(false, nil, 'dot', '!') == 'dot')
check('nothing to show: empty slot', attn(false, nil, nil, '!') == nil)
check('active tab shows neither', attn(true, true, 'dot', '!') == nil)

-- ---- C3: wcwidth-aware UTF-8 & path truncation with '…' ------------------
local ustr = require('utils.str')
local create_title = tab_title.create_title
check('create_title exposed for truncation tests', type(create_title) == 'function')
check(
   'display_width CJK double-width',
   ustr.display_width('中文标题') == 8,
   ustr.display_width('中文标题')
)
check(
   'display_width emoji double-width',
   ustr.display_width('🚀🔥abc') == 7,
   ustr.display_width('🚀🔥abc')
)
check(
   'display_width ZWJ emoji cluster single 2-cell width',
   ustr.display_width('👨‍👩‍👧a') == 3,
   ustr.display_width('👨‍👩‍👧a')
)

if type(create_title) == 'function' then
   local function rstrip(s)
      return (s:gsub('%s+$', ''))
   end

   local long_ascii = 'build-and-deploy-microservice-production-target'
   local t_ascii = create_title(long_ascii, 26, 4) -- target = 22
   check(
      'long title appends ellipsis and stays <= target width',
      ustr.ends_with(rstrip(t_ascii), '…') and ustr.display_width(t_ascii) == 22,
      t_ascii
   )

   local long_cjk = '这是一个非常长的中文标签页标题测试字符串'
   local t_cjk = create_title(long_cjk, 18, 4) -- target = 14
   check(
      'CJK title truncates cleanly by display columns with ellipsis',
      ustr.ends_with(rstrip(t_cjk), '…') and ustr.display_width(t_cjk) == 14,
      t_cjk .. ' (w=' .. tostring(ustr.display_width(t_cjk)) .. ')'
   )

   local long_emoji = '🚀🔥✨🎯📦⚙️🧪🎉hello-world'
   local t_emoji = create_title(long_emoji, 14, 4) -- target = 10
   check(
      'emoji title truncates at grapheme boundary with ellipsis',
      ustr.ends_with(rstrip(t_emoji), '…') and ustr.display_width(t_emoji) == 10,
      t_emoji .. ' (w=' .. tostring(ustr.display_width(t_emoji)) .. ')'
   )

   local deep_200 = '/home/sahil/workspace/'
      .. string.rep('nested-component/', 10)
      .. 'target-file.lua'
   check('200-char path fixture length > 200', #deep_200 > 200, #deep_200)
   local t_path = create_title(deep_200, 30, 4) -- target = 26
   check(
      '200-char path preserves basename and truncates middle with ellipsis',
      t_path:find('…/', 1, true) ~= nil
         and ustr.ends_with(rstrip(t_path), 'target-file.lua')
         and ustr.display_width(t_path) == 26,
      t_path
   )

   local cmd_200 = 'nvim ' .. deep_200
   local t_cmd_path = create_title(cmd_200, 32, 4) -- target = 28
   check(
      'command + 200-char path preserves both command and basename',
      ustr.starts_with(t_cmd_path, 'nvim ')
         and t_cmd_path:find('…/', 1, true) ~= nil
         and ustr.ends_with(rstrip(t_cmd_path), 'target-file.lua')
         and ustr.display_width(t_cmd_path) == 28,
      t_cmd_path
   )
end

print(string.format('tab-title composition: %d pass, %d fail', pass, fail))
os.exit(fail == 0 and 0 or 1)
