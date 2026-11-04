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
  -- Retrieve the active Catppuccin palette if available. When terminal-colors
  -- runs, color_overrides ensures cp.overlay0/cp.overlay1/cp.text satisfy WCAG AA
  -- (>= 4.5:1 contrast against the wallpaper background).
  local cp
  local ok_t, theme = pcall(require, 'utils.theme')
  if ok_t and theme and theme.palette then
    pcall(function()
      cp = theme.palette()
    end)
  end
  if not cp then
    local ok_c, palettes = pcall(require, 'catppuccin.palettes')
    if ok_c and palettes then
      pcall(function()
        cp = palettes.get_palette()
      end)
    end
  end

  -- Fallback highlight slot reader for standalone / minimal test runners
  local function slot(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl.fg and string.format('#%06x', hl.fg) or nil
  end

  local c = {
    surface2 = slot 'CursorLine',
    surface1 = (cp and cp.surface1) or slot 'NonText',
    overlay1 = (cp and cp.overlay1) or slot 'Comment',
    overlay0 = (cp and cp.overlay0) or slot 'NonText',
    comment = (cp and cp.overlay1) or slot 'Comment',
    punctuation = (cp and cp.overlay0) or slot 'NonText',
    operator = (cp and cp.overlay1) or slot 'Comment',
    linenr = (cp and cp.overlay0) or slot 'NonText',
    text = (cp and cp.text) or slot 'Normal',
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

  -- Punctuation and operators: recede hard while clearing MIN_CONTRAST (>= 4.5:1)
  -- so brackets and symbols remain crisp and legible.
  set(0, '@punctuation', { fg = c.punctuation })
  set(0, '@punctuation.bracket', { fg = c.punctuation })
  set(0, '@punctuation.delimiter', { fg = c.punctuation })
  set(0, '@punctuation.special', { fg = c.punctuation })
  set(0, '@operator', { fg = c.operator })
  set(0, '@keyword.operator', { fg = c.operator })

  -- Gutter: the current line number is the exception — it is a position
  -- cue, not decoration, so it gets full text weight.
  set(0, 'LineNr', { fg = c.linenr })
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
