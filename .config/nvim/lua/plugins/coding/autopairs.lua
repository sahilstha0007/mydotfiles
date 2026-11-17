-- autopairs
-- https://github.com/windwp/nvim-autopairs

return {
  'windwp/nvim-autopairs',
  event = 'InsertEnter',
  -- Bracket/quote pairing while typing. Completion-driven bracket insertion
  -- (adding `()` after accepting a function) is handled by blink.cmp itself.
  config = function()
    local autopairs = require 'nvim-autopairs'
    autopairs.setup {}

    -- nvim-autopairs ships no `<`/`>` pair (it would clash with comparison
    -- operators in code), but markup files are exactly where you want it.
    -- add_rules appends to the defaults, so nothing else changes.
    local Rule = require 'nvim-autopairs.rule'
    autopairs.add_rules {
      Rule('<', '>', {
        'html',
        'xml',
        'xhtml',
        'htmldjango',
        'eruby',
        'php',
        'blade',
        'vue',
        'svelte',
        'astro',
        'heex',
        'eelixir',
        'ejson',
        'jinja',
        'jinja.html',
        'handlebars',
        'mustache',
      }),
    }
  end,
}
