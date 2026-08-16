-- Terminal-adopting colorscheme.
--
-- Instead of a fixed wallpaper-derived palette (the old matugen theme), nvim
-- queries the terminal emulator it runs inside for its actual palette and
-- adopts it. Both kitty and wezterm answer OSC 4 (colors 0-15), OSC 10 (fg)
-- and OSC 11 (bg) queries, and both push updated OSC 4 sequences to running
-- apps when the terminal colorscheme changes — so nvim re-tints live when you
-- switch themes in the terminal.
--
-- Mechanics (documented in :h TermResponse):
--   * vim.api.nvim_ui_send("\027]4;N;?\027\\") asks the host terminal for
--     color index N; the response arrives as a TermResponse event.
--   * The 16 ANSI colors + fg/bg are mapped onto catppuccin's semantic slots
--     (base/surface/text/overlay + accents) via color_overrides, so every
--     catppuccin integration (treesitter, blink, gitsigns, snacks, trouble,
--     neo-tree, lualine, bufferline, …) follows the terminal automatically.
--   * If the terminal never answers (no OSC support / non-tty, or nvim runs
--     inside tmux which eats OSC queries), we fall back to reading the ACTIVE
--     terminal's config file — kitty's colors-*.conf or wezterm's
--     colors/custom.lua (ml4w writes both on theme switch). The file is
--     detected from env vars (KITTY_WINDOW_ID / WEZTERM_PANE, which survive
--     into tmux) and polled for live re-tints. If no palette source answers,
--     we keep stock catppuccin mocha — the config degrades gracefully.

local M = {}

-- ---------------------------------------------------------------------------
-- Palette state
-- ---------------------------------------------------------------------------
local pal = {
  ansi = {}, -- [0..15] -> '#rrggbb'
  fg = nil,  -- OSC 10
  bg = nil,  -- OSC 11
}

-- True once the 16 ANSI colors have been collected. fg/bg are optional —
-- build_overrides falls back to catppuccin defaults for those.
local function complete()
  for i = 0, 15 do
    if not pal.ansi[i] then
      return false
    end
  end
  return true
end

-- ---------------------------------------------------------------------------
-- Color helpers
-- ---------------------------------------------------------------------------
-- Convert a color response component to an 8-bit hex channel.
-- Terminals answer with rgb:RRRR/GGGG/BBBB (16-bit, kitty/wezterm) or
-- rgb:RR/GG/BB (8-bit).
local function chan(v)
  local n = tonumber(v, 16)
  if n >= 0x100 then
    n = math.floor(n / 257)
  end
  return n
end

-- Parse an OSC color spec into '#rrggbb'. Handles rgb:RRRR/GGGG/BBBB,
-- rgba:RRRR/GGGG/BBBB/AAAA (alpha ignored) and #rrggbb.
local function parse_color(spec)
  if not spec then
    return nil
  end
  local r, g, b = spec:match 'rgba?:%s*(%x+)/(%x+)/(%x+)'
  if r and g and b then
    return string.format('#%02x%02x%02x', chan(r), chan(g), chan(b))
  end
  local hex = spec:match '#(%x%x%x%x%x%x)'
  if hex then
    return '#' .. hex
  end
  return nil
end

-- Mix two '#rrggbb' colors by fraction t (0..1) toward the second.
local function mix(a, b, t)
  local function rgb(hex)
    return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  end
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  local function ch(x, y)
    return string.format('%02x', math.floor(x + (y - x) * t + 0.5))
  end
  return '#' .. ch(ar, br) .. ch(ag, bg) .. ch(ab, bb)
end

-- Saturation (0..1) of a '#rrggbb' color. Terminal palettes occasionally map
-- accent slots to grays — ml4w's kitty theme uses #e0e2e8 for green AND cyan,
-- which washes the whole UI out gray when adopted wholesale. We only adopt an
-- accent when it is actually colorful; gray slots keep catppuccin mocha's own
-- vibrant accent instead.
local function saturation(hex)
  local r = tonumber(hex:sub(2, 3), 16)
  local g = tonumber(hex:sub(4, 5), 16)
  local b = tonumber(hex:sub(6, 7), 16)
  local max, min = math.max(r, g, b), math.min(r, g, b)
  if max == min then
    return 0
  end
  return (max - min) / (255 - math.abs(max + min - 255))
end

-- Pick an accent from an ANSI pair (base + bright). Prefers the bright variant
-- (terminals design those to read on dark backgrounds), falling back to the
-- base variant when only that one is colorful. Returns nil when both are gray
-- — the caller then keeps catppuccin's own accent.
local ACCENT_MIN_SAT = 0.2
local function acc(idx, bright)
  local base, bv = pal.ansi[idx], pal.ansi[bright]
  if bv and saturation(bv) >= ACCENT_MIN_SAT then
    return bv
  end
  if base and saturation(base) >= ACCENT_MIN_SAT then
    return base
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Map the terminal palette onto catppuccin mocha slots
-- ---------------------------------------------------------------------------
local MOCHA_DEFAULTS = {
  base = '#1e1e2e', text = '#cdd6f4', surface0 = '#313244', surface1 = '#45475a',
  surface2 = '#585b70', overlay0 = '#6c7086', overlay1 = '#7f849c', overlay2 = '#9399b2',
  blue = '#89b4fa', lavender = '#b4befe', sapphire = '#74c7ec', sky = '#89dceb',
  teal = '#94e2d5', green = '#a6e3a1', yellow = '#f9e2af', peach = '#fab387',
  red = '#f38ba8', maroon = '#eba0ac', mauve = '#cba6f7', pink = '#f5c2e7',
  flamingo = '#f2cdcd', rosewater = '#f5e0dc',
}

-- Build catppuccin `color_overrides` from the collected terminal palette.
-- Falls back to catppuccin's own mocha defaults for any slot we never learned.
local function build_overrides()
  local base = pal.bg or MOCHA_DEFAULTS.base
  local text = pal.fg or MOCHA_DEFAULTS.text
  -- Surfaces are derived from bg/fg blends, never from ANSI slots: ml4w puts a
  -- light gray (#e0e2e8) in slot 8, which made menus/popups look like washed-
  -- out gray boxes when adopted as surface0.
  local surface0 = mix(base, text, 0.08)

  return {
    base = base,
    mantle = mix(base, '#000000', 0.15),
    crust = mix(base, '#000000', 0.3),
    surface0 = surface0,
    surface1 = mix(surface0, text, 0.12),
    surface2 = mix(surface0, text, 0.25),
    overlay0 = mix(text, base, 0.68),
    overlay1 = mix(text, base, 0.55),
    overlay2 = mix(text, base, 0.4),
    text = text,
    subtext0 = mix(text, base, 0.3),
    subtext1 = mix(text, base, 0.15),
    -- accents straight from the terminal — but only when actually colorful;
    -- gray slots fall back to catppuccin mocha's own accents (see acc above)
    blue = acc(4, 12) or MOCHA_DEFAULTS.blue,
    lavender = acc(4, 12) or MOCHA_DEFAULTS.lavender,
    sapphire = acc(6, 14) or MOCHA_DEFAULTS.sapphire,
    sky = acc(6, 14) or MOCHA_DEFAULTS.sky,
    teal = acc(6, 14) or MOCHA_DEFAULTS.teal,
    green = acc(2, 10) or MOCHA_DEFAULTS.green,
    yellow = acc(3, 11) or MOCHA_DEFAULTS.yellow,
    peach = acc(3, 11) or MOCHA_DEFAULTS.peach,
    red = acc(1, 9) or MOCHA_DEFAULTS.red,
    maroon = acc(1, 9) or MOCHA_DEFAULTS.maroon,
    mauve = acc(5, 13) or MOCHA_DEFAULTS.mauve,
    pink = acc(5, 13) or MOCHA_DEFAULTS.pink,
    flamingo = acc(1, 9) or MOCHA_DEFAULTS.flamingo,
    rosewater = MOCHA_DEFAULTS.rosewater,
  }
end

-- ---------------------------------------------------------------------------
-- catppuccin options (same design language as the old matugen theme, but
-- colors are sourced from the terminal instead of a wallpaper).
-- ---------------------------------------------------------------------------
local function catppuccin_opts()
  return {
    flavour = 'mocha',
    transparent_background = true, -- let kitty/wezterm opacity show through
    color_overrides = { mocha = build_overrides() },
    integrations = {
      neo_tree           = true,
      treesitter         = true,
      blink_cmp          = true,
      gitsigns           = true,
      which_key          = true,
      telescope          = { enabled = true },
      mini               = { enabled = true },
      snacks             = true,
      lsp_trouble        = true,
      treesitter_context = true,
      ufo                = true,
      flash              = true,
    },
    highlight_overrides = {
      mocha = function(c)
        return {
          -- Explorer blends with terminal
          NeoTreeNormal        = { bg = 'NONE', fg = c.text },
          NeoTreeNormalNC      = { bg = 'NONE' },
          NeoTreeEndOfBuffer   = { bg = 'NONE' },
          NeoTreeWinSeparator  = { fg = c.surface1, bg = 'NONE' },
          NeoTreeRootName      = { fg = c.blue, bold = true },
          NeoTreeDirectoryName = { fg = c.blue },
          NeoTreeDirectoryIcon = { fg = c.blue },
          NeoTreeFileName      = { fg = c.text },
          NeoTreeFileIcon      = { fg = c.subtext0 },
          NeoTreeGitAdded      = { fg = c.green },
          NeoTreeGitModified   = { fg = c.yellow },
          NeoTreeGitUntracked  = { fg = c.mauve },
          NeoTreeIndentMarker  = { fg = c.overlay0 },

          -- Popup: frosted — winblend/pumblend (options.lua) blend these
          -- toward the terminal background, so the tint + blend reads as glass.
          Pmenu      = { bg = c.surface0, fg = c.text },
          PmenuSel   = { bg = c.surface1, fg = c.blue, bold = true },
          PmenuSbar  = { bg = c.surface1 },
          PmenuThumb = { bg = c.blue },

          -- blink.cmp
          BlinkCmpLabel         = { fg = c.text },
          BlinkCmpLabelMatch    = { fg = c.blue, bold = true },
          BlinkCmpLabelDetail   = { fg = c.overlay1 },
          BlinkCmpMenuBorder    = { fg = c.surface1 },
          BlinkCmpMenuSelection = { bg = c.surface1, fg = c.blue, bold = true },
          BlinkCmpDoc           = { bg = c.surface0 },
          BlinkCmpDocBorder     = { fg = c.surface1 },
          BlinkCmpGhostText     = { fg = c.overlay0 },
          BlinkCmpKindFunction  = { fg = c.blue },
          BlinkCmpKindMethod    = { fg = c.blue },
          BlinkCmpKindVariable  = { fg = c.red },
          BlinkCmpKindConstant  = { fg = c.yellow },
          BlinkCmpKindClass     = { fg = c.yellow },
          BlinkCmpKindKeyword   = { fg = c.mauve },
          BlinkCmpKindSnippet   = { fg = c.green },
          BlinkCmpKindText      = { fg = c.subtext0 },
          BlinkCmpKindProperty  = { fg = c.subtext0 },

          -- contrast polish for dim palettes
          Search      = { bg = c.blue, fg = c.base },
          Visual      = { bg = c.surface1 },
          MatchParen  = { bg = c.surface1, fg = c.blue, bold = true },
          WinSeparator = { fg = c.surface1 },

          -- Floating windows (hover, diagnostics popup, dressing): frosted
          -- glass — tinted body + a slightly lighter border so the rounded
          -- edges read against the transparent editor. winblend=25 (from
          -- options.lua) does the see-through; these are the tint layers.
          FloatBorder = { fg = c.surface2 },
          NormalFloat = { bg = c.surface0, fg = c.text },
        }
      end,
    },
  }
end

-- ---------------------------------------------------------------------------
-- Terminal query + live update
-- ---------------------------------------------------------------------------
local function query()
  local q = {}
  for i = 0, 15 do
    q[#q + 1] = string.format('\027]4;%d;?\027\\', i)
  end
  -- fg (OSC 10) and bg (OSC 11)
  q[#q + 1] = '\027]10;?\027\\\027]11;?\027\\'
  pcall(vim.api.nvim_ui_send, table.concat(q))
end

-- Re-run catppuccin setup + colorscheme with the current palette.
-- color_overrides changed => catppuccin recompiles its cache and re-tints.
local function apply()
  local opts = catppuccin_opts()
  local ok, err = pcall(function()
    require('catppuccin').setup(opts)
    vim.cmd.colorscheme 'catppuccin'
  end)
  if not ok then
    vim.notify('terminal-colors: ' .. tostring(err), vim.log.levels.ERROR)
  end
end

local apply_timer
local function schedule_apply()
  if apply_timer then
    apply_timer:stop()
  else
    apply_timer = vim.uv.new_timer()
  end
  -- debounce: kitty/wezterm answer the 18 queries in a burst. The timer
  -- callback can fire inside vim.wait() (a fast event context) where
  -- vim.notify/snacks would crash — defer via vim.schedule to a normal
  -- context before touching catppuccin or any UI.
  apply_timer:start(40, 0, function()
    vim.schedule(apply)
  end)
end

-- A single TermResponse event may carry several OSC responses back-to-back
-- (kitty/wezterm can batch them), so parse every `ESC ] N ; ...` response in
-- order. Returns true when at least one color was newly captured.
local function parse_sequences(seq)
  local changed = false
  for body in seq:gmatch '\027%]([^\027\x07]+)' do
    -- body is "N;spec" (e.g. "4;1;rgb:..." or "11;rgb:...")
    local num, spec = body:match '^(%d+);(.*)$'
    if num and spec then
      if num == '4' then
        local idx, colorspec = spec:match '^(%d+);(.*)$'
        local hex = idx and parse_color(colorspec)
        if hex then
          idx = tonumber(idx)
          if idx >= 0 and idx <= 15 and pal.ansi[idx] ~= hex then
            pal.ansi[idx] = hex
            changed = true
          end
        end
      elseif num == '10' then
        local hex = parse_color(spec)
        if hex and pal.fg ~= hex then
          pal.fg = hex
          changed = true
        end
      elseif num == '11' then
        local hex = parse_color(spec)
        if hex and pal.bg ~= hex then
          pal.bg = hex
          changed = true
        end
      end
    end
  end
  return changed
end

local function on_termresponse(ev)
  local seq = ev.data.sequence or ''
  if parse_sequences(seq) and complete() then
    schedule_apply()
  end
end

-- ---------------------------------------------------------------------------
-- Fallback source: the terminal's own config file
-- ---------------------------------------------------------------------------
-- OSC queries only reach the terminal when nvim is DIRECTLY attached to it.
-- Under tmux (this setup's normal case) tmux eats the queries and answers
-- nothing, so OSC adoption silently fails. Both kitty and wezterm keep their
-- palette in a config file on disk (ml4w writes them on theme switch), so
-- read the ACTIVE terminal's file as the authoritative fallback — works
-- inside tmux and updates when the file changes.

local palette_file = nil -- resolved palette file once found

-- Which terminal are we inside? Env vars survive into tmux (verified:
-- WEZTERM_PANE and KITTY_WINDOW_ID both propagate). WEZTERM_PANE wins when
-- both are set — that happens when wezterm itself is launched from a kitty
-- window, and nvim's palette should follow the terminal it's ACTUALLY in.
local function detect_terminal()
  if vim.env.WEZTERM_PANE or vim.env.TERM_PROGRAM == 'WezTerm' then
    return 'wezterm'
  elseif vim.env.KITTY_WINDOW_ID or vim.env.TERM_PROGRAM == 'kitty' then
    return 'kitty'
  end
  return nil
end

-- Follow `include` lines in a kitty config file. Returns a list of
-- { path, content } pairs for every file in the chain (resolved relative
-- to the kitty config dir).
local function read_kitty_with_includes(path, depth)
  depth = depth or 0
  if depth > 4 then
    return {}
  end
  local f = io.open(path, 'r')
  if not f then
    return {}
  end
  local content = f:read '*a'
  f:close()
  local out = { { path = path, content = content } }
  for line in content:gmatch '[^\n]+' do
    local inc = line:match '^%s*include%s+([^%s]+)'
    if inc then
      local incpath = inc:gsub('%$HOME', vim.env.HOME or '')
      if not vim.startswith(incpath, '/') then
        incpath = vim.fs.dirname(path) .. '/' .. incpath
      end
      local sub = read_kitty_with_includes(incpath, depth + 1)
      for _, s in ipairs(sub) do
        out[#out + 1] = s
      end
    end
  end
  return out
end

-- Parse kitty color directives (color0..color15, foreground, background) into
-- pal. Returns true when the 16 ANSI colors were all found. Tracks the file
-- that supplied the colors so the live watcher can poll it (ml4w re-writes
-- colors-matugen.conf on theme switch).
local function read_kitty_palette()
  local home = vim.env.HOME or ''
  local conf = home .. '/.config/kitty/kitty.conf'
  local files = read_kitty_with_includes(conf)
  if #files == 0 then
    return false
  end

  local found = {}
  for _, file in ipairs(files) do
    for line in file.content:gmatch '[^\n]+' do
      -- skip /* */ block comments and # comments
      local key, val = line:match '^%s*([%w_]+)%s+(#[%x]+)'
      if key and val and not line:match '^%s*/%*' then
        local hex = val:match '^#(%x%x%x%x%x%x)$'
        if hex then
          hex = '#' .. hex
          local idx = key:match '^color(%d+)$'
          if idx then
            idx = tonumber(idx)
            if idx >= 0 and idx <= 15 then
              pal.ansi[idx] = hex
              found[idx] = true
              palette_file = file.path
            end
          elseif key == 'foreground' then
            pal.fg = hex
          elseif key == 'background' then
            pal.bg = hex
          end
        end
      end
    end
  end
  for i = 0, 15 do
    if not found[i] then
      return false
    end
  end
  return true
end

-- Parse wezterm's colorscheme file (~/.config/wezterm/colors/*.lua — ml4w
-- writes colors/custom.lua). It's a Lua table `colorscheme` with `ansi` and
-- `brights` arrays + foreground/background, so load and read it. Returns true
-- when the 16 ANSI colors were all found.
local function read_wezterm_palette()
  local home = vim.env.HOME or ''
  local conf = home .. '/.config/wezterm/colors/custom.lua'
  local f = io.open(conf, 'r')
  if not f then
    return false
  end
  local src = f:read '*a'
  f:close()
  local fn, err = loadstring(src)
  if not fn then
    vim.notify('terminal-colors: wezterm palette parse: ' .. tostring(err), vim.log.levels.WARN)
    return false
  end
  local ok, cs = pcall(fn)
  if not ok or type(cs) ~= 'table' or not cs.ansi then
    return false
  end

  local found = {}
  local function set(i, hex)
    if type(hex) == 'string' and hex:match '^#[%x][%x][%x][%x][%x][%x]$' then
      pal.ansi[i] = hex
      found[i] = true
      palette_file = conf
    end
  end
  for i = 0, 7 do
    set(i, cs.ansi[i + 1]) -- ansi[1..8] are colors 0..7
  end
  for i = 8, 15 do
    set(i, cs.brights and cs.brights[i - 7]) -- brights[1..8] are colors 8..15
  end
  if type(cs.foreground) == 'string' then
    pal.fg = cs.foreground
  end
  if type(cs.background) == 'string' then
    pal.bg = cs.background
  end
  for i = 0, 15 do
    if not found[i] then
      return false
    end
  end
  return true
end

-- Read the active terminal's palette file into pal.
local function read_terminal_palette()
  local term = detect_terminal()
  if term == 'wezterm' then
    return read_wezterm_palette()
  end
  -- kitty (or unknown terminal): try kitty's file; wezterm's as a last resort
  return read_kitty_palette() or read_wezterm_palette()
end

-- Re-read the palette file and report whether any ANSI color changed.
local function poll_palette_file()
  local before = vim.deepcopy(pal.ansi)
  local ok = read_terminal_palette()
  if not ok then
    return false
  end
  for i = 0, 15 do
    if pal.ansi[i] ~= before[i] then
      return true
    end
  end
  return false
end

-- Poll the palette file every few seconds while inside tmux (where OSC is
-- dead) so theme switches re-tint live without needing focus changes.
local watch_timer
local function start_palette_watch()
  if not vim.env.TMUX then
    return -- OSC live updates already cover the direct-terminal case
  end
  if watch_timer then
    return
  end
  watch_timer = vim.uv.new_timer()
  watch_timer:start(3000, 3000, vim.schedule_wrap(function()
    if palette_file and poll_palette_file() and complete() then
      apply()
    end
  end))
end

-- ---------------------------------------------------------------------------
-- Setup
-- ---------------------------------------------------------------------------
local augroup
local function setup()
  augroup = vim.api.nvim_create_augroup('terminal-colors', { clear = true })
  vim.api.nvim_create_autocmd('TermResponse', {
    group = augroup,
    callback = on_termresponse,
  })

  -- Paint immediately with the fallback palette so startup never flashes raw
  -- nvim defaults, then ask the terminal for its palette. The responses fire
  -- as TermResponse events (processed during vim.wait) and re-tint within a
  -- few tens of milliseconds.
  apply()
  query()
  vim.wait(300, complete, 5)
  if not complete() then
    -- tmux eats OSC queries; fall back to reading the terminal's config file.
    read_terminal_palette()
  end
  if complete() then
    apply()
  end

  -- Live updates: kitty/wezterm push OSC 4 to the app when the terminal
  -- colorscheme changes (caught by on_termresponse). Under tmux OSC is dead,
  -- so poll the terminal's palette file instead. Re-query on focus too, in
  -- case the palette changed while nvim was unfocused.
  start_palette_watch()
  vim.api.nvim_create_autocmd('FocusGained', {
    group = augroup,
    callback = function()
      vim.schedule(function()
        query()
        -- also re-read the palette file (covers tmux where OSC is dead)
        if poll_palette_file() and complete() then
          schedule_apply()
        end
      end)
    end,
  })
end

M.setup = setup

-- ---------------------------------------------------------------------------
-- lazy.nvim spec
-- ---------------------------------------------------------------------------
return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    lazy = false,
    priority = 1000,
    config = function()
      setup()
    end,
  },
  {
    'LazyVim/LazyVim',
    opts = { colorscheme = 'catppuccin-mocha' },
  },
}
