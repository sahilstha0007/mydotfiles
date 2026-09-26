local M = {}

-- mode → palette-slot map, resolved per refresh so the statusline mode
-- color follows the terminal palette too
local MODE_SLOTS = {
  n = 'red', i = 'green', v = 'blue', [''] = 'blue', V = 'blue',
  c = 'magenta', no = 'red', s = 'orange', S = 'orange', ['\22'] = 'orange',
  ic = 'yellow', R = 'violet', Rv = 'violet', cv = 'red', ce = 'red',
  r = 'cyan', rm = 'cyan', ['r?'] = 'cyan', ['!'] = 'red', t = 'red',
}

-- Populated by refresh(): catppuccin.palettes.get_palette() reads the live
-- color_overrides, so after a terminal palette change this table carries the
-- new colors and the mode component (which looks it up per redraw) follows.
M.mode_colors = {}

local function get_palette()
  local palette = require('utils.theme').palette()

  return {
    bg = palette.base,
    fg = palette.text,
    yellow = palette.yellow,
    cyan = palette.teal,
    darkblue = palette.crust,
    green = palette.green,
    orange = palette.peach,
    violet = palette.lavender,
    magenta = palette.mauve,
    blue = palette.blue,
    red = palette.red,
    pink = palette.pink,
  }
end

-- Rebuild the mode→color map + re-apply highlight groups. Called on startup
-- and on every ColorScheme (fired when terminal-colors re-applies after a
-- terminal palette change).
function M.refresh()
  local c = get_palette()
  for mode, slot in pairs(MODE_SLOTS) do
    M.mode_colors[mode] = c[slot]
  end
  M.apply_highlights()
end

function M.apply_highlights()
  local c = get_palette()

  -- Transparent statusline: bg 'NONE' lets the terminal wallpaper show
  -- through the whole bar (pairs with catppuccin transparent_background).
  vim.api.nvim_set_hl(0, 'LualineNormalC', { fg = c.fg, bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'LualineInactiveC', { fg = c.fg, bg = 'NONE' })
  vim.api.nvim_set_hl(0, 'LualineFilename', { fg = c.fg, bg = 'NONE' })

  vim.api.nvim_set_hl(0, 'LualineDiagnosticsError', { bg = 'NONE', fg = c.red })
  vim.api.nvim_set_hl(0, 'LualineDiagnosticsWarn', { bg = 'NONE', fg = c.yellow })
  vim.api.nvim_set_hl(0, 'LualineDiagnosticsInfo', { bg = 'NONE', fg = c.cyan })
  vim.api.nvim_set_hl(0, 'LualineLsp', { bg = 'NONE', fg = c.pink })
  vim.api.nvim_set_hl(
    0,
    'LualineBranch',
    { bg = 'NONE', fg = c.violet, bold = true }
  )
  vim.api.nvim_set_hl(
    0,
    'LualineDiffAdded',
    { bg = 'NONE', fg = c.green, bold = true }
  )
  vim.api.nvim_set_hl(
    0,
    'LualineDiffModified',
    { bg = 'NONE', fg = c.orange, bold = true }
  )
  vim.api.nvim_set_hl(
    0,
    'LualineDiffRemoved',
    { bg = 'NONE', fg = c.red, bold = true }
  )

  -- add more as needed
end

return M
