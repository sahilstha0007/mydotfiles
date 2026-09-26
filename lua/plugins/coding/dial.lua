-- dial.nvim — smart <C-a>/<C-x>: dates, booleans, semver, true↔false,
-- arrow functions, and more (S/A-tier "hidden gem" in top configs).
-- Uses the stock augmented augends plus common web-dev toggles.
return {
  {
    'monaqa/dial.nvim',
    keys = {
      { '<C-a>', mode = { 'n', 'v' }, desc = 'Increment (dial)' },
      { '<C-x>', mode = { 'n', 'v' }, desc = 'Decrement (dial)' },
      { 'g<C-a>', mode = 'v', desc = 'Increment sequence' },
      { 'g<C-x>', mode = 'v', desc = 'Decrement sequence' },
    },
    config = function()
      local dial = require 'dial.map'
      local augend = require 'dial.augend'

      require('dial.config').augends:register_group('default', {
        augend.constant.new {
          elements = { 'true', 'false' },
          word = true,
          cyclic = true,
        },
        augend.constant.new {
          elements = { 'yes', 'no' },
          word = true,
          cyclic = true,
        },
        augend.constant.new {
          elements = { 'and', 'or' },
          word = true,
          cyclic = true,
        },
        augend.case.new {
          types = { 'camelCase', 'PascalCase', 'snake_case', 'SCREAMING_SNAKE_CASE' },
          cyclic = true,
        },
        augend.date.new {
          pattern = '%Y-%m-%d',
          default_kind = 'day',
        },
        augend.date.new {
          pattern = '%d/%m/%Y',
          default_kind = 'day',
        },
        augend.date.new {
          pattern = '%H:%M',
          default_kind = 'day',
        },
        augend.hexcolor.new {
          case = 'lower',
        },
        augend.semver.semver,
        augend.integer.new_decimal,
      })

      vim.keymap.set('n', '<C-a>', dial.inc_normal(), { desc = 'Increment (dial)' })
      vim.keymap.set('n', '<C-x>', dial.dec_normal(), { desc = 'Decrement (dial)' })
      vim.keymap.set('v', '<C-a>', dial.inc_visual(), { desc = 'Increment (dial)' })
      vim.keymap.set('v', '<C-x>', dial.dec_visual(), { desc = 'Decrement (dial)' })
      vim.keymap.set('v', 'g<C-a>', dial.inc_gvisual(), { desc = 'Increment sequence' })
      vim.keymap.set('v', 'g<C-x>', dial.dec_gvisual(), { desc = 'Decrement sequence' })
    end,
  },
}
