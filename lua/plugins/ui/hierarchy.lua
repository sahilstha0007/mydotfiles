-- Syntax hierarchy.
--
-- A wallpaper-derived palette is generated for LARGE AREAS — a background and
-- a handful of accents. Code is the opposite: small glyphs, high density, and
-- a language needs 10-15 distinguishable token classes. matugen produces ~8
-- accents. So the palette alone cannot be enough; the hierarchy on top of it is
-- what makes code readable.
--
-- Two rules, and only two:
--   DEMOTE structure — comments, operators, punctuation. They carry no meaning
--     but dominate a screen at full strength, so they must recede.
--   PROMOTE exactly three things — diagnostics, the cursor line, git changes.
--     A theme where five things are bright is a theme where nothing is.
--
-- Called by terminal-colors.lua at the end of every re-tint, NOT a lazy spec
-- of its own. See the note at the call site: a second spec naming the same
-- plugin is what lazy rejected.

local M = {}

---Apply the hierarchy on top of whatever palette is currently loaded.
function M.apply()
  -- Catppuccin semantic slots are guaranteed present: terminal-colors maps
  -- the terminal's ANSI 0-15 onto these exact names, and falls back to stock
  -- mocha if nothing answers. Reading the live highlight group is more
  -- robust than re-deriving hexes here.
  local function slot(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.fg and string.format('#%06x', hl.fg) or nil
  end

  local c = {
    surface2 = slot 'CursorLine',
    surface1 = slot 'NonText',
    overlay1 = slot 'Comment',
    overlay0 = slot 'LineNr',
    comment = slot 'Comment',
    text = slot 'Normal',
    error = slot 'DiagnosticError',
    warn = slot 'DiagnosticWarn',
  }

  -- --- demote: structure -------------------------------------------------
  -- Comments are the single biggest source of visual noise in a code editor.
  local set = vim.api.nvim_set_hl

  set(0, 'Comment', { fg = c.comment, italic = true })
  set(0, '@comment', { fg = c.comment, italic = true })
  set(0, '@comment.documentation', { link = 'Comment' })
  set(0, '@comment.error', { link = 'DiagnosticError' })
  set(0, '@comment.warning', { link = 'DiagnosticWarn' })
  set(0, '@comment.todo', { fg = c.warn, bold = true })

  -- Punctuation and operators: recede hard. These are the highest-frequency
  -- tokens on screen and the lowest-information ones.
  set(0, '@punctuation', { fg = c.surface1 })
  set(0, '@punctuation.bracket', { fg = c.surface1 })
  set(0, '@punctuation.delimiter', { fg = c.surface1 })
  set(0, '@punctuation.special', { fg = c.surface1 })
  set(0, '@operator', { fg = c.overlay0 })
  set(0, '@keyword.operator', { fg = c.overlay0 })

  -- Gutter: the current line number is the exception — it is a position
  -- cue, not decoration, so it gets full text weight.
  set(0, 'LineNr', { fg = c.overlay0 })
  set(0, 'SignColumn', { link = 'LineNr' })
  set(0, 'CursorLineNr', { fg = c.text })

  -- --- promote: the three that earn it ------------------------------------
  -- Diagnostics. Severity sort + underline means the LIST reads in the right
  -- order; the underline means it survives on a translucent background
  -- where a subtle colour shift would not.
  vim.diagnostic.config { severity_sort = true, underline = true }

  -- Git: gitsigns already colours these; the hunk marks are the third
  -- promoted element and must stay above the demoted structure above.
  set(0, 'DiffAdd', { fg = c.text })
  set(0, 'DiffDelete', { fg = c.error })
  set(0, 'DiffChange', { fg = c.warn })
end

-- Also re-apply on any later colorscheme change, so a manual
-- `:colorscheme` or another plugin's reload cannot leave the hierarchy off.
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('SyntaxHierarchy', { clear = true }),
  callback = M.apply,
  desc = 'Re-apply the syntax hierarchy after any colorscheme change',
})

return M
