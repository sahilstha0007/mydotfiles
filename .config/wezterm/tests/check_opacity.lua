-- Task 1 test: window background opacity is controllable at runtime.
--
-- What "controllable" has to mean, precisely, because the obvious version of
-- this test passes on a broken config:
--
--   1. SUPER+y / SUPER+Y must reach adjust_opacity with a signed delta, and
--      the resulting number must land in the window's config overrides.
--   2. The clamp must actually clamp. Without a bounds check a runaway key
--      repeat walks opacity past 1.0 (wezterm rejects >1) or below OPACITY_MIN.
--   3. At the ceiling/floor the value must STOP MOVING, and the caller must be
--      able to see that (adjust_opacity returns the value; bindings toast it).
--   4. The value must PERSIST. An opacity knob that forgets on restart is not
--      controllable, it is a per-session accident.
--   5. The whole path must be idempotent per keypress: one press, one step.
--      A binding that fires twice per press moves 0.10 not 0.05.
--
-- Mutation target: any edit that breaks 1-5 must turn this red. Verified by
-- /tmp/mutate-check-backdrops.sh, which re-runs it against a patched copy.
--
-- Run: luajit tests/check_opacity.lua <config-root>
--   (FAKE_HOME must point at a throwaway dir — the opacity cache is written
--    under it, and this test must never write to the user's real ~/.cache)

local root = assert(arg[1], 'usage: check_opacity.lua <config-root>')
local home = os.getenv('FAKE_HOME')
assert(home, 'FAKE_HOME must be set to a throwaway dir')
-- persist() writes home .. '/.cache/<name>' with a plain io.open — no mkdir. It
-- worked before only because the directory already existed, which made the
-- suite silently depend on a pre-made sandbox. Create it here so the suite is
-- self-contained; the cache can only ever land under FAKE_HOME, never in the
-- real ~/.cache.
os.execute('mkdir -p ' .. home .. '/.cache')
package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path

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

-- ---- mock wezterm ---------------------------------------------------------
-- set_config_overrides REPLACES the whole table in the real wezterm. A mock
-- that merges would pass a broken config that drops keys.
_G.wezterm = {
   home_dir = home,
   config_dir = root,
   target_triple = 'x86_64-unknown-linux-gnu',
   os = 'Linux',
   log_error = function() end,
   log_info = function() end,
   log_error_at = function() end,
   on = function() end,
   action_callback = function(fn) return fn end,
   background_child_process = function() error('no bg spawn in sandbox') end,
   run_child_process = function() return 0 end,
   glob = function() return { '/pics/a.jpg', '/pics/b.jpg', '/pics/c.jpg' } end,
   nerdfonts = setmetatable({}, { __index = function() return '' end }),
   to_notification = function(_, a, b, c) return { title = a, body = b, timeout = c } end,
   config_dir = root,
   version = '20260716-102532-2ef4bef4',
   action = setmetatable({}, {
      __index = function()
         return function() end
      end,
   }),
   format = function(t) return t end,
   open_with = function() end,
   toast_notification = function() end,
   -- config/appearance.lua pulls in utils/gpu-adapter.lua, which enumerates
   -- real GPUs at load time. There are none in a headless sandbox, so stub
   -- the minimum surface it reads.
   gui = {
      enumerate_gpus = function() return {} end,
      get_guids = function() return {} end,
   },
}
package.loaded['wezterm'] = _G.wezterm
package.loaded['wezterm.config'] = { enable_tab_bar = true }

local function new_window()
   local w = { _ov = nil, _eff = { enable_tab_bar = true } }
   function w:get_config_overrides() return self._ov end
   function w:effective_config() return self._eff end
   function w:set_config_overrides(t)
      self._ov = t -- real semantics: replace
   end
   function w:toast_notification() end
   return w
end

local function cachefile()
   return home .. '/.cache/wezterm-opacity'
end

-- Clears BOTH caches, not just the opacity one. The wash cache used to survive
-- a clear_cache(), so any check that stepped wash left ~/.cache/wezterm-wash
-- behind and every later "fresh instance" read it. That is what made CHECK 8
-- fail intermittently on a correct tree.
local function clear_cache()
   os.remove(cachefile())
   os.remove(home .. '/.cache/wezterm-wash')
end

-- ===========================================================================
print('=== CHECK 1: bindings exist and are wired to adjust_opacity ===')
-- ===========================================================================
do
   -- Drive the REAL key table, not a re-implementation of it. Re-writing the
   -- binding body here is what makes a spec lie: it would pass even if the
   -- shipped binding pointed at the wrong function.
   local bd = require('utils.backdrops')
   bd.images = { '/pics/a.jpg', '/pics/b.jpg', '/pics/c.jpg' }
   bd.current_idx = 1

   local ok_bind, bindings = pcall(require, 'config.bindings')
   check('config/bindings.lua loads', ok_bind, bindings)
   local keys = ok_bind and bindings.keys or {}
   check('bindings exposes a key table', type(keys) == 'table', type(keys))

   local function find(key, mods)
      for _, k in ipairs(keys) do
         if k.key == key and k.mods == mods then
            return k
         end
      end
   end

   local up = find('y', 'ALT') -- SUPER == ALT on linux
   local down = find('Y', 'ALT')
   check('SUPER+y (solidify) binding exists', up ~= nil, 'no ALT+y')
   check('SUPER+Shift+y (fade) binding exists', down ~= nil, 'no ALT+Y')

   if up and down then
      -- One press = one step. Capture the delta the binding passes.
      local seen = {}
      local real_adj = bd.adjust_opacity
      bd.adjust_opacity = function(self, _w, delta)
         table.insert(seen, delta)
         return real_adj(self, _w, delta)
      end

      clear_cache()
      bd.opacity = 0.5
      local w = new_window()
      local ok1, e1 = pcall(up.action, w, nil)
      check('SUPER+y runs without error', ok1, e1)
      local ok2, e2 = pcall(down.action, w, nil)
      check('SUPER+Shift+y runs without error', ok2, e2)

      local deltas = {}
      for _, d in ipairs(seen) do
         table.insert(deltas, tostring(d))
      end
      check('exactly one adjust per press (2 presses, 2 calls)', #seen == 2,
         'got ' .. #seen .. ' calls, deltas: ' .. table.concat(deltas, ','))
      check('SUPER+y passes a POSITIVE delta (toward solid)', seen[1] == 1, tostring(seen[1]))
      check('SUPER+Shift+y passes a NEGATIVE delta (toward fade)', seen[2] == -1, tostring(seen[2]))
      bd.adjust_opacity = real_adj
   end
end

-- ===========================================================================
print('=== CHECK 2: the step lands in the window overrides ===')
-- ===========================================================================
do
   local bd = require('utils.backdrops')
   local w = new_window()
   clear_cache()
   bd.opacity = 0.50
   bd:adjust_opacity(w, 1)
   check('opaque direction raises the value', bd.opacity == 0.55, tostring(bd.opacity))
   check('override carries the new opacity',
      w._ov and w._ov.window_background_opacity == 0.55,
      tostring(w._ov and w._ov.window_background_opacity))
   check('override is a NUMBER, not a string',
      type(w._ov and w._ov.window_background_opacity) == 'number',
      type(w._ov and w._ov.window_background_opacity))

   bd:adjust_opacity(w, -1)
   check('fade direction lowers the value', bd.opacity == 0.50, tostring(bd.opacity))
   check('override follows the second press',
      w._ov and w._ov.window_background_opacity == 0.50,
      tostring(w._ov and w._ov.window_background_opacity))
end

-- ===========================================================================
print('=== CHECK 3: the clamp clamps (and the caller can see it stopped) ===')
-- ===========================================================================
do
   local bd = require('utils.backdrops')
   local w = new_window()
   clear_cache()

   bd.opacity = 1.0
   local at_ceiling = bd:adjust_opacity(w, 1)
   check('cannot exceed 1.0 (wezterm rejects >1)', bd.opacity == 1.0, tostring(bd.opacity))
   check('returns the clamped value so the toast shows the real number', at_ceiling == 1.0,
      tostring(at_ceiling))

   -- Hammer the ceiling: key repeat must not drift past it. The in-memory
   -- value is the assertion that matters here — a press that lands ON the
   -- ceiling is a deliberate no-op in adjust_opacity (line 153-155), so it
   -- never calls _apply and the window override keeps whatever the last
   -- *effective* press wrote. The effective value is still 1.0, and nothing
   -- about the window is left in a wrong state.
   for _ = 1, 40 do
      bd:adjust_opacity(w, 1)
   end
   check('40 extra presses at the ceiling stay at 1.0', bd.opacity == 1.0, tostring(bd.opacity))
   local ov = w._ov and w._ov.window_background_opacity
   check('window override is still a legal opacity after the hammer',
      ov == nil or (ov >= 0.30 and ov <= 1.0),
      tostring(ov))

   -- The no-op must not have written anything: count the writes.
   local writes = 0
   local w2 = new_window()
   local real_set = w2.set_config_overrides
   w2.set_config_overrides = function(self, t)
      writes = writes + 1
      return real_set(self, t)
   end
   bd.opacity = 1.0
   for _ = 1, 5 do
      bd:adjust_opacity(w2, 1)
   end
   check('5 clamped presses write ZERO overrides (no redundant repaint)',
      writes == 0, 'wrote ' .. writes .. ' times')

   bd.opacity = 0.30
   local at_floor = bd:adjust_opacity(w, -1)
   check('cannot go below the floor', bd.opacity == 0.30, tostring(bd.opacity))
   check('floor value is returned to the caller', at_floor == 0.30, tostring(at_floor))
   for _ = 1, 40 do
      bd:adjust_opacity(w, -1)
   end
   check('40 extra presses at the floor stay put', bd.opacity == 0.30, tostring(bd.opacity))
end

-- ===========================================================================
print('=== CHECK 4: steps are exactly OPACITY_STEP, with no float drift ===')
-- ===========================================================================
do
   local bd = require('utils.backdrops')
   local w = new_window()
   clear_cache()
   bd.opacity = 1.0
   local seen = {}
   for _ = 1, 8 do
      bd:adjust_opacity(w, -1)
      table.insert(seen, bd.opacity)
   end
   -- 1.00 .95 .90 .85 .80 .75 .70 .65 .60 — a naive `v = v - 0.05` in binary
   -- floats gives 0.8999999999999999 and drifts off the grid; the config
   -- rounds to 2dp precisely so the cache file stays readable.
   local expected = { 0.95, 0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60 }
   local mismatches = {}
   for i, want in ipairs(expected) do
      if seen[i] ~= want then
         table.insert(mismatches, string.format('#%d got %s want %s', i, tostring(seen[i]), tostring(want)))
      end
   end
   check('every step lands exactly on the 0.05 grid', #mismatches == 0, table.concat(mismatches, '; '))
end

-- ===========================================================================
print('=== CHECK 5: the choice PERSISTS across a restart ===')
-- ===========================================================================
do
   local bd = require('utils.backdrops')
   local w = new_window()
   clear_cache()

   bd.opacity = 0.50
   bd:adjust_opacity(w, -1)
   local chosen = bd.opacity
   check('value is written to the cache file', io.open(cachefile(), 'r') ~= nil,
      'no cache file at ' .. cachefile())

   -- read it back through the REAL load path, in a fresh module instance:
   -- a fresh require is the closest thing to a wezterm restart we can get.
   local saved = io.open(cachefile(), 'r')
   local on_disk = saved:read('*l')
   saved:close()
   check('cache holds the chosen value', tonumber(on_disk) == chosen,
      string.format('on disk %q, in memory %s', tostring(on_disk), tostring(chosen)))

   package.loaded['utils.backdrops'] = nil
   local restarted = require('utils.backdrops')
   check('a fresh instance restores the persisted value', restarted.opacity == chosen,
      string.format('restarted at %s, expected %s', tostring(restarted.opacity), tostring(chosen)))

   -- and the config seeds from the SAME cache, so the very first paint matches
   local cs = require('config.appearance')
   check('config.appearance seeds opacity from the cache, not a hardcoded 1.0',
      cs.window_background_opacity == chosen,
      string.format('config seeds %s, cache holds %s',
         tostring(cs.window_background_opacity), tostring(chosen)))
   package.loaded['utils.backdrops'] = bd
end

-- ===========================================================================
print('=== CHECK 6: a corrupt cache falls back instead of poisoning the config ===')
-- ===========================================================================
do
   -- A truncated write (power loss mid-write) leaves a half number. Reading it
   -- as an opacity would hand wezterm a nil/garbage and it rejects the config.
   for _, bad in ipairs({ 'garbage', '', '2.5', '-1', '0.0' }) do
      clear_cache()
      local f = assert(io.open(cachefile(), 'w'))
      f:write(bad)
      f:close()
      package.loaded['utils.backdrops'] = nil
      local fresh = require('utils.backdrops')
      local ok = type(fresh.opacity) == 'number'
         and fresh.opacity >= 0.30
         and fresh.opacity <= 1.0
      check(string.format('corrupt cache %q falls back to a usable value', bad),
         ok, tostring(fresh.opacity))
      package.loaded['utils.backdrops'] = nil
   end
   clear_cache()
   package.loaded['utils.backdrops'] = nil
   local fresh = require('utils.backdrops')
   -- wezterm.lua does the scanning; a bare require does not. Without this the
   -- singleton has an empty image list and set_img/preview_step correctly
   -- bail out early, which reads as a spurious failure.
   fresh.images = { '/pics/a.jpg', '/pics/b.jpg', '/pics/c.jpg' }
   fresh.current_idx = 1
end

-- ===========================================================================
print('=== CHECK 7: opacity survives every other backdrop action ===')
-- ===========================================================================
do
   -- set_config_overrides REPLACES. Any path that rebuilds the override table
   -- without carrying the current opacity silently snaps the window back to
   -- solid. This is the exact failure the merge_overrides seam exists for.
   local bd = require('utils.backdrops')
   local paths = {
      cycle_forward = function(b, win) b:cycle_forward(win) end,
      cycle_back    = function(b, win) b:cycle_back(win) end,
      random        = function(b, win) b:random(win) end,
      preview_step  = function(b, win) b:preview_step(win, 1) end,
      set_img       = function(b, win) b:set_img(win, 2) end,
      adjust_wash   = function(b, win) b:adjust_wash(win, 1) end,
      toggle_focus  = function(b, win) b:toggle_focus(win) end,
   }
   for name, fn in pairs(paths) do
      local w = new_window()
      bd.no_img = false
      bd.opacity = 0.65
      bd.wash = 0.82
      bd.current_idx = 1
      local ok, err = pcall(fn, bd, w)
      check(name .. ' runs without error', ok, err)
      check(name .. ' preserves the opacity',
         w._ov and w._ov.window_background_opacity == 0.65,
         'got ' .. tostring(w._ov and w._ov.window_background_opacity))
   end
   bd.no_img = false
   clear_cache()
end

-- ===========================================================================
print('=== CHECK 8: reset() puts both knobs back to their session start ===')
-- ===========================================================================
do
   -- Start from a module instance seeded by an empty cache, so the "session
   -- start" reset() targets is the one a real cold start sees — not whatever
   -- residue an earlier check left the shared singleton on. CHECK 7 steps wash
   -- by 0.04, which moves it off the 0.82 default and onto a different mod-0.04
   -- class; reusing that instance made this check assert an order-dependent
   -- contract, and it failed on a correct tree for that reason alone.
   clear_cache()
   package.loaded['utils.backdrops'] = nil
   local bd = require('utils.backdrops')
   local w = new_window()
   bd.images = { '/pics/a.jpg', '/pics/b.jpg', '/pics/c.jpg' }
   bd.current_idx = 1
   bd.no_img = false

   -- Drive both knobs as far from home as they go — VIA THE STEPPER, not by
   -- assigning the fields. This is not pedantry: ±step preserves a value's
   -- residue mod step, so a value reached by stepping is only ever walkable
   -- back. Assign 0.40 and you get a value in a different residue class than
   -- the 0.82 start (0.40 ≡ 0.00, 0.82 ≡ 0.02), and NO step walk can ever
   -- cross between the classes — so reset could not reach the start, for a
   -- reason that has nothing to do with reset. Assigning here manufactured an
   -- impossible state and then failed on it. A user can only ever get these
   -- values by pressing keys, so the spec does the same.
   for _ = 1, 40 do
      bd:adjust_wash(w, -1)
      bd:adjust_opacity(w, -1)
   end
   local drifted_wash, drifted_opacity = bd.wash, bd.opacity
   check('the knobs are at the floor after 40 down-steps',
      drifted_wash == 0.40 and drifted_opacity == 0.30,
      string.format('wash %s opacity %s', tostring(drifted_wash), tostring(drifted_opacity)))

   local ok, err = pcall(function()
      bd:reset(w)
   end)
   check('reset() runs without error', ok, err)

   -- The defaults are module-locals the spec cannot read, so it asserts the
   -- OBSERVABLE contract instead: the knobs are inside their bounds, they are
   -- two decimal places, and the window override follows the opacity.
   --
   -- Deliberately NOT "lands on the step grid". The whole bug this check grew
   -- out of is that a correct reset can and must land OFF the grid — a cold
   -- start sits on WASH_DEFAULT 0.85, which has no neighbours on the 0.04
   -- grid. Asserting grid membership here would have rejected the fix and
   -- passed the broken version.
   local function two_dp(v)
      return math.abs(v - math.floor(v * 100 + 0.5) / 100) < 1e-9
   end
   check('wash is back in range', bd.wash >= 0.40 and bd.wash <= 1.0, tostring(bd.wash))
   check('opacity is back in range', bd.opacity >= 0.30 and bd.opacity <= 1.0, tostring(bd.opacity))
   check('both knobs stay 2dp rounded', two_dp(bd.wash) and two_dp(bd.opacity),
      string.format('wash %s opacity %s', tostring(bd.wash), tostring(bd.opacity)))
   check('window override carries the reset opacity',
      w._ov and w._ov.window_background_opacity == bd.opacity,
      'override ' .. tostring(w._ov and w._ov.window_background_opacity) .. ' vs ' .. tostring(bd.opacity))

   -- reset() must PERSIST, not just move the in-memory fields. `window = nil`
   -- here on purpose: a repaint is what writes the override above, so with a
   -- window attached a reset that skipped persist() would still look right.
   -- With none, the only thing that can put a value in the cache is persist.
   local w2 = new_window()
   clear_cache()
   for _ = 1, 40 do
      bd:adjust_wash(w2, -1)
      bd:adjust_opacity(w2, -1)
   end
   bd:reset(nil)
   local of = io.open(cachefile(), 'r')
   local persisted = of and of:read('*a') or nil
   if of then of:close() end
   check('reset persists the opacity to the cache',
      tonumber(persisted) == bd.opacity,
      'cache ' .. tostring(persisted) .. ', in memory ' .. tostring(bd.opacity))
   local wf = io.open(home .. '/.cache/wezterm-wash', 'r')
   local wp = wf and wf:read('*a') or nil
   if wf then wf:close() end
   check('reset persists the wash to the cache',
      tonumber(wp) == bd.wash,
      'cache ' .. tostring(wp) .. ', in memory ' .. tostring(bd.wash))

   -- Idempotent: a second reset must not walk off the value it just reached.
   -- Without the `== break` guards the loop would spin to the bound instead.
   local wash1, op1 = bd.wash, bd.opacity
   bd:reset(w)
   check('reset is idempotent', bd.wash == wash1 and bd.opacity == op1,
      string.format('second reset moved %s -> %s', tostring(wash1), tostring(bd.wash)))

   -- The value it lands on must be the session's starting values, or "reset"
   -- means something different before and after a restart. This is EXACT
   -- equality on purpose, and it is the check that found the real bug: the
   -- first implementation was a "step until equal" loop, which cannot terminate
   -- when the target is off-grid (0.82 has no neighbours on the 0.04 grid, so
   -- 0.80 and 0.84 straddle it). It ping-ponged to the bound and returned
   -- 0.80. Nothing about the value being "close" is good enough here — the
   -- point of reset is to restore a specific state.
   local now_wash, now_opacity = bd:defaults()
   check('reset lands exactly on the session defaults',
      bd.wash == now_wash and bd.opacity == now_opacity,
      string.format('landed %s/%s, defaults are %s/%s',
         tostring(bd.wash), tostring(bd.opacity), tostring(now_wash), tostring(now_opacity)))

   -- THE landing invariant, and the reason snap() exists: a ±step walk only
   -- ever reaches values congruent to its start mod step, so it can step
   -- straight PAST an off-grid target. Assert the target and the landing value
   -- are numerically identical — which is stronger than the old same-grid
   -- check, and is exactly what snap() guarantees.
   check('reset lands on the target itself, not merely on its grid',
      bd.wash == now_wash and bd.opacity == now_opacity,
      string.format('target %s, landed %s', tostring(now_wash), tostring(bd.wash)))
   check('defaults() is a pure read (calling it twice gives the same answer)',
      select(1, bd:defaults()) == now_wash and select(2, bd:defaults()) == now_opacity,
      string.format('%s/%s', tostring(select(1, bd:defaults())), tostring(select(2, bd:defaults()))))

   -- Against a cache-free instance: a fresh require is the closest thing to a
   -- wezterm restart. Its start is WASH_DEFAULT 0.85, which is OFF the 0.04
   -- step grid — so this is the case that a grid-equality check would have
   -- rejected and that a plain "step until equal" walk cannot reach. Drive it
   -- to the far end and back; the walk must return exactly.
   clear_cache()
   package.loaded['utils.backdrops'] = nil
   local cold = require('utils.backdrops')
   local cw = new_window()
   for _ = 1, 30 do
      cold:adjust_wash(cw, -1)
      cold:adjust_opacity(cw, -1)
   end
   cold:reset(cw)
   check('a cold start round-trips back to its own off-grid default',
      cold.wash == select(1, cold:defaults()) and cold.opacity == select(2, cold:defaults()),
      string.format('after 30 down-steps and a reset: %s/%s, default %s/%s',
         tostring(cold.wash), tostring(cold.opacity),
         tostring(select(1, cold:defaults())), tostring(select(2, cold:defaults()))))

   -- THE anti-tautology check, and the one the mutation harness exists for.
   --
   -- Every check above compares bd against bd:defaults() — the module against
   -- ITSELF. That is not a tautology in general (it would catch a wrong
   -- direction, a wrong step count, a dropped persist), but it is blind to one
   -- specific class: a defect in the CAPTURE. Corrupt start_wash and the
   -- module becomes internally consistent about the wrong number, so the
   -- round-trip passes 59/0 while reset() quietly targets a value the user
   -- never had. Mutation M11 did exactly that and the suite stayed green.
   --
   -- So pin the cold start to a number the SPEC owns. 0.85 and 0.90 duplicate
   -- WASH_DEFAULT/OPACITY_DEFAULT (module-locals, unreadable from here) on
   -- purpose: an independent copy is the only thing that can disagree. If you
   -- change a default in utils/backdrops.lua, change it here too — the failure
   -- is the point, and it is a one-line fix in a file you are already editing.
   check('a cold start begins on the documented defaults, not on a corrupted capture',
      cold.wash == 0.85 and cold.opacity == 0.90
         and select(1, cold:defaults()) == 0.85 and select(2, cold:defaults()) == 0.90,
      string.format('cold starts at %s/%s, defaults() reports %s/%s, spec pins 0.85/0.90',
         tostring(cold.wash), tostring(cold.opacity),
         tostring(select(1, cold:defaults())), tostring(select(2, cold:defaults()))))

   -- And the same pin for a WARM start, driven only through the public API: a
   -- cache file the spec writes itself must become the value reset() returns
   -- to. The spec picks 0.68, which is off the 0.04 grid, so this also proves
   -- the off-grid path works for a non-default starting value.
   os.execute('mkdir -p ' .. home .. '/.cache')
   local wf2 = assert(io.open(home .. '/.cache/wezterm-wash', 'w'))
   wf2:write('0.68')
   wf2:close()
   local of2 = assert(io.open(cachefile(), 'w'))
   of2:write('0.75')
   of2:close()
   package.loaded['utils.backdrops'] = nil
   local warm = require('utils.backdrops')
   local ww = new_window()
   warm:reset(ww)
   check('a warm start from an off-grid cached value resets to that exact value',
      warm.wash == 0.68 and warm.opacity == 0.75,
      string.format('reset to %s/%s, cache had 0.68/0.75',
         tostring(warm.wash), tostring(warm.opacity)))

   -- snap()'s clamp and 2dp rounding, on an input the config never produces on
   -- its own. Every value snap() sees in normal use is already 2dp and in
   -- range, so without this both are dead code -- and the mutation harness
   -- proved it: M8 (clamp removed) and M9 (rounding removed) each passed
   -- 61/0. This pins the two lines to a hostile session start, which is
   -- reachable by anyone who hand-edits ~/.cache/wezterm-wash, and keeps them
   -- from being deleted as "unreachable".
   package.loaded['utils.backdrops'] = nil
   local raw = require('utils.backdrops')
   raw.start_wash = 1.2345      -- too many decimals
   raw.start_opacity = 4.0      -- beyond OPACITY_MAX
   local rw = new_window()
   raw:reset(rw)
   check('reset clamps an out-of-range session start', raw.opacity == 1.0, tostring(raw.opacity))
   check('reset rounds a session start to 2dp', raw.wash == 1.0 and two_dp(raw.wash),
      tostring(raw.wash))
   package.loaded['utils.backdrops'] = bd
   clear_cache()
end

print()
print(string.format('RESULT: %d pass, %d fail', pass, fail))
os.exit(fail == 0 and 0 or 1)
