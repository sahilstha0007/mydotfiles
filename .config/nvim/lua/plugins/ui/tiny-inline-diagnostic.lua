-- Modern, clean inline diagnostics under the cursor
return {
  'rachartier/tiny-inline-diagnostic.nvim',
  event = 'LspAttach',
  priority = 1000,
  opts = {
    preset = 'modern',
    transparent_bg = true,
    options = {
      show_source = true,
      use_icons_from_diagnostic = true,
      multilines = true,
      softwrap = 30,
    },
  },
  config = function(_, opts)
    require('tiny-inline-diagnostic').setup(opts)
    -- Disable flat virtual_text so diagnostics don't duplicate
    vim.diagnostic.config { virtual_text = false }
  end,
}
