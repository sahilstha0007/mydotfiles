-- The ACTIVE tab's raised "pill": clearly lighter than the terminal
-- background so it reads as a raised chip. It borrows the same blue accent
-- wezterm's tab bar / tmux's window pill use (raised 0.08 -> 0.28 so the
-- shared accent is actually visible) while keeping light text readable.
local function pill_tint(c)
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
  return mix(c.surface2, c.blue, 0.28)
end

-- The full highlight table (shared between opts and the ColorScheme re-tint).
-- c is the live catppuccin palette. The strip is fully transparent (bg
-- NONE) so the terminal's wallpaper shows straight through — only the
-- ACTIVE tab's pill carries a background, as the one raised element.
local function highlights_from(c)
  local pill = pill_tint(c)
  return {
    -- transparent strip: the terminal wallpaper shows through; only the
    -- active tab's pill raises on top
    fill = { fg = c.subtext0, bg = 'NONE' },
    background = { bg = 'NONE', fg = c.overlay0 },
    -- thin dividers: subtle tone-on-tone bars (underline off — the
    -- underline indicator would otherwise paint a light line here)
    separator = { fg = c.surface2, bg = 'NONE', underline = false },
    separator_selected = { fg = c.surface2, bg = 'NONE', underline = false },
    separator_visible = { fg = c.surface2, bg = 'NONE', underline = false },
    tab_separator = { fg = c.surface2, bg = 'NONE', underline = false },
    tab_separator_selected = { fg = c.surface2, bg = 'NONE', underline = false },
    -- ACTIVE tab: the raised pill — lighter bg, bold text. No underline,
    -- no boxy indicator; tab_size padding (options) extends the pill bg
    -- around the name so it reads as a chip floating on the wallpaper.
    buffer_selected = {
      bg = pill,
      fg = c.text,
      bold = true,
    },
    indicator_selected = {
      bg = pill,
      fg = c.text,
    },
    -- INACTIVE tabs: quiet text straight on the wallpaper
    buffer = { bg = 'NONE', fg = c.overlay1 },
    buffer_visible = { bg = 'NONE', fg = c.overlay0 },
    -- unsaved-changes dot: soft amber, visible on wallpaper and pill
    modified = { fg = c.yellow, bg = 'NONE' },
    modified_selected = { fg = c.yellow, bg = pill },
    modified_visible = { fg = c.yellow, bg = 'NONE' },
    -- Explorer offset area: transparent, subtle separator
    offset_separator = { bg = 'NONE', fg = c.surface1 },
    -- Tab diagnostics (error/warn/info icons): bufferline derives these
    -- from the Normal bg, which is transparent here — so pin the fg to
    -- the palette or they'd render in the terminal's default colors.
    -- Selected variants sit on the raised active tab (the pill).
    error = { fg = c.red, bg = 'NONE' },
    error_selected = { fg = c.red, bg = pill },
    error_visible = { fg = c.red, bg = 'NONE' },
    error_diagnostic = { fg = c.red, bg = 'NONE' },
    error_diagnostic_selected = { fg = c.red, bg = pill },
    error_diagnostic_visible = { fg = c.red, bg = 'NONE' },
    warning = { fg = c.yellow, bg = 'NONE' },
    warning_selected = { fg = c.yellow, bg = pill },
    warning_visible = { fg = c.yellow, bg = 'NONE' },
    warning_diagnostic = { fg = c.yellow, bg = 'NONE' },
    warning_diagnostic_selected = { fg = c.yellow, bg = pill },
    warning_diagnostic_visible = { fg = c.yellow, bg = 'NONE' },
    info = { fg = c.cyan, bg = 'NONE' },
    info_selected = { fg = c.cyan, bg = pill },
    info_visible = { fg = c.cyan, bg = 'NONE' },
    info_diagnostic = { fg = c.cyan, bg = 'NONE' },
    info_diagnostic_selected = { fg = c.cyan, bg = pill },
    info_diagnostic_visible = { fg = c.cyan, bg = 'NONE' },
    hint = { fg = c.subtext0, bg = 'NONE' },
    hint_selected = { fg = c.subtext0, bg = pill },
    hint_visible = { fg = c.subtext0, bg = 'NONE' },
    hint_diagnostic = { fg = c.subtext0, bg = 'NONE' },
    hint_diagnostic_selected = { fg = c.subtext0, bg = pill },
    hint_diagnostic_visible = { fg = c.subtext0, bg = 'NONE' },
  }
end

-- <leader>bs toggle state: the buffer ids in MRU (pre-directory-sort)
-- order, saved before switching to directory grouping so it can be put back.
local mru_snapshot = nil

return {
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = {
      { '<leader>bp', '<cmd>BufferLinePick<CR>', desc = 'Pick Buffer (tabs)' },
      {
        '<leader>bs',
        function()
          -- Toggle: MRU (insert_after_current, the default) <-> directory.
          -- Gotchas learned from the source (verified headless):
          --  - sort_by('directory') records a one-shot order in
          --    state.custom_sort; config.options.sort_by is NOT changed.
          --  - insert_after_current "respects the current order", so simply
          --    clearing custom_sort does NOT restore MRU — the directory
          --    order would persist. Instead: snapshot ids before sorting,
          --    and restore the snapshot via state.custom_sort on toggle-back.
          --  - persist_buffer_sort=true (plugin default) keeps any custom
          --    order across refreshes, which is exactly what we want here.
          local state = require 'bufferline.state'
          if not mru_snapshot then
            local ids = {}
            for _, c in ipairs(state.components or {}) do
              table.insert(ids, c.id)
            end
            if #ids == 0 then
              return vim.notify('bufferline: no buffers to sort', vim.log.levels.WARN)
            end
            mru_snapshot = ids
            require('bufferline').sort_by 'directory'
            vim.notify('bufferline: directory order', vim.log.levels.INFO)
          else
            -- custom_sort drives get_updated_buffers on every refresh,
            -- so restoring the snapshot puts the strip back to MRU order
            require('bufferline.state').custom_sort = mru_snapshot
            require('bufferline.ui').refresh()
            mru_snapshot = nil
            vim.notify('bufferline: MRU order', vim.log.levels.INFO)
          end
        end,
        desc = 'Toggle Buffer Sort (MRU / directory)',
      },
    },
    opts = function()
      local c = require('utils.theme').palette()

      return {
        options = {
          mode = 'buffers',
          -- tab strip always visible so the file title stays on top
          always_show_bufferline = true,
          show_close_icon = false,
          -- clean: no x buttons on every tab (BufferLinePick / ]b cover
          -- closing; right-mouse still deletes)
          show_buffer_close_icons = false,
          -- clean thin dividers — no slanted boxes/triangles between tabs
          separator_style = 'thin',
          -- NO indicator: no underline, no bar, no blob under/on the active
          -- tab — the raised pill alone marks the current file (the
          -- "underline" style drew a boxy bottom line, ponytail: gone)
          indicator = { style = 'icon', icon = '' },
          -- soft dot on tabs with unsaved changes
          modified_icon = '●',
          -- VS Code-style ordering: a newly-opened buffer appears right
          -- after the current one, so the strip reads as "recently used"
          -- instead of a fixed buffer-number order
          sort_by = 'insert_after_current',
          -- a little breathing room around each name so the active tab's
          -- bg reads as a padded pill rather than a tight label
          tab_size = 20,
          offsets = {
            {
              filetype = 'NvimTree',
              text = vim.fn.nr2char(0xF024B) .. ' Explorer', -- md-folder (verified in Nerd Fonts 3.5)
              highlight = 'Directory',
              separator = true,
            },
          },
        },
        -- Design system (translated from the design skills): the tab strip
        -- is fully transparent — the terminal's wallpaper shows straight
        -- through. The active tab is the ONE raised element: a lighter pill
        -- (pill_tint) with bold text, padded by tab_size so it reads as a
        -- chip floating on the wallpaper. Inactive tabs are quiet text
        -- without any background. Tone-on-tone dividers, no boxes/borders.
        --
        -- NOTE: the theme sets `Normal` bg to transparent, so bufferline
        -- derives nil colors for several groups (they'd render in the
        -- terminal's default white) — every fg below is pinned to a
        -- palette tone on purpose.
        highlights = highlights_from(c),
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
          local c = require('utils.theme').palette()
          local hl = require('bufferline.highlights')
          for name, attrs in pairs(highlights_from(c)) do
            vim.api.nvim_set_hl(0, hl.generate_name(name), attrs)
          end
        end,
      })
    end,
  },
}
