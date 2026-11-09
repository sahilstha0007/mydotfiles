------------------------------------------------------------------------------------------
-- Inspired by https://github.com/wez/wezterm/discussions/628#discussioncomment-1874614 --
------------------------------------------------------------------------------------------

local wezterm = require('wezterm')
local backdrops = require('utils.backdrops')
local Cells = require('utils.cells')
local OptsValidator = require('utils.opts-validator')
local ustr = require('utils.str')

-- Theme tokens resolve the wallpaper direction (light/dark) once per config
-- load: dark branch values match the old mocha chrome exactly, light branch
-- uses latte-tone equivalents so pills/text stay legible on light themes.
local tokens = require('utils.tokens')

local nf = wezterm.nerdfonts
local attr = Cells.attr

---
-- =======================================
-- Defining event setup options and schema
-- =======================================

---@class Event.TabTitleOptionsInput
---@field unseen_icon? 'circle' | 'numbered_circle' | 'numbered_box'
---@field hide_active_tab_unseen? boolean
---@field show_progress? boolean

---@class Event.TabTitleOptions
---@field unseen_icon 'circle' | 'numbered_circle' | 'numbered_box'
---@field hide_active_tab_unseen boolean
---@field show_progress boolean

---Setup options for the tab title
---@type OptsValidator
local EVENT_OPTS = OptsValidator:new({
   {
      name = 'unseen_icon',
      type = 'string',
      enum = { 'circle', 'numbered_circle', 'numbered_box' },
      default = 'circle',
   },
   {
      name = 'hide_active_tab_unseen',
      type = 'boolean',
      default = true,
   },
   {
      name = 'show_progress',
      type = 'boolean',
      default = true,
   },
})

---
-- ===================
-- Constants and icons
-- ===================

local M = {}

---Commit date part of release tag `20250209-182623-44866cc1`
local PROGRESS_MIN_VERSION = 20250209
local PROGRESS_STALE_AFTER = 30 -- seconds

local ICON_SCIRCLE_LEFT = nf.ple_left_half_circle_thick --[[  ]]
local ICON_SCIRCLE_RIGHT = nf.ple_right_half_circle_thick --[[  ]]

-- stylua: ignore
---@enum PrefixIcon
local ICON_PREFIX = {
   admin    = nf.md_shield_half_full, --[[ 󰞀 ]]
   wsl      = nf.cod_terminal_linux,  --[[  ]]
   debug    = nf.fa_bug,              --[[  ]]
   select   = nf.md_selection_search, --[[ 󱈅 ]]
   --  search = '🔭',
   launcher = nf.oct_rocket,          --[[  ]]
   edit     = nf.fa_edit,             --[[  ]]
}

---@enum UnseenOutputIcon
local ICON_UNSEEN = {
   circle = nf.fa_circle, --[[  ]]
   cirlce = nf.fa_circle, --[[  fallback alias ]]

   numbered_box_1 = nf.md_numeric_1_box_multiple, --[[ 󰼏 ]]
   numbered_box_2 = nf.md_numeric_2_box_multiple, --[[ 󰼐 ]]
   numbered_box_3 = nf.md_numeric_3_box_multiple, --[[ 󰼑 ]]
   numbered_box_4 = nf.md_numeric_4_box_multiple, --[[ 󰼒 ]]
   numbered_box_5 = nf.md_numeric_5_box_multiple, --[[ 󰼓 ]]
   numbered_box_6 = nf.md_numeric_6_box_multiple, --[[ 󰼔 ]]
   numbered_box_7 = nf.md_numeric_7_box_multiple, --[[ 󰼕 ]]
   numbered_box_8 = nf.md_numeric_8_box_multiple, --[[ 󰼖 ]]
   numbered_box_9 = nf.md_numeric_9_box_multiple, --[[ 󰼗 ]]
   numbered_box_10 = nf.md_numeric_9_plus_box_multiple, --[[ 󰼘 ]]

   numbered_circle_1 = nf.md_numeric_1_circle, --[[ 󰲠 ]]
   numbered_circle_2 = nf.md_numeric_2_circle, --[[ 󰲢 ]]
   numbered_circle_3 = nf.md_numeric_3_circle, --[[ 󰲤 ]]
   numbered_circle_4 = nf.md_numeric_4_circle, --[[ 󰲦 ]]
   numbered_circle_5 = nf.md_numeric_5_circle, --[[ 󰲨 ]]
   numbered_circle_6 = nf.md_numeric_6_circle, --[[ 󰲪 ]]
   numbered_circle_7 = nf.md_numeric_7_circle, --[[ 󰲬 ]]
   numbered_circle_8 = nf.md_numeric_8_circle, --[[ 󰲮 ]]
   numbered_circle_9 = nf.md_numeric_9_circle, --[[ 󰲰 ]]
   numbered_circle_10 = nf.md_numeric_9_plus_circle, --[[ 󰲲 ]]
}

local ICON_PROGRESS_PCT_FRAMES = {
   [1] = nf.md_circle_slice_1, --[[ 󰪞 ]]
   [2] = nf.md_circle_slice_2, --[[ 󰪟 ]]
   [3] = nf.md_circle_slice_3, --[[ 󰪠 ]]
   [4] = nf.md_circle_slice_4, --[[ 󰪡 ]]
   [5] = nf.md_circle_slice_5, --[[ 󰪢 ]]
   [6] = nf.md_circle_slice_6, --[[ 󰪣 ]]
   [7] = nf.md_circle_slice_7, --[[ 󰪤 ]]
   [8] = nf.md_circle_slice_8, --[[ 󰪥 ]]
}

local ICON_PROGRESS_IND_FRAMES = {
   [1] = '◜',
   [2] = '◠',
   [3] = '◝',
   [4] = '◞',
   [5] = '◡',
   [6] = '◟',
}

local TITLE_INSET = {
   default = 4,
   increment = 2,
}

-- stylua: ignore
---Render Segments
local RS = {
   scircle_left  = 1,
   icon          = 2,
   title         = 3,
   progress      = 4,
   unseen_output = 5,
   padding       = 6,
   scircle_right = 7,
}

-- stylua: ignore
-- luacheck: ignore
---Render Variants
local RV = {
   { RS.scircle_left, RS.padding, RS.title, RS.padding, RS.scircle_right },
   { RS.scircle_left, RS.padding, RS.title, RS.padding, RS.unseen_output, RS.padding, RS.scircle_right },

   { RS.scircle_left, RS.padding, RS.title, RS.padding, RS.progress, RS.padding, RS.scircle_right },
   { RS.scircle_left, RS.padding, RS.title, RS.padding, RS.progress, RS.padding, RS.unseen_output, RS.padding, RS.scircle_right },

   { RS.scircle_left, RS.padding, RS.icon, RS.padding, RS.title, RS.padding, RS.scircle_right },
   { RS.scircle_left, RS.padding, RS.icon, RS.padding, RS.title, RS.padding, RS.unseen_output, RS.padding, RS.scircle_right },

   { RS.scircle_left, RS.padding, RS.icon, RS.padding, RS.title, RS.padding, RS.progress, RS.padding, RS.scircle_right },
   { RS.scircle_left, RS.padding, RS.icon, RS.padding, RS.title, RS.padding, RS.progress, RS.padding, RS.unseen_output, RS.padding, RS.scircle_right },
}


---@type table<string, Cells.SegmentColors>
-- stylua: ignore
local colors = {
   text_default          = { bg = tokens.surface, fg = tokens.on_surface },
   text_hover            = { bg = tokens.surface_hover, fg = tokens.on_surface },
   text_active           = { bg = tokens.accent, fg = tokens.on_accent },

   unseen_output_default = { bg = tokens.surface, fg = tokens.unseen },
   unseen_output_hover   = { bg = tokens.surface_hover, fg = tokens.unseen },
   unseen_output_active  = { bg = tokens.accent, fg = tokens.unseen },

   scircle_default       = { bg = tokens.glass, fg = tokens.surface },
   scircle_hover         = { bg = tokens.glass, fg = tokens.surface_hover },
   scircle_active        = { bg = tokens.glass, fg = tokens.accent },

   progress_percentage_default    = { bg = tokens.surface, fg = tokens.progress_ok },
   progress_percentage_hover      = { bg = tokens.surface_hover, fg = tokens.progress_ok },
   progress_percentage_active     = { bg = tokens.accent, fg = tokens.progress_ok },

   progress_error_default         = { bg = tokens.surface, fg = tokens.progress_error },
   progress_error_hover           = { bg = tokens.surface_hover, fg = tokens.progress_error },
   progress_error_active          = { bg = tokens.accent, fg = tokens.progress_error },

   progress_indeterminate_default = { bg = tokens.surface, fg = tokens.progress_indeterminate },
   progress_indeterminate_hover   = { bg = tokens.surface_hover, fg = tokens.progress_indeterminate },
   progress_indeterminate_active  = { bg = tokens.accent, fg = tokens.progress_indeterminate },
}

---
-- ================
-- Helper functions
-- ================

---@param pct number
local function _pct_to_frame(pct)
   local frame = math.floor(pct * #ICON_PROGRESS_PCT_FRAMES / 100)
   return ICON_PROGRESS_PCT_FRAMES[frame]
end

local __indeter_frame = 1
local function _ind_to_frame()
   local frame = __indeter_frame
   __indeter_frame = (__indeter_frame % #ICON_PROGRESS_IND_FRAMES) + 1
   return ICON_PROGRESS_IND_FRAMES[frame]
end

---@param proc string
local function clean_process_name(proc)
   local a = string.gsub(proc, '.*[/\\](.*)', '%1')
   return a:gsub('%.exe$', '')
end

-- Zoom marker for the active tab. md_fullscreen on a patched font; the ASCII
-- fallback keeps the concat (and the marker) safe on a font that lacks it.
local GLYPH_ZOOM = nf.md_fullscreen or '[Z]'

-- Bell marker, drawn in the same slot as the unseen-output dot (a bell
-- outranks a dot: it is the louder, human-issued signal). One "attention"
-- slot keeps the render tables flat -- a second optional segment would
-- quadruple them.
local GLYPH_BELL = nf.md_bell_ring_outline or '!'

-- Tabs that rang a bell and have not been looked at since: tab_id -> true.
-- wezterm exposes no per-tab bell state in TabInformation, so the `bell`
-- event is the only source; the marker clears when the tab is activated (the
-- format-tab-title handler below). Entries for tabs that die are inert.
local bell_tabs = {}

---Working directory of a PaneInformation snapshot.
---
---`tab.active_pane` in this event is a PaneInformation (a plain snapshot
---table), where the cwd is the FIELD `current_working_dir` — a
---"file://host/path" string. The old code called it as a method
---(`:get_current_working_dir()`), which raised "unknown field" on every tab
---re-render, so the project-name prefix in the tab title never rendered. Read
---the field; keep a pcall'd method fallback for builds that expose one.
---@param pane any
---@return string?
local function pane_cwd(pane)
   if not pane then
      return nil
   end
   if type(pane.current_working_dir) == 'string' and pane.current_working_dir ~= '' then
      return pane.current_working_dir
   end
   local ok, url = pcall(function()
      return pane:get_current_working_dir()
   end)
   if ok and url then
      return tostring(url)
   end
   return nil
end

---Whether a PaneInformation snapshot's pane is zoomed (FIELD), with a method
---fallback. The old `:is_zoomed()` call was inside a pcall, so it failed
---silently and the zoom marker was never drawn.
---@param pane any
---@return boolean
local function pane_zoomed(pane)
   if not pane then
      return false
   end
   if type(pane.is_zoomed) == 'boolean' then
      return pane.is_zoomed
   end
   local ok, z = pcall(function()
      return pane:is_zoomed()
   end)
   return ok and z == true or false
end

---Live Tab id, tolerating both the method and field spellings across builds.
---@param tab any
---@return integer?
local function tab_id_of(tab)
   if not tab then
      return nil
   end
   local ok, id = pcall(function()
      return tab:tab_id()
   end)
   if ok and id ~= nil then
      return id
   end
   return tab.tab_id
end

---Which glyph the attention slot shows, and whether looking clears it. A bell
---outranks unseen output; an ACTIVE tab shows neither (unseen self-clears via
--- pane state, the bell via bell_tabs at the call site).
---
---Exposed as M.attention_icon for tests/check-tab-title.lua.
---@param is_active boolean
---@param bell boolean?
---@param unseen string?
---@param glyph string
---@return string?
local function attention_icon(is_active, bell, unseen, glyph)
   if is_active then
      return nil
   end
   if bell then
      return glyph
   end
   return unseen
end
M.attention_icon = attention_icon

---Basename of wezterm's cwd report ("file://host/home/sahil/work" -> "work";
---$HOME -> "~"). Returns nil when there is nothing to show — a pane that has
---never reported OSC 7 (or an unparseable URL) must fall back to the old
---title form, not render an empty segment.
---@param cwd string?
---@return string?
local function cwd_basename(cwd)
   if not cwd or cwd == '' then
      return nil
   end
   local path = cwd:gsub('^file://[^/]+', ''):gsub('/+$', '')
   if path == '' then
      return nil
   end
   local home = (wezterm.home_dir or ''):gsub('/+$', '')
   if home ~= '' and path == home then
      return '~'
   end
   local base = path:gsub('.*/', '')
   if base == '' then
      return path
   end
   return base
end

---Compose the tab title text before padding. With a reported cwd the project
---basename LEADS ("Atlas ~ Terminal Stack Home.md") — when every tab runs
---nvim, the directory is the differentiator, and the process name is not
---lost: it already lives in the right-status pane-command badge (hud.lua),
---which hides shells and shows the rest. Without a cwd (no OSC 7 yet) the
---original "process ~ title" form stands.
---
---Exposed as M.compose_title so tests/check-tab-title.lua can assert the
---parsing/composition without a live window.
---@param process_name string
---@param cwd string?
---@param base_title string
---@return string
local function compose_title(process_name, cwd, base_title)
   local dir = cwd_basename(cwd)
   if dir then
      return dir .. ' ~ ' .. base_title
   end
   if process_name:len() > 0 then
      return process_name .. ' ~ ' .. base_title
   end
   return base_title
end
M.compose_title = compose_title

-- Exposed so tests/check-tab-title.lua can prove the PaneInformation reads
-- from the FIELD spelling — the bug that made these raise "unknown field" and
-- silently killed the project prefix / zoom marker.
M.pane_cwd = pane_cwd
M.pane_zoomed = pane_zoomed

---@generic T
---@param pane_title string
---@param process_name string
---@return string, PrefixIcon?
local function create_base_title(pane_title, process_name)
   ---@type PrefixIcon|nil
   local prefix_icon = nil
   local base_title = pane_title

   -- if Debug-Overlay is active
   if base_title == 'Debug' then
      prefix_icon = ICON_PREFIX.debug
      base_title = base_title:upper()

   -- if built-in Launcher is active
   elseif base_title == 'Launcher' then
      prefix_icon = ICON_PREFIX.launcher
      base_title = base_title:upper()

   -- if shell is elevated to windows administrator
   elseif
      ustr.starts_with(base_title, 'Administrator:') or ustr.ends_with(base_title, '(Admin)')
   then
      prefix_icon = ICON_PREFIX.admin
      base_title = base_title:gsub('Administrator: ', ''):gsub('%(Admin%)', '')

   -- if shell is wsl instance
   elseif ustr.starts_with(process_name, 'wsl') then
      prefix_icon = ICON_PREFIX.wsl

   -- if `PromptInputLine` or `InputSelector` overlay is active
   elseif ustr.starts_with(base_title, 'InputSelector:') then
      prefix_icon = ICON_PREFIX.select
      base_title = base_title:gsub('InputSelector: ', '')
   elseif ustr.starts_with(base_title, 'InputLine:') then
      prefix_icon = ICON_PREFIX.edit
      base_title = base_title:gsub('InputLine: ', '')
   end

   return base_title, prefix_icon
end

---@param title string pre-composed title text (compose_title + zoom marker)
---@param max_width number
---@param inset number
local function create_title(title, max_width, inset)
   if wezterm.column_width(title) > max_width - inset then
      local diff = wezterm.column_width(title) - max_width + inset
      title = wezterm.truncate_right(title, wezterm.column_width(title) - diff)
   else
      local padding = max_width - wezterm.column_width(title) - inset
      title = title .. string.rep(' ', padding)
   end

   return title
end

local progress_stale = (function()
   -- stylua: ignore
   local status_score = {
      indeterminate = 100,
      error         = 200,
      percentage    = 300,
   }

   ---@type {sum: integer, last_changed: integer}[]
   local entries = {}

   ---Mark progress value as stale if the output hasn't changed in 30 seconds
   ---@param tab_index integer
   ---@param pane_index integer
   ---@param status 'indeterminate'|'error'|'percentage'
   ---@param pct integer
   ---@return boolean `true` if stale
   return function(tab_index, pane_index, status, pct)
      -- shifting by 5 bits, assuming no more than 31 panes will be
      -- spawned in a single tab
      local entry_id = (tab_index << 5) | pane_index

      if not entries[entry_id] then
         entries[entry_id] = {}
         entries[entry_id].sum = status_score[status] + pct
         entries[entry_id].last_changed = os.time()
         return false
      end

      local sum = status_score[status] + pct

      if sum ~= entries[entry_id].sum then
         entries[entry_id].sum = sum
         entries[entry_id].last_changed = os.time()
         return false
      end

      return os.time() - entries[entry_id].last_changed > PROGRESS_STALE_AFTER
   end
end)()

---@param options Event.TabTitleOptions
---@param tab_index integer
---@param panes PaneInformation[]
---@return {icon: string?, status: 'indeterminate'|'percentage'|'error'?}[]
local function check_progress(options, tab_index, panes)
   if not options.show_progress then
      return {}
   end

   local progress = {}
   local limit = 3

   for _, pane in ipairs(panes) do
      if #progress > limit then
         break
      end

      local prog = pane.progress
      local status = nil
      local icon = nil
      local pct = 0

      if prog == 'Indeterminate' then
         status = 'indeterminate'
         icon = _ind_to_frame()
      elseif prog.Percentage ~= nil then
         status = 'percentage'
         icon, pct = _pct_to_frame(prog.Percentage), prog.Percentage
      elseif prog.Error ~= nil then
         status = 'error'
         icon, pct = _pct_to_frame(prog.Error), prog.Error
      end

      if icon and status then
         if not progress_stale(tab_index, pane.pane_index, status, pct) then
            table.insert(progress, { icon = icon, status = status })
         end
      end
   end

   return progress
end

---@param options Event.TabTitleOptions
---@param is_active boolean
---@param panes PaneInformation[]
---@return UnseenOutputIcon|nil
local function check_unseen_output(options, is_active, panes)
   if options.hide_active_tab_unseen and is_active then
      return nil
   end

   local icon = nil

   local count = 0
   local limit = 10

   if options.unseen_icon == 'circle' then
      limit = 0
   end

   for _, pane in ipairs(panes) do
      if count > limit then
         break
      end

      if pane.has_unseen_output then
         count = count + 1
      end
   end

   if count > 0 then
      if options.unseen_icon == 'circle' then
         icon = ICON_UNSEEN[options.unseen_icon]
      else
         icon = ICON_UNSEEN[options.unseen_icon .. '_' .. count]
      end
   end

   return icon
end

---
-- =================
-- Tab class and API
-- =================

local progress_cells = Cells:new():add_segment(RS.progress):add_segment(RS.padding, ' ')
local title_cells = Cells:new()
   :add_segment(RS.scircle_left, ICON_SCIRCLE_LEFT)
   :add_segment(RS.icon)
   :add_segment(RS.title, nil, nil, attr(attr.intensity('Bold')))
   :add_nested_segment(RS.progress)
   :add_segment(RS.unseen_output)
   :add_segment(RS.padding, ' ')
   :add_segment(RS.scircle_right, ICON_SCIRCLE_RIGHT)

---@class Tab
---@field title_locked boolean
---@field locked_title string
---@field has_icon boolean
---@field has_unseen boolean
---@field has_progress boolean
local Tab = {}
Tab.__index = Tab

---@return Tab
function Tab:new()
   local tab = {
      title_locked = false,
      locked_title = '',
      has_icon = false,
      has_unseen = false,
      has_progress = false,
   }

   return setmetatable(tab, self)
end

---@param event_opts Event.TabTitleOptions
---@param tab TabInformation
---@param hover boolean
---@param max_width number
function Tab:update_cells(event_opts, tab, hover, max_width)
   self.has_icon = false
   self.has_unseen = false
   self.has_progress = false

   local tab_state = 'default'
   if tab.is_active then
      tab_state = 'active'
   elseif hover then
      tab_state = 'hover'
   end

   local process_name = clean_process_name(tab.active_pane.foreground_process_name)
   local base_title, prefix_icon = create_base_title(tab.active_pane.title, process_name)
   -- Unseen output icon; a bell on this tab takes the same slot (louder
   -- signal wins), and looking at the tab clears its bell.
   local unseen_icon = check_unseen_output(event_opts, tab.is_active, tab.panes)
   if tab.is_active then
      bell_tabs[tab.tab_id] = nil
   end
   unseen_icon = attention_icon(tab.is_active, bell_tabs[tab.tab_id], unseen_icon, GLYPH_BELL)
   local progress = check_progress(event_opts, tab.tab_index, tab.panes)
   local inset = TITLE_INSET.default

   -- Prefix icons
   if prefix_icon then
      inset = inset + TITLE_INSET.increment
      self.has_icon = true
      title_cells:update_segment_text(RS.icon, prefix_icon)
   end

   -- Unseen output icon
   if unseen_icon then
      inset = inset + TITLE_INSET.increment
      self.has_unseen = true
      title_cells:update_segment_text(RS.unseen_output, unseen_icon)
   end

   -- Progress icons - BEGIN
   inset = inset + (TITLE_INSET.increment * #progress)
   self.has_progress = #progress > 0

   ---@type FormatItem[][]
   local nested_items = {}

   if self.has_progress then
      for i, prog in ipairs(progress) do
         local prog_colors = 'progress_' .. prog.status .. '_' .. tab_state
         progress_cells
            :update_segment_text(RS.progress, prog.icon)
            :update_segment_colors(RS.progress, colors[prog_colors])
            :update_segment_colors(RS.padding, colors['text_' .. tab_state])
         if i == #progress then
            table.insert(nested_items, progress_cells:render({ RS.progress }))
         else
            table.insert(nested_items, progress_cells:render({ RS.progress, RS.padding }))
         end
      end
   end

   title_cells:update_nested_segment(RS.progress, nested_items)
   -- Progress icons - END

   if self.title_locked then
      process_name = ''
      base_title = self.locked_title
      -- A locked title is the user's own label: no cwd, no zoom marker on it.
      title = create_title(compose_title(process_name, nil, base_title), max_width, inset)
   else
      title = compose_title(process_name, pane_cwd(tab.active_pane), base_title)
      -- Zoom marker, front and center on the ACTIVE tab only: a zoomed pane
      -- is indistinguishable from a lone pane otherwise.
      if tab.is_active and pane_zoomed(tab.active_pane) then
         title = GLYPH_ZOOM .. ' ' .. title
      end
      title = create_title(title, max_width, inset)
   end

   title_cells:update_segment_text(RS.title, title)

   -- stylua: ignore
   title_cells
      :update_segment_colors(RS.scircle_left,   colors['scircle_' .. tab_state])
      :update_segment_colors(RS.icon,           colors['text_' .. tab_state])
      :update_segment_colors(RS.title,          colors['text_' .. tab_state])
      :update_segment_colors(RS.unseen_output,  colors['unseen_output_' .. tab_state])
      :update_segment_colors(RS.padding,        colors['text_' .. tab_state])
      :update_segment_colors(RS.scircle_right,  colors['scircle_' .. tab_state])
end

---@param title string
function Tab:update_and_lock_title(title)
   self.locked_title = title
   self.title_locked = true
end

---@return FormatItem[]
function Tab:render()
   local variant_idx = self.has_icon and 5 or 1
   if self.has_unseen then
      variant_idx = variant_idx + 1
   end
   if self.has_progress then
      variant_idx = variant_idx + 2
   end
   return title_cells:render(RV[variant_idx])
end

---@type Tab[]
local tab_list = {}

---NOTE:
---Progress indicator is only available for WezTerm nightly versions `20250209-182623-44866cc1` and onwards.
---If an older version is used, the `show_progress` options will be hard-set to `false`.
---@param opts? Event.TabTitleOptionsInput Default: {unseen_icon = 'circle', hide_active_tab_unseen = true, show_progress = true}
M.setup = function(opts)
   local valid_opts, err = EVENT_OPTS:validate(opts or {})

   if err then
      wezterm.log_error(err)
   end

   ---@cast valid_opts Event.TabTitleOptions

   if tonumber(wezterm.version:sub(1, 8)) < PROGRESS_MIN_VERSION then
      valid_opts.show_progress = false
   end

   -- A bell in ANY pane marks its tab; the marker is drawn (and cleared) by
   -- the format-tab-title handler above. pcall-guarded: a bell from a pane
   -- whose tab cannot be resolved is simply not marked, never an error in
   -- the event path.
   wezterm.on('bell', function(_window, pane)
      local ok, tab = pcall(function()
         return pane:tab()
      end)
      if not ok then
         return
      end
      local id = tab_id_of(tab)
      if id ~= nil then
         bell_tabs[id] = true
      end
   end)

   -- CUSTOM EVENT
   -- Event listener to manually update the tab name
   -- Tab name will remain locked until the `reset-tab-title` is triggered
   wezterm.on('tabs.manual-update-tab-title', function(window, pane)
      local title = nil

      if ustr.ends_with(wezterm.version, 'custom-build') then
         title = 'InputLine: Manual Tab Title'
      end

      window:perform_action(
         wezterm.action.PromptInputLine({
            title = title,
            description = wezterm.format({
               -- theme-aware: white text would vanish on a light overlay
               { Foreground = { Color = tokens.fg } },
               { Attribute = { Intensity = 'Bold' } },
               { Text = 'Enter new name for tab' },
            }),
            action = wezterm.action_callback(function(_window, _pane, line)
               if line ~= nil then
                  local tab = window:active_tab()
                  local id = tab:tab_id()
                  tab_list[id]:update_and_lock_title(line)
               end
            end),
         }),
         pane
      )
   end)

   -- CUSTOM EVENT
   -- Event listener to unlock manually set tab name
   wezterm.on('tabs.reset-tab-title', function(window, _pane)
      ---@cast window Window
      local tab = window:active_tab()
      local id = tab:tab_id()
      tab_list[id].title_locked = false
   end)

   -- CUSTOM EVENT
   -- Event listener to manually update the tab name
   wezterm.on('tabs.toggle-tab-bar', function(window, _pane)
      ---@cast window Window
      local effective_config = window:effective_config()
      -- merge_overrides, not set_config_overrides: the latter REPLACES the whole
      -- table, so building a fresh two-key table here dropped the backdrop's
      -- window_background_opacity and snapped the window back to opaque on
      -- every SUPER+9. `backdrops` is the same singleton appearance.lua holds.
      backdrops:merge_overrides(window, {
         enable_tab_bar = not effective_config.enable_tab_bar,
         background = effective_config.background,
      })
   end)

   -- BUILTIN EVENT
   wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
      if not tab_list[tab.tab_id] then
         tab_list[tab.tab_id] = Tab:new()
      end

      -- `max_width` refers to the `tab_max_width` option set in `config/appearance.lua`
      tab_list[tab.tab_id]:update_cells(valid_opts, tab, hover, max_width)
      return tab_list[tab.tab_id]:render()
   end)
end

return M
