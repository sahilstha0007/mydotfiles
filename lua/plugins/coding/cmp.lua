-- Completion via blink.cmp — a single fast (Rust core) plugin that replaces
-- nvim-cmp + its source plugins + LuaSnip. `version = '*'` pulls a prebuilt
-- binary, so no local Rust toolchain is required.
return {
  {
    'saghen/blink.cmp',
    event = 'InsertEnter',
    version = '*',
    dependencies = {
      'folke/lazydev.nvim',
      'rafamadriz/friendly-snippets', -- loaded by blink's native vim.snippet engine
    },
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      -- Default preset: <C-y> accept, <C-n>/<C-p> select, <C-space> open/docs,
      -- <C-e> hide, <C-b>/<C-f> scroll docs, <Tab>/<S-Tab> snippet jump.
      keymap = {
        preset = 'default',
        -- Space closes the completion menu instead of re-filtering with it
        -- open — the re-filter caused flicker / cursor jumps / "no matches"
        -- flashing while typing code. This hides the menu AND inserts the
        -- space. Two gotchas, learned the hard way:
        --   * must return the literal ' ' character — expr-mapping results are
        --     NOT termcode-expanded, so '<Space>' would type "<Space>" text
        --   * a plain { 'hide', 'fallback' } would EAT the space whenever the
        --     menu is open, because hide() returns true when it hid something
        ['<space>'] = {
          function()
            require('blink.cmp').hide()
            return ' '
          end,
        },
      },
      appearance = { nerd_font_variant = 'mono' },
      completion = {
        -- Frosted menu + docs: blink draws its own windows, so the global
        -- 'pumblend' option doesn't apply — each window needs its own
        -- winblend to match the floats (options.lua sets 25 globally).
        menu = { winblend = 25 },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = { winblend = 25 },
        },
      },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'lazydev' },
        providers = {
          -- lazydev completions for editing this Neovim config; high score so
          -- they outrank (and dedupe) lua_ls's own suggestions.
          lazydev = {
            name = 'LazyDev',
            module = 'lazydev.integrations.blink',
            score_offset = 100,
          },
        },
      },
      -- Use blink's built-in snippet engine (no LuaSnip).
      snippets = { preset = 'default' },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
