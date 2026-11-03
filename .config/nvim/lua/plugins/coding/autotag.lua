-- nvim-ts-autotag — the other half of "auto close tags". Treesitter knows
-- the real element under the cursor, so:
--   * editing an opening tag name in insert renames its closing twin too
--     (<div>hello</div>, edit "div" → <span>hello</span>)
--   * typing `>` after `<p` inserts the `</p>` pair with the cursor inside
--     (<p>|</p>) — pairs with autopairs' `<` → `<>` rule.
-- enable_close_on_slash is left OFF (plugin default): it only behaves on the
-- exact `</|>` placeholder state and corrupts ordinary `</` typing otherwise.
-- Supported filetypes are built in (html + aliases: astro/vue/php/blade/
-- eruby/htmldjango/twig/liquid, xml, svelte, heex, tsx/jsx) — no whitelist
-- needed here.
return {
  'windwp/nvim-ts-autotag',
  -- lazy.nvim removed the `LazyFile` custom event; it is no longer in
  -- lazy/core/handler/event.lua's M.mappings (only `VeryLazy` survives), so
  -- requesting it fails at setup with
  --   Invalid 'event': 'LazyFile'
  -- It was sugar for these three real buffer events, so name them directly.
  event = { 'BufReadPost', 'BufNewFile', 'BufWritePre' },
  opts = {
    opts = {
      enable_rename = true,
      enable_close = true,
    },
  },
}
