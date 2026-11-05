local wezterm = require('wezterm')
local platform = require('utils.platform')
local backdrops = require('utils.backdrops')
local workspaces = require('utils.workspaces')
local act = wezterm.action

local mod = {}

if platform.is_mac then
   mod.SUPER = 'SUPER'
   mod.SUPER_REV = 'SUPER|CTRL'
elseif platform.is_win or platform.is_linux then
   mod.SUPER = 'ALT' -- to not conflict with Windows key shortcuts
   mod.SUPER_REV = 'ALT|CTRL'
end

-- Wallpaper picker (Alt+p): full-screen live preview of each wallpaper.
-- Enter commits (remembers + runs the theme cascade), Esc/q reverts to the
-- image you had when the picker opened. Browse keys are in the key table.
local wallpaper_picker_original = nil

local function wallpaper_picker_status(window)
   local img = backdrops.images[backdrops.current_idx]
   local name = img and img:match('([^/]+)$') or '?'
   window:toast_notification(
      string.format('Wallpaper %d/%d', backdrops.current_idx, #backdrops.images),
      name,
      1200
   )
end

local picker_prev = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, -1)
   wallpaper_picker_status(window)
end)
local picker_next = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, 1)
   wallpaper_picker_status(window)
end)
local picker_random = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, 0)
   wallpaper_picker_status(window)
end)
local picker_commit = wezterm.action_callback(function(window, pane)
   backdrops:commit(window)
   window:toast_notification('Wallpaper applied', '', 1200)
   window:perform_action(act.PopKeyTable, pane)
end)
local picker_cancel = wezterm.action_callback(function(window, pane)
   if wallpaper_picker_original ~= nil then
      backdrops:preview_jump(window, wallpaper_picker_original)
   end
   window:perform_action(act.PopKeyTable, pane)
end)

-- ---------------------------------------------------------------------------
-- Backdrops control panel (SUPER+o)
--
-- One popup holding every backdrop knob, so they stop being three separate
-- keybindings you have to remember. It reuses the wallpaper_picker's idiom
-- exactly — ActivateKeyTable to push, PopKeyTable to leave, the toast as the
-- status line — so it is the same interaction the picker already trains.
--
-- The toast IS the panel: every action re-renders it. A separate window would
-- need its own input handling, its own theme sync, and a place for a stray
-- keystroke to get stuck; the toast is already themed, already in the corner
-- we want, and already repaints for free.
--
-- Readout labels each knob by what it actually does, because the two alphas
-- are NOT the same lever and the labels are the whole point of the panel:
--   frost wash (k/j)  -> shapes the artwork wezterm draws INSIDE the window.
--                       This is the one you can see.
--   opacity  (h/l)    -> window_background_opacity, which fades toward
--                       whatever the COMPOSITOR painted behind the window.
--                       With no wallpaper daemon running that is Hyprland's
--                       flat background, so it changes almost nothing on
--                       screen. It persists, and it matters the moment a
--                       desktop wallpaper exists — so it stays, labelled
--                       honestly rather than hidden.
-- ---------------------------------------------------------------------------

local function panel_status(window)
   local img = backdrops.images[backdrops.current_idx]
   local name = img and img:match('([^/]+)$') or '?'
   if #name > 34 then
      name = name:sub(1, 31) .. '...'
   end
   window:toast_notification(
      'Backdrops',
      string.format(
         'wash %.2f   opacity %.2f\n%s  %d/%d',
         backdrops.wash,
         backdrops.opacity,
         name,
         backdrops.current_idx,
         #backdrops.images
      ),
      4000
   )
end

-- The panel's own arrows are wrapped rather than reused from the bare
-- SUPER+u / SUPER+y bindings: those toasts fire on every press and would
-- immediately overwrite the panel readout, leaving the panel showing only
-- whichever knob was touched last.
local panel_wash_up = wezterm.action_callback(function(window, _)
   backdrops:adjust_wash(window, 1)
   panel_status(window)
end)
local panel_wash_down = wezterm.action_callback(function(window, _)
   backdrops:adjust_wash(window, -1)
   panel_status(window)
end)
local panel_opacity_up = wezterm.action_callback(function(window, _)
   backdrops:adjust_opacity(window, 1)
   panel_status(window)
end)
local panel_opacity_down = wezterm.action_callback(function(window, _)
   backdrops:adjust_opacity(window, -1)
   panel_status(window)
end)
local panel_wallpaper_next = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, 1)
   panel_status(window)
end)
local panel_wallpaper_prev = wezterm.action_callback(function(window, _)
   backdrops:preview_step(window, -1)
   panel_status(window)
end)
-- Reset lives in the module (backdrops:reset) because the session-start values
-- it targets are captured there, in init(). See its docstring for why it snaps
-- to the target rather than stepping there.
local panel_reset = wezterm.action_callback(function(window, _)
   backdrops:reset(window)
   panel_status(window)
end)
local panel_close = wezterm.action_callback(function(window, pane)
   window:perform_action(act.PopKeyTable, pane)
end)

local function resize_window(window, delta)
   -- Hyprland (Wayland) integration:
   -- On Wayland/Hyprland, client-side window:set_inner_size() cannot alter the
   -- compositor's window container geometry, which desynchronizes the EGL surface
   -- from the Wayland toplevel and causes severe graphical glitching/tearing.
   -- Delegate the window resize to Hyprland's compositor dispatcher.
   if os.getenv('HYPRLAND_INSTANCE_SIGNATURE') then
      local cmd = string.format('hl.dsp.window.resize({ x = %d, y = %d, relative = true })', delta, delta)
      local spawn = wezterm.background_child_process or wezterm.run_child_process
      local ok = pcall(spawn, { 'hyprctl', 'dispatch', cmd })
      if not ok then
         pcall(spawn, { 'hyprctl', 'dispatch', 'resizeactive', string.format('%d %d', delta, delta) })
      end
      return
   end

   local dimensions = window:get_dimensions()
   -- On Windows or fullscreen, set_inner_size can freeze or break UI
   if platform.is_win or dimensions.is_full_screen then
      return
   end
   local new_width = math.max(300, dimensions.pixel_width + delta)
   local new_height = math.max(200, dimensions.pixel_height + delta)
   window:set_inner_size(new_width, new_height)
end

-- stylua: ignore
---@type Key[]
local keys = {
   -- misc/useful --
   { key = 'F1', mods = 'NONE', action = act.ActivateCopyMode },
   { key = 'F2', mods = 'NONE', action = act.ActivateCommandPalette },
   -- F6: symbol/emoji picker — browse glyphs (nerd icons, box drawing,
   -- emoji) from the installed fallback fonts, Enter inserts into the pane.
   { key = 'F6', mods = 'NONE', action = act.CharSelect },
   { key = 'F3', mods = 'NONE', action = act.ShowLauncher },
   { key = 'F4', mods = 'NONE', action = act.ShowLauncherArgs({ flags = 'FUZZY|TABS' }) },
   {
      key = 'F5',
      mods = 'NONE',
      action = act.ShowLauncherArgs({ flags = 'FUZZY|WORKSPACES' }),
   },
   { key = 'F11', mods = 'NONE',    action = act.ToggleFullScreen },
   { key = 'F12', mods = 'NONE',    action = act.ShowDebugOverlay },
   { key = 'f',   mods = mod.SUPER, action = act.Search({ CaseInSensitiveString = '' }) },
   {
      key = 'u',
      mods = mod.SUPER_REV,
      action = wezterm.action.QuickSelectArgs({
         label = 'open url',
         patterns = {
            '\\((https?://\\S+)\\)',
            '\\[(https?://\\S+)\\]',
            '\\{(https?://\\S+)\\}',
            '<(https?://\\S+)>',
            '\\bhttps?://\\S+[)/a-zA-Z0-9-]+'
         },
         action = wezterm.action_callback(function(window, pane)
            local url = window:get_selection_text_for_pane(pane)
            wezterm.log_info('opening: ' .. url)
            wezterm.open_with(url)
         end),
      }),
   },

   -- cursor movement --
   { key = 'Backspace',  mods = mod.SUPER,     action = act.SendString('\u{15}') },
   -- NO Alt+Left / Alt+Right here. They were SendString('\u{1b}OH') /
   -- ('\u{1b}OF') — Home/End, a Windows Terminal habit — and they silently ate
   -- tmux's `bind -n M-Left previous-window` / `M-Right next-window`, because
   -- the emulator resolves the key before the multiplexer ever sees the bytes.
   -- Nothing errored; window cycling just did nothing in wezterm and worked in
   -- kitty, which is the worst version of this bug: one key, two behaviours,
   -- depending on which terminal you launched.
   -- tmux owns windows (see the "Double chrome" rule), so the emulator keeps
   -- no claim on these. Home/End still exist as their own keys.
   -- Guarded by scripts/check-key-collisions.sh.


   -- copy/paste --
   { key = 'c',          mods = 'CTRL|SHIFT',  action = act.CopyTo('Clipboard') },
   { key = 'v',          mods = 'CTRL|SHIFT',  action = act.PasteFrom('Clipboard') },
   -- generic quick-select: type the shown letter to copy that match
   -- (default pattern set: URLs, git hashes, hex colors, filenames...)
   { key = 'Space',      mods = 'CTRL|SHIFT',  action = act.QuickSelect },

   -- tabs --
   -- tabs: spawn+close
   { key = 't',          mods = mod.SUPER,     action = act.SpawnTab('DefaultDomain') },
   { key = 'w',          mods = mod.SUPER_REV, action = act.CloseCurrentTab({ confirm = false }) },

   -- THE wezterm/tmux BRIDGE.
   --
   -- Both layers multiplex, and until now they had no meeting point: wezterm
   -- owned tabs, tmux owned sessions, and moving between projects meant
   -- remembering which layer held what. This key makes a wezterm TAB a tmux
   -- SESSION — one press, pick a project with fzf, and the new tab attaches to
   -- that project's session (creating it and seeding nvim on first visit).
   --
   -- It is the same script tmux's `Prefix f` popup runs, reused rather than
   -- reimplemented: inside tmux it would switch-client, and here, with no
   -- $TMUX in the tab's environment, it takes its own documented bare-shell
   -- branch and attaches. One script, two entry points, no divergence.
   --
   -- Why a tab and not a pane: the existing wezterm chrome then describes the
   -- session — tab-title.lua already renders the project basename, process
   -- icon, progress ring and unseen dot — so the tab bar becomes a live
   -- overview of every tmux session you have a tab open for. Nothing about
   -- tmux changes; the outer layer just stops being blind to it.
   --
   -- SUPER_REV (not bare Alt) deliberately: bare Alt is tmux's root-table
   -- namespace, and taking a key from it is the silent-steal bug this config
   -- has been bitten by four times. scripts/check-key-collisions.sh enforces it.
   -- Detaching the session closes the tab (exit_behavior = CloseOnCleanExit);
   -- the session itself survives in tmux, as sessions do.
   { key = 's',          mods = mod.SUPER_REV, action = act.SpawnCommandInNewTab {
      args = { 'zsh', '-lc', 'exec "$HOME/.config/tmux/sessionizer.sh"' },
   } },

   -- PROJECT TASKS — the same dispatcher zed's tasks, tmux's `Prefix P` and the
   -- pt* shell aliases call: ~/.local/bin/project-task detects the project
   -- (Cargo / package.json + lockfile / pyproject / go.mod / composer+artisan)
   -- and runs the run/test/lint/format command that project actually defines.
   -- fzf picks the action; the task runs in a new TAB so a dev server or watcher
   -- outlives the picker. SUPER_REV, never bare Alt: bare Alt is tmux's root-
   -- table namespace (guarded by scripts/check-key-collisions.sh).
   { key = 'r',          mods = mod.SUPER_REV, action = act.SpawnCommandInNewTab {
      args = { 'zsh', '-lc', 'project-task; exec zsh -l' },
   } },

   -- tabs: navigation
   { key = '[',          mods = mod.SUPER,     action = act.ActivateTabRelative(-1) },
   { key = ']',          mods = mod.SUPER,     action = act.ActivateTabRelative(1) },
   { key = '[',          mods = mod.SUPER_REV, action = act.MoveTabRelative(-1) },
   { key = ']',          mods = mod.SUPER_REV, action = act.MoveTabRelative(1) },

   -- tab: title
   { key = '0',          mods = mod.SUPER,     action = act.EmitEvent('tabs.manual-update-tab-title') },
   { key = '0',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.reset-tab-title') },

   -- tab: hide tab-bar
   -- SUPER_REV, not SUPER: bare Alt+9 is tmux's `bind -n M-9 select-window -t 9`
   -- and the emulator would have won silently. Alt+1..8 were removed for this
   -- exact reason (see the NOTE below); Alt+9 was missed because the tab-bar
   -- toggle looked like chrome. It is chrome — it just picked a key the inner
   -- layer already owned. Guarded by scripts/check-key-collisions.sh.
   { key = '9',          mods = mod.SUPER_REV, action = act.EmitEvent('tabs.toggle-tab-bar'), },

   -- NOTE: no Alt+1..8 tab jumps here on purpose — wezterm would eat the
   -- key before tmux ever sees it, killing tmux's Alt+1..9 window jump
   -- (tmux owns windows/panes; wezterm tabs are the outer chrome, see
   -- the "Double chrome" gotcha in the Obsidian notes).

   -- window --
   -- window: spawn windows
   { key = 'n',          mods = mod.SUPER,     action = act.SpawnWindow },

   -- window: zoom window (shrink / grow 50px)
   {
      key = '-',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         resize_window(window, -50)
      end),
   },
   {
      key = '_',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         resize_window(window, -50)
      end),
   },
   {
      key = '=',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         resize_window(window, 50)
      end),
   },
   {
      key = '+',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         resize_window(window, 50)
      end),
   },
   {
      key = 'Enter',
      mods = mod.SUPER_REV,
      action = wezterm.action_callback(function(window, _pane)
         window:maximize()
      end)
   },

   -- background controls --
   -- Cycle back/forward are bound to BOTH the raw key and its shifted
   -- partner (`,`/`<`, `.`/`>`): on most layouts `<`/`>` are Shift+`,`/`. and
   -- the shift folds into the produced char, so only one form ever matches.
   {
      key = [[/]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:random(window)
      end),
   },
   {
      key = [[,]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = '<',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_back(window)
      end),
   },
   {
      key = [[.]],
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = '>',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:cycle_forward(window)
      end),
   },
   {
      key = [[/]],
      mods = mod.SUPER_REV,
      -- Built at press time (not load time) so the list is re-globbed and
      -- re-fetched every time the picker opens: drop a new wallpaper into
      -- ~/Pictures/wallpaper and it appears here without a wezterm restart.
      action = wezterm.action_callback(function(window, pane)
         window:perform_action(
            act.InputSelector({
               title = 'InputSelector: Select Background',
               choices = backdrops:rescan():choices(),
               fuzzy = true,
               fuzzy_description = 'Select Background: ',
               action = wezterm.action_callback(function(w, _pane, idx)
                  if not idx then
                     return
                  end
                  ---@diagnostic disable-next-line: param-type-mismatch
                  backdrops:set_img(w, tonumber(idx))
               end),
            }),
            pane
         )
      end),
   },
   {
      key = 'b',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         backdrops:toggle_focus(window)
      end)
   },

   -- Background opacity — the "fade the background" control, for when the
   -- vibe changes. SUPER+y solidifies (more opaque, easier to read), SUPER+Shift+y
   -- fades the whole window toward whatever the COMPOSITOR has behind it.
   -- That is Hyprland's background, not wezterm's background.image — and
   -- hyprpaper is not running here, so there is no desktop wallpaper to
   -- reveal. It fades toward flat colour. For artwork alpha use SUPER+u.
   -- This is the only window-level alpha lever in the stack: tmux has none of
   -- its own, so any translucency has to live here, beneath tmux and nvim.
   {
      key = 'y',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local o = backdrops:adjust_opacity(window, 1)
         window:toast_notification(
            'Background opacity',
            string.format('%.2f  (more solid / easier to read)', o)
         )
      end),
   },
   {
      key = 'Y',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local o = backdrops:adjust_opacity(window, -1)
         window:toast_notification(
            'Background opacity',
            string.format('%.2f  (more see-through / more mood)', o)
         )
      end),
   },

   -- Frost wash: how hard the dark wash sits over the wallpaper. SUPER+u /
   -- SUPER+Shift+u shape the ARTWORK (more frost = darker, more flat), which
   -- is a different job from the window alpha above. Only takes effect while
   -- a wallpaper is loaded — in focus mode the background is a flat colour.
   -- (SUPER+w was the first choice but is already CloseCurrentPane; a second
   -- binding on the same key silently kills one of the two.)
   {
      key = 'u',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local w = backdrops:adjust_wash(window, 1)
         window:toast_notification(
            'Frost wash',
            string.format('%.2f  (darker / flatter)', w)
         )
      end),
   },
   {
      key = 'U',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, _pane)
         local w = backdrops:adjust_wash(window, -1)
         window:toast_notification(
            'Frost wash',
            string.format('%.2f  (more artwork / more glass)', w)
         )
      end),
   },

   -- wallpaper picker: full-screen live preview (Enter applies, Esc cancels)
   {
      key = 'p',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, pane)
         if #backdrops.images == 0 then
            return
         end
         wallpaper_picker_original = backdrops.current_idx
         window:toast_notification(
            'Wallpaper picker',
            '← → / h l / , . browse · r random · Enter apply · Esc cancel',
            3000
         )
         window:perform_action(
            act.ActivateKeyTable({
               name = 'wallpaper_picker',
               one_shot = false,
               timeout_milliseconds = 20000,
            }),
            pane
         )
      end),
   },

   -- backdrop control panel: every backdrop knob in one place (SUPER+o)
   {
      key = 'o',
      mods = mod.SUPER,
      action = wezterm.action_callback(function(window, pane)
         panel_status(window)
         window:perform_action(
            act.ActivateKeyTable({
               name = 'backdrops_panel',
               one_shot = false,
               timeout_milliseconds = 20000,
            }),
            pane
         )
      end),
   },

   -- panes --
   -- panes: split panes
   {
      key = [[\]],
      mods = mod.SUPER,
      action = act.SplitVertical({ domain = 'CurrentPaneDomain' }),
   },
   {
      key = [[\]],
      mods = mod.SUPER_REV,
      action = act.SplitHorizontal({ domain = 'CurrentPaneDomain' }),
   },

   -- panes: zoom+close pane
   { key = 'Enter', mods = mod.SUPER,     action = act.TogglePaneZoomState },
   { key = 'w',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },
   { key = 'x',     mods = 'SUPER',       action = act.SendString('\x01x') },

   -- app / window close:
   -- Alt+q (mod.SUPER on Linux) closes the current pane/window (never kills all WezTerm instances).
   -- Alt+Shift+Q quits the entire application.
   { key = 'q',     mods = mod.SUPER,     action = act.CloseCurrentPane({ confirm = false }) },
   { key = 'Q',     mods = mod.SUPER,     action = act.QuitApplication },

   -- workspaces: fast fuzzy switch (Alt+s), new (Alt+Shift+S), key table (Leader+w)
   { key = 'w',     mods = 'LEADER',      action = act.ActivateKeyTable { name = 'workspaces', one_shot = false } },
   { key = 's',     mods = mod.SUPER,     action = wezterm.action_callback(workspaces.switch_workspace) },
   { key = 'S',     mods = mod.SUPER_REV, action = wezterm.action_callback(workspaces.new_workspace) },

   -- NOTE: no Ctrl+Alt+hjkl pane navigation here on purpose — wezterm
   -- would eat the key before tmux ever sees it, killing tmux.nvim's
   -- C-M-hjkl pane-swap binding (tmux owns windows/panes; wezterm is
   -- outer chrome only — see the "Double chrome" gotcha in Obsidian).
   {
      key = 'p',
      mods = mod.SUPER_REV,
      action = act.PaneSelect({ alphabet = '1234567890', mode = 'SwapWithActiveKeepFocus' }),
   },

   -- panes: scroll pane
   -- NOTE: no bare PageUp/PageDown binds — wezterm would eat them before
   -- tmux sees them, killing tmux's `bind -n PageUp copy-mode -u` scrollback
   -- entry. The default (pass through to the app) is what we want.
   -- Semantic shell zones: Shift+PageUp/Down jump directly between command prompts
   {
      key = 'PageUp',
      mods = 'SHIFT',
      action = act.ScrollToPrompt(-1),
   },
   {
      key = 'PageDown',
      mods = 'SHIFT',
      action = act.ScrollToPrompt(1),
   },

   -- key-tables --
   -- resizes fonts
   {
      key = 'f',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_font',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- resize panes
   {
      key = 'p',
      mods = 'LEADER',
      action = act.ActivateKeyTable({
         name = 'resize_pane',
         one_shot = false,
         timeout_milliseconds = 1000,
      }),
   },
   -- quit wezterm (default bindings are disabled, so we add our own)
   -- Use the actual Windows/SUPER key, not ALT (mod.SUPER is ALT on Linux)
   {
      key = 'q',
      mods = 'SUPER',
      action = act.CloseCurrentPane({ confirm = false }),
   },
   {
      key = 'Q',
      mods = 'SUPER',
      action = act.QuitApplication,
   },
}

-- WSL tab. Appended after the table because domains.lua only defines the WSL
-- domains on Windows — off-Windows this spawned a tab against a domain that
-- does not exist. On Linux SUPER_REV is Alt|CTRL, so this was Alt+Ctrl+t.
if platform.is_win then
   table.insert(keys, {
      key = 't',
      mods = mod.SUPER_REV,
      action = act.SpawnTab({ DomainName = 'wsl:ubuntu-fish' }),
   })
end

-- stylua: ignore
---@type table<string, Key[]>
local key_tables = {
   backdrops_panel = {
      { key = 'k',          action = panel_wash_up },
      { key = 'UpArrow',    action = panel_wash_up },
      { key = 'j',          action = panel_wash_down },
      { key = 'DownArrow',  action = panel_wash_down },
      { key = 'l',          action = panel_opacity_up },
      { key = 'RightArrow', action = panel_opacity_up },
      { key = 'h',          action = panel_opacity_down },
      { key = 'LeftArrow',  action = panel_opacity_down },
      { key = 'n',          action = panel_wallpaper_next },
      { key = 'p',          action = panel_wallpaper_prev },
      { key = 'r',          action = panel_reset },
      { key = 'q',          action = panel_close },
      { key = 'Escape',     action = 'PopKeyTable' },
   },
   wallpaper_picker = {
      { key = 'h',          action = picker_prev },
      { key = 'LeftArrow',  action = picker_prev },
      { key = ',',          action = picker_prev },
      { key = 'l',          action = picker_next },
      { key = 'RightArrow', action = picker_next },
      { key = '.',          action = picker_next },
      { key = 'r',          action = picker_random },
      { key = '/',          action = picker_random },
      { key = 'Enter',      action = picker_commit },
      { key = 'q',          action = picker_cancel },
      { key = 'Escape',     action = picker_cancel },
   },
   resize_font = {
      { key = 'k',      action = act.IncreaseFontSize },
      { key = 'j',      action = act.DecreaseFontSize },
      { key = 'r',      action = act.ResetFontSize },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
   resize_pane = {
      { key = 'k',      action = act.AdjustPaneSize({ 'Up', 1 }) },
      { key = 'j',      action = act.AdjustPaneSize({ 'Down', 1 }) },
      { key = 'h',      action = act.AdjustPaneSize({ 'Left', 1 }) },
      { key = 'l',      action = act.AdjustPaneSize({ 'Right', 1 }) },
      { key = 'Escape', action = 'PopKeyTable' },
      { key = 'q',      action = 'PopKeyTable' },
   },
   workspaces = workspaces.key_table,
}

---@type MouseBinding[]
local mouse_bindings = {
   -- Ctrl-click will open the link under the mouse cursor
   {
      event = { Up = { streak = 1, button = 'Left' } },
      mods = 'CTRL',
      action = act.OpenLinkAtMouseCursor,
   },
}

---@type Config
return {
   disable_default_key_bindings = true,
   -- disable_default_mouse_bindings = true,
   leader = { key = 'Space', mods = mod.SUPER_REV },
   keys = keys,
   key_tables = key_tables,
   mouse_bindings = mouse_bindings,
}
