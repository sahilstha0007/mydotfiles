-- Frosted-glass tint: with the terminal at <1 opacity, this reads as
-- glass — wallpaper shows through, the strip is a faint tinted layer,
-- and the active tab raises on top. Kept light (25%) so the strip
-- leans transparent; the active tab's surface1 still lifts it clear.
local function glass_tint(c)
  local function mix(hex_a, hex_b, t)
    local function to_rgb(hex)
      local h = hex:gsub('#', '')
      return tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16)
    end
    local ar, ag, ab = to_rgb(hex_a)
    local br, bg, bb = to_rgb(hex_b)
    return string.format(
      '#%02x%02x%02x',
      math.floor(ar + (br - ar) * t + 0.5),
      math.floor(ag + (bg - ag) * t + 0.5),
      math.floor(ab + (bb - ab) * t + 0.5)
    )
  end
  return mix(c.base, c.surface0, 0.25)
end

-- The full highlight table (shared between opts and the ColorScheme re-tint).
-- c is the live catppuccin palette, glass the tinted strip background.
local function highlights_from(c, glass)
  return {
    -- Frosted-glass strip: a subtle tinted layer (glass) instead of a
    -- solid band or bare transparency. Only the ACTIVE tab carries a
    -- raised background, so the file you're editing is the raised core.
    fill = { fg = c.subtext0, bg = glass },
    -- thin dividers: subtle tone-on-tone bars (underline off — the
    -- underline indicator would otherwise paint a light line here)
    separator = { fg = c.surface2, bg = glass, underline = false },
    separator_selected = { fg = c.surface2, bg = glass, underline = false },
    separator_visible = { fg = c.surface2, bg = glass, underline = false },
    tab_separator = { fg = c.surface2, bg = glass, underline = false },
    tab_separator_selected = { fg = c.surface2, bg = glass, underline = false },
    -- ACTIVE tab: raised background + bold text. Nothing else — no
    -- underline, no indicator (that was the boxy bottom line).
    buffer_selected = {
      bg = c.surface1,
      fg = c.text,
      bold = true,
    },
    indicator_selected = {
      bg = c.surface1,
      fg = c.text,
    },
    -- INACTIVE tabs: quiet text on the glass
    buffer = { bg = glass, fg = c.overlay0 },
    buffer_visible = { bg = glass, fg = c.overlay0 },
    -- Explorer offset area: same glass, subtle separator
    offset_separator = { bg = glass, fg = c.surface1 },
    -- Tab diagnostics (error/warn/info icons): bufferline derives these
    -- from the Normal bg, which is transparent here — so pin the fg to
    -- the palette or they'd render in the terminal's default colors.
    -- Selected variants sit on the raised active tab (surface1).
    error = { fg = c.red, bg = glass },
    error_selected = { fg = c.red, bg = c.surface1 },
    error_visible = { fg = c.red, bg = glass },
    error_diagnostic = { fg = c.red, bg = glass },
    error_diagnostic_selected = { fg = c.red, bg = c.surface1 },
    error_diagnostic_visible = { fg = c.red, bg = glass },
    warning = { fg = c.yellow, bg = glass },
    warning_selected = { fg = c.yellow, bg = c.surface1 },
    warning_visible = { fg = c.yellow, bg = glass },
    warning_diagnostic = { fg = c.yellow, bg = glass },
    warning_diagnostic_selected = { fg = c.yellow, bg = c.surface1 },
    warning_diagnostic_visible = { fg = c.yellow, bg = glass },
    info = { fg = c.cyan, bg = glass },
    info_selected = { fg = c.cyan, bg = c.surface1 },
    info_visible = { fg = c.cyan, bg = glass },
    info_diagnostic = { fg = c.cyan, bg = glass },
    info_diagnostic_selected = { fg = c.cyan, bg = c.surface1 },
    info_diagnostic_visible = { fg = c.cyan, bg = glass },
    hint = { fg = c.subtext0, bg = glass },
    hint_selected = { fg = c.subtext0, bg = c.surface1 },
    hint_visible = { fg = c.subtext0, bg = glass },
    hint_diagnostic = { fg = c.subtext0, bg = glass },
    hint_diagnostic_selected = { fg = c.subtext0, bg = c.surface1 },
    hint_diagnostic_visible = { fg = c.subtext0, bg = glass },
  }
end

return {
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>bp', '<cmd>BufferLinePick<CR>', desc = 'Pick Buffer (tabs)' },
    },
    opts = function()
      local c = require('catppuccin.palettes').get_palette 'mocha'
      local glass = glass_tint(c)

      return {
        options = {
          mode = 'buffers',
          -- tab strip always visible so the file title stays on top
          always_show_bufferline = true,
          show_close_icon = false,
          -- clean: no x buttons on every tab, no per-tab diagnostic counts
          -- (errors/warnings live in the statusline where they're readable)
          show_buffer_close_icons = false,
          -- clean thin dividers — no slanted boxes/triangles between tabs
          separator_style = 'thin',
          -- NO indicator: no underline, no bar, no blob under/on the active
          -- tab — the raised background alone marks the current file (the
          -- "underline" style drew a boxy bottom line, ponytail: gone)
          indicator = { style = 'icon', icon = '' },
          -- no green unsaved-changes dot on tabs
          modified_icon = '',
          offsets = {
            {
              filetype = 'NvimTree',
              text = vim.fn.nr2char(0xF024B) .. ' Explorer', -- md-folder (verified in Nerd Fonts 3.5)
              highlight = 'Directory',
              separator = true,
            },
          },
        },
        -- Design system (translated from the design skills): an Apple-style
        -- frosted-glass strip — a subtle tinted layer (glass), with the
        -- terminal's opacity showing the wallpaper through it. The active tab
        -- is the ONE raised element (surface1); inactive tabs are quiet text
        -- on the glass. Tone-on-tone dividers, no boxes/borders.
        --
        -- NOTE: the theme sets `Normal` bg to transparent, so bufferline
        -- derives nil colors for several groups (they'd render in the
        -- terminal's default white) — every fg below is pinned to a
        -- palette tone on purpose.
        highlights = highlights_from(c, glass),
      }
    end,
    config = function(_, opts)
      require('bufferline').setup(opts)
      -- Re-tint on palette changes: terminal-colors re-runs :colorscheme when
      -- the terminal theme changes (fires ColorScheme). Recompute the palette
      -- and push each highlight group through bufferline's own name generator
      -- so the strip follows the terminal without a full re-setup.
      vim.api.nvim_create_autocmd('ColorScheme', {
        group = vim.api.nvim_create_augroup('bufferline-palette', { clear = true }),
        callback = function()
          local c = require('catppuccin.palettes').get_palette 'mocha'
          local glass = glass_tint(c)
          local hl = require('bufferline.highlights')
          for name, attrs in pairs(highlights_from(c, glass)) do
            vim.api.nvim_set_hl(0, hl.generate_name(name), attrs)
          end
        end,
      })
    end,
  },
}
