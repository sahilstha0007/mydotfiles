local wezterm = require('wezterm')
local colors = require('colors.custom')

-- Seeding random numbers before generating for use
-- Known issue with lua math library
-- see: https://stackoverflow.com/questions/20154991/generating-uniform-random-numbers-in-lua
math.randomseed(os.time())
math.random()
math.random()
math.random()

local GLOB_PATTERN = '*.{jpg,jpeg,png,gif,bmp,ico,tiff,pnm,dds,tga}'
local WALLPAPER_CACHE = wezterm.home_dir .. '/.cache/wezterm-wallpaper'
-- Downscaled DISPLAY copies (built by utils/cache-wallpapers.sh): wezterm
-- renders these instead of the full-size originals so wallpaper swaps and
-- startup decode in milliseconds. Theming (matugen) always uses originals.
local DISPLAY_CACHE_DIR = wezterm.home_dir .. '/.cache/wezterm-wallpapers'

-- Frost-wash strength: how hard the dark wash is laid over the wallpaper.
-- This shapes the artwork; OPACITY below shapes how much the whole window
-- lets the desktop through. Two knobs, two different jobs — see adjust_wash.
local WASH_CACHE = wezterm.home_dir .. '/.cache/wezterm-wash'
local WASH_DEFAULT = 0.85
local WASH_STEP = 0.04
local WASH_MIN, WASH_MAX = 0.40, 1.0

-- Window background opacity: the real "fade the background" control. 1.0 is
-- solid, lower fades the whole window toward whatever the COMPOSITOR has behind
-- it. Note what that is: Hyprland's background, NOT wezterm's own
-- background.image. On this machine hyprpaper is not running, so there is no
-- desktop wallpaper behind the window and lowering this fades toward flat
-- colour — it will not reveal the artwork. Artwork alpha is `wash` below.
-- Persisted so the mood you pick survives a restart.
local OPACITY_CACHE = wezterm.home_dir .. '/.cache/wezterm-opacity'
local OPACITY_DEFAULT = 0.90
local OPACITY_STEP = 0.05
local OPACITY_MIN, OPACITY_MAX = 0.30, 1.0

---Read a persisted number, or the default if absent/corrupt/out of range.
---@param path string
---@param default number
---@param lo number
---@param hi number
---@return number
local function cached_num(path, default, lo, hi)
   local f = io.open(path, 'r')
   if f then
      local v = tonumber(f:read('*l'))
      f:close()
      if v and v >= lo and v <= hi then
         return v
      end
   end
   return default
end

local function cached_wash()
   return cached_num(WASH_CACHE, WASH_DEFAULT, WASH_MIN, WASH_MAX)
end

local function cached_opacity()
   return cached_num(OPACITY_CACHE, OPACITY_DEFAULT, OPACITY_MIN, OPACITY_MAX)
end

---Round to 2dp and persist. Rounding keeps the cache readable and stops
---float drift from accumulating over many keypresses.
---@param path string
---@param v number
local function persist(path, v)
   local f = io.open(path, 'w')
   if f then
      f:write(string.format('%.2f', v))
      f:close()
   end
end

---The display copy of an image, or the original while the cache is cold.
---@param img string
---@return string
local function display_path(img)
   local name = img:match('([^/\\\\]+)$')
   local stem = name and name:match('^(.*)%.%w+$') or name
   if not stem then
      return img
   end
   local dst = DISPLAY_CACHE_DIR .. '/' .. stem .. '.jpg'
   local f = io.open(dst, 'r')
   if f then
      f:close()
      return dst
   end
   return img
end

-- Last wallpaper sync-wallpaper.sh applied (written before each palette
-- regeneration). Lets a config reload restore the current backdrop instead
-- of reshuffling to a random one — required for live palette reloads.
---@return string|nil absolute path of the cached wallpaper
local function cached_wallpaper()
   local f = io.open(WALLPAPER_CACHE, 'r')
   if not f then
      return nil
   end
   local path = f:read('*l')
   f:close()
   return path
end

---Snap a knob to an exact value: clamp, record, persist, repaint.
---
---Why reset() does NOT step to its target (this replaced two working
---implementations, so the reasoning is the point):
---
---  1. Stepping cannot reach an off-grid target. WASH_DEFAULT is 0.85 with
---     WASH_STEP 0.04, so 0.85 has no neighbours on the step grid — 0.84 and
---     0.88 straddle it. A "step until equal" loop therefore never terminates:
---     it ping-pongs between 0.84 and 0.88 to the iteration bound and returns
---     whichever the bound's parity favours. That was the first real bug.
---  2. Even a bounded walk is pointless here. It was tried — whole steps
---     through the adjusters, then a direct write for the sub-step residue —
---     and the mutation harness showed the walk was UNOBSERVABLE: mutants that
---     inverted the direction, or under-counted the steps, or dropped the
---     residue write entirely, all still passed 61/0. The residue write snapped
---     the value to the target regardless of how the walk got there. So the
---     walk bought ten cache writes and ten config repaints per reset and was
---     cosmetic, which is worse than nothing.
---
---So: one snap, same clamp the adjusters apply, and the same persist+repaint
---tail. It is the adjusters' *stepped* contract that differs — theirs is
---quantized to the grid, and this one is not, deliberately.
---
---@param value number the exact value to land on
---@param field 'wash'|'opacity' the knob to move
---@param lo number that knob's floor
---@param hi number that knob's ceiling
---@param cache string the knob's cache file
---@param window Window? wezterm window; nil just records the value
---@return number the value it landed on
local function snap(self, value, field, lo, hi, cache, window)
   local v = math.floor((math.max(lo, math.min(hi, value)) + 0.005) * 100) / 100
   if v == self[field] then
      return self[field]
   end
   self[field] = v
   persist(cache, v)
   if window ~= nil then
      self:_apply(window, self:_gen_opts())
   end
   return self[field]
end

---@class BackDrops
---@field current_idx number index of current image
---@field images string[] background images
---@field images_dir string directory of background images. Default is `wezterm.config_dir .. '/backdrops/'`
---@field no_img boolean focus mode on or off
---@field wash number frost-wash strength, 0.40 (all-glass) .. 1.0 (opaque)
---@field opacity number window background opacity, OPACITY_MIN .. 1.0
local BackDrops = {}
BackDrops.__index = BackDrops

--- Initialise backdrop controller
---@private
function BackDrops:init()
   local backdrops = {
      current_idx = 1,
      images = {},
      images_dir = wezterm.config_dir .. '/backdrops/',
      no_bg = false,
      wash = cached_wash(),
      opacity = cached_opacity(),
   }
   -- Where a reset() returns to. Captured once, here, because the knobs are
   -- only reachable on the grid they were born on (see reset()).
   backdrops.start_wash = backdrops.wash
   backdrops.start_opacity = backdrops.opacity
   return setmetatable(backdrops, self)
end

---Adjust window background opacity — the "fade the background" control.
---Lower = more desktop shows through, higher = more solid for code. Separate
---from adjust_wash, which only shapes the artwork; this one moves the whole
---window's alpha, and it is the one to reach for when the mood changes.
---@param window Window? wezterm window; nil just records the value
---@param delta number signed steps of OPACITY_STEP
---@return number the new opacity
function BackDrops:adjust_opacity(window, delta)
   local next_op =
      math.floor(((self.opacity + delta * OPACITY_STEP) + 0.005) * 100) / 100
   next_op = math.max(OPACITY_MIN, math.min(OPACITY_MAX, next_op))
   if next_op == self.opacity then
      return self.opacity
   end
   self.opacity = next_op
   persist(OPACITY_CACHE, next_op)

   if window ~= nil then
      -- set_config_overrides REPLACES the whole override table, so this must
      -- go through _apply (or re-read the current overrides) or every
      -- wallpaper change silently resets the opacity back to the config value.
      self:_apply(window, self:_gen_opts())
   end
   return self.opacity
end

---Adjust the frost wash and re-apply it. Shapes how the dark wash sits over
---the wallpaper: higher = darker/flatter for code, lower = more artwork.
---@param window Window? wezterm window; nil just records the value
---@param delta number signed steps of WASH_STEP
---@return number the new wash value
function BackDrops:adjust_wash(window, delta)
   local next_wash = math.floor(((self.wash + delta * WASH_STEP) + 0.005) * 100) / 100
   next_wash = math.max(WASH_MIN, math.min(WASH_MAX, next_wash))
   if next_wash == self.wash then
      return self.wash
   end
   self.wash = next_wash
   persist(WASH_CACHE, next_wash)

   -- `not self.no_img`, NOT `#self.images > 0`: toggle_focus only flips the
   -- flag, it never empties the image list, so the old guard repainted the
   -- wallpaper over the flat focus background while no_img stayed true —
   -- split brain, where the next SUPER+b then toggled nothing visible.
   -- _gen_opts has its own else-branch, so a non-empty list is still implied.
   if window ~= nil and not self.no_img then
      self:_apply(window, self:_gen_opts())
   end
   return self.wash
end

---Put both alphas back to where they started this session.
---
---Why the target is the session start and not WASH_DEFAULT/OPACITY_DEFAULT:
---the session start is the honest meaning of "reset" — back to how the terminal
---looked before I started fiddling. On a cold start the two coincide anyway,
---and on a warm start the session start is the value the user was actually
---looking at, which the file-level default is not.
---
---@param window Window? wezterm window; nil just records the values
---@return number, number the new wash and opacity
function BackDrops:reset(window)
   snap(self, self.start_wash, 'wash', WASH_MIN, WASH_MAX, WASH_CACHE, window)
   snap(self, self.start_opacity, 'opacity', OPACITY_MIN, OPACITY_MAX, OPACITY_CACHE, window)
   return self.wash, self.opacity
end

---The values a reset returns to. Exported so the caller can label the reset
---("back to 0.85 / 0.90") and so the spec can assert reset() hits them rather
---than just "some legal value".
---@return number, number
function BackDrops:defaults()
   return self.start_wash, self.start_opacity
end

---Override the default `images_dir`
---Default `images_dir` is `wezterm.config_dir .. '/backdrops/'`
---
--- INFO:
---  This function must be invoked before `scan_images_dir()`
---
---@param path string directory of background images
function BackDrops:set_images_dir(path)
   self.images_dir = path
   if not path:match('/$') then
      self.images_dir = path .. '/'
   end
   return self
end

---**MUST BE RUN BEFORE ALL OTHER `BackDrops` methods**
---Sets the `images` after instantiating `BackDrops`.
---
--- INFO:
---   During the initial load of the config, this function can only invoked in `wezterm.lua`.
---   WezTerm's fs utility `glob` (used in this function) works by running on a spawned child process.
---   This throws a coroutine error if the function is invoked in outside of `wezterm.lua` in the -
---   initial load of the Terminal config.
function BackDrops:scan_images_dir()
   self.images = wezterm.glob(self.images_dir .. GLOB_PATTERN)
   return self
end

---Filter out files from the loaded `images`.
---Must be invoked after `scan_images_dir()`.
---Filenames may be given with or without the file extension.
---@param files string[] list of filenames to exclude
function BackDrops:exclude_files(files)
   -- Stored (not just applied once) so runtime rescans can re-apply them.
   self.excluded = self.excluded or {}
   for _, file in ipairs(files) do
      local name = file:match('([^/\\]+)$') or file
      self.excluded[name] = true
      local stem = name:match('^(.*)%.%w+$')
      if stem then
         self.excluded[stem] = true
      end
   end
   return self:_apply_excludes()
end

---Filter `self.images` against the stored exclusions (from `exclude_files`)
---@private
function BackDrops:_apply_excludes()
   local excluded = self.excluded or {}
   local filtered = {}
   for _, image in ipairs(self.images) do
      local name = image:match('([^/\\]+)$') or image
      local stem = name:match('^(.*)%.%w+$') or name
      if not excluded[name] and not excluded[stem] then
         table.insert(filtered, image)
      end
   end
   self.images = filtered
   return self
end

---Re-glob the images dir at runtime so newly dropped wallpapers are picked up
---without a config reload, keeping the current image selected by path.
---Exclusions from `exclude_files` are re-applied.
---@param window Window? if given, re-applies the (possibly changed) backdrop
function BackDrops:rescan(window)
   local current = self.images[self.current_idx]
   self:scan_images_dir()
   if self.excluded and next(self.excluded) then
      self:_apply_excludes()
   end

   local found = false
   if current and #self.images > 0 then
      for idx, img in ipairs(self.images) do
         if img == current then
            self.current_idx = idx
            found = true
            break
         end
      end
   end
   if not found then
      self.current_idx = #self.images > 0 and math.random(#self.images) or 1
   end

   -- Newly added wallpapers have no display copy yet: warm the cache in the
   -- background so the next preview/cycle is instant.
   self:ensure_display_cache()

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self
end

---Kick off background generation of the downscaled display copies (skips
---files already cached; the helper script checks mtimes). Safe to call on
---every cycle — it no-ops once the cache is warm.
---@return boolean true if a cache job was spawned
function BackDrops:ensure_display_cache()
   if #self.images == 0 then
      return false
   end
   local missing = false
   for _, img in ipairs(self.images) do
      if display_path(img) == img then
         missing = true
         break
      end
   end
   if not missing then
      return false
   end
   local args = { wezterm.home_dir .. '/.config/wezterm/utils/cache-wallpapers.sh' }
   for _, img in ipairs(self.images) do
      table.insert(args, img)
   end
   local ok = pcall(wezterm.background_child_process, args)
   if not ok then
      wezterm.run_child_process(args)
   end
   return ok
end

---Create the `background` options with the current image
---@private
---@return BackgroundLayer[]
function BackDrops:_gen_opts()
   local bg_opts = {}
   -- One knob for the whole frost wash. Bound to SUPER+y / SUPER+Shift+y
   -- (see config/bindings.lua); adjust_wash persists it to a cache file so
   -- the choice survives a wezterm restart, like the wallpaper choice does.
   local wash = self.wash

   if #self.images > 0 then
      -- wallpaper — the GLASS itself: dimmed so bright code text keeps high
      -- contrast; the image still reads as a wallpaper feature through every
      -- translucent surface.
      table.insert(bg_opts, {
         -- display copy when cached (fast decode); original while warming
         source = { File = display_path(self.images[self.current_idx]) },
         horizontal_align = 'Center',
         hsb = { brightness = 0.85, saturation = 0.95 },
      })
      -- flat frost wash — how much "glass" vs. flat dark you get across the
      -- entire window uniformly with no partition or middle seam.
      table.insert(bg_opts, {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = wash,
      })
   else
      table.insert(bg_opts, {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1,
      })
   end

   return bg_opts
end

---Create the `background` options for focus mode
---@private
---@return BackgroundLayer[]
function BackDrops:_gen_no_img_opts()
   return {
      {
         source = { Color = colors.background },
         height = '120%',
         width = '120%',
         vertical_offset = '-10%',
         horizontal_offset = '-10%',
         opacity = 1,
      },
   }
end

---Set the initial options for `background`
---@param opts {no_img?: boolean} initial options for `background`
function BackDrops:initial_options(opts)
   opts.no_img = opts.no_img or false
   assert(type(opts.no_img) == 'boolean', 'BackDrops:initial_options - Expected a boolean')

   self.no_img = opts.no_img
   if opts.no_img then
      return self:_gen_no_img_opts()
   end

   return self:_gen_opts()
end

---Override the current window options for background
---@private
---@param window Window WezTerm Window see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param background_opts BackgroundLayer[] background option
---Persist the currently chosen wallpaper to the cache file IMMEDIATELY
---(synchronously, before any async theme work finishes). A restart then
---restores exactly what was on screen — even if wezterm quit before the
---background theme worker ran. Without this, closing wezterm right after a
---cycle left the cache pointing at the OLD image and the next start fell
---back to a random wallpaper.
---@private
function BackDrops:_remember()
   local img = self.images[self.current_idx]
   if not img then
      return self
   end
   local f = io.open(WALLPAPER_CACHE, 'w')
   if f then
      f:write(img)
      f:close()
   end
   return self
end

function BackDrops:_set_opt(window, background_opts)
   self:_remember()
   self:_apply(window, background_opts)
end

---Apply background layers to a window WITHOUT remembering the choice or
---syncing the theme — used by the wallpaper preview picker, so browsing is
---instant and side-effect-free. Only `commit`/normal cycling remember + sync.
---@private
---Merge key/value pairs into the window's config overrides.
---
---set_config_overrides REPLACES the whole table rather than merging it, so
---every caller has to start from the overrides already in place. Two call
---sites each used to build a fresh table — this one, and the tab-bar toggle in
---events/tab-title.lua — and whichever ran last silently dropped the other's
---keys. That is how `window_background_opacity` kept resetting itself: the
---backdrop paths all funnel here, but SUPER+9 bypassed here entirely.
---One seam, both callers, no second chance to forget.
---@param window Window
---@param changes table key/value pairs to merge in
function BackDrops:merge_overrides(window, changes)
   local overrides = window:get_config_overrides() or {}
   for k, v in pairs(changes) do
      overrides[k] = v
   end
   window:set_config_overrides(overrides)
end

function BackDrops:_apply(window, background_opts)
   self:merge_overrides(window, {
      background = background_opts,
      enable_tab_bar = window:effective_config().enable_tab_bar,
      window_background_opacity = self.opacity,
   })
end

---Convert the `images` array to a table of `InputSelector` choices
---see: https://wezfurlong.org/wezterm/config/lua/keyassignment/InputSelector.html
function BackDrops:choices()
   local choices = {}
   for idx, file in ipairs(self.images) do
      table.insert(choices, {
         id = tostring(idx),
         label = file:match('([^/]+)$'),
      })
   end
   return choices
end

---Sync the current background to the rest of the environment
---(matugen -> tmux tokens -> zsh-highlight -> herdr -> opencode); the script
---debounces repeats. It does NOT touch hyprpaper or any desktop wallpaper.
function BackDrops:sync()
   local img = self.images[self.current_idx]
   if img ~= nil then
      local args = {
         wezterm.home_dir .. '/.config/wezterm/utils/sync-wallpaper.sh',
         img,
      }
      -- Fire-and-forget: the keypress handler returns the moment the script
      -- is spawned (script itself is instant for repeats, and does the
      -- matugen + reload cascade in its own serialized run). Falls back to
      -- the synchronous spawn where background spawns aren't allowed yet
      -- (e.g. while the config file is being evaluated at startup/reload).
      local ok = pcall(wezterm.background_child_process, args)
      if not ok then
         wezterm.run_child_process(args)
      end
   end
   return self
end

---Select the cached (last-synced) background if it still exists in the
---images dir, otherwise a random one. Deterministic across config reloads:
---sync-wallpaper.sh touches wezterm.lua to reload the palette live, and this
---keeps that reload from reshuffling the user's chosen wallpaper.
---Pass in `Window` object to override the current window options
---@param window Window? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:from_cache_or_random(window)
   local cached = cached_wallpaper()
   local found = false
   if cached then
      local f = io.open(cached, 'r')
      if f then
         f:close()
         for idx, img in ipairs(self.images) do
            if img == cached then
               self.current_idx = idx
               found = true
               break
            end
         end
         if not found then
            table.insert(self.images, cached)
            self.current_idx = #self.images
            found = true
         end
      end
   end
   if not found and #self.images > 0 then
      -- First boot (no cache) or the cached file vanished: pick one and
      -- persist it now so the NEXT start is stable, never random again.
      self.current_idx = math.random(#self.images)
      self:_remember()
   end

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   -- No theme sync here: spawning processes while the config file is being
   -- evaluated is unreliable. events/gui-startup.lua runs the palette
   -- cascade after the first window exists if the shown wallpaper has not
   -- been synced yet, so text colors always follow the displayed image.
   return self
end

---Select a random background from the loaded `files`
---Pass in `Window` object to override the current window options
---@param window Window? WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:random(window)
   self:rescan()
   self.current_idx = math.random(#self.images)

   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self:sync()
end

---Cycle the loaded `files` and select the next background
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_forward(window)
   self:rescan()
   if self.current_idx == #self.images then
      self.current_idx = 1
   else
      self.current_idx = self.current_idx + 1
   end
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Cycle the loaded `files` and select the previous background
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:cycle_back(window)
   self:rescan()
   if self.current_idx == 1 then
      self.current_idx = #self.images
   else
      self.current_idx = self.current_idx - 1
   end
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Is `idx` a valid 1-based image index? Shared by set_img and preview_jump so
---the two guards cannot drift apart again — they did: set_img's own copy read
---`idx < 0`, which in Lua lets 0 through and then indexes a nil image.
---@param idx any
---@return boolean
function BackDrops:_valid_idx(idx)
   return type(idx) == 'number' and idx >= 1 and idx <= #self.images
end

---Set a specific background from the `files` array
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
---@param idx number index of the `files` array
function BackDrops:set_img(window, idx)
   if not self:_valid_idx(idx) then
      wezterm.log_error('Index out of range')
      return
   end

   self.current_idx = idx
   self:_set_opt(window, self:_gen_opts())
   return self:sync()
end

---Preview helpers for the wallpaper picker (Alt+p). They change ONLY the
---backdrop on screen — no cache write, no matugen, no config reload — so
---browsing is instant and free. The two exits are `commit` (keep + theme)
---and `preview_jump` back to the original index (cancel).
---@param window Window
---@param dir integer -1 previous, 0 random, 1 next
function BackDrops:preview_step(window, dir)
   local n = #self.images
   if n == 0 then
      return self
   end
   if dir == 0 then
      self.current_idx = math.random(n)
   else
      self.current_idx = ((self.current_idx - 1 + dir) % n) + 1
   end
   self:_apply(window, self:_gen_opts())
   return self
end

---Jump to a specific image in preview mode (no cache/theme side effects)
---@param window Window
---@param idx number 1-based image index
function BackDrops:preview_jump(window, idx)
   if self:_valid_idx(idx) then
      self.current_idx = idx
      self:_apply(window, self:_gen_opts())
   end
   return self
end

---Commit the previewed wallpaper: remember it as the chosen one and run the
---theme cascade (matugen -> tmux tokens -> reload) in the background.
---@param window Window
function BackDrops:commit(window)
   self:_remember()
   if window ~= nil then
      self:_set_opt(window, self:_gen_opts())
   end
   return self:sync()
end

---Toggle the focus mode
---@param window Window WezTerm `Window` see: https://wezfurlong.org/wezterm/config/lua/window/index.html
function BackDrops:toggle_focus(window)
   local background_opts = self.no_img and self:_gen_opts() or self:_gen_no_img_opts()
   self.no_img = not self.no_img

   self:_set_opt(window, background_opts)
end

return BackDrops:init()
