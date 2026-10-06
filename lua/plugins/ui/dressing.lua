return {
  {
    -- dressing is a FALLBACK, not the owner, and it has to be told so
    -- explicitly. Its setup() calls patch.all(), which installs handlers for
    -- vim.ui.select / input / open LAST -- at `VeryLazy`, after snacks (priority
    -- 1000, lazy = false) has already claimed both. So it silently clobbered
    -- them, and checkhealth said so:
    --   ERROR `vim.ui.select` is not set to `Snacks.picker.select`
    --   ERROR `vim.ui.input`  is not set to `Snacks.input`
    -- This file's own comment used to claim the opposite of what was happening.
    --
    -- Priority does NOT fix it (tried: priority 900 changed nothing) -- priority
    -- orders plugin setup, but VeryLazy fires after snacks' own setup either
    -- way, and dressing re-patches on top. The unpatch below is the fix: snacks
    -- owns the interactive UI, dressing keeps its window border/padding styling,
    -- and nothing fights over vim.ui.
    --
    -- What dressing is still here for: the transparent/border styling that
    -- snacks' own windows don't provide.
    --
    -- The two health lines above now report as INFO, not ERROR: snacks' check is
    -- an identity test, and this file's patch owns vim.ui permanently -- so the
    -- test could never pass even though routing is correct. The redirect lives
    -- in plugins/editor/snacks.lua (opts, near the top) because this file loads
    -- on VeryLazy->UIEnter and so never runs under a headless `:checkhealth`.
    'stevearc/dressing.nvim',
    event = 'VeryLazy',
    opts = {
      -- The actual fix, and it is not about ordering. dressing/patch.lua wraps
      -- vim.ui.select and vim.ui.input at REQUIRE time, not setup time, and
      -- the wrapper is a dispatcher: it checks `dressing.config[key].enabled`
      -- on every call and forwards to the original only when that is false.
      -- Both default to true, so dressing answered every select/input that
      -- snacks had registered -- which is why checkhealth reported snacks as
      -- not owning vim.ui, and why reordering or a lower priority changed
      -- nothing: the wrapper stays installed either way.
      --
      -- So turn the two modules off. Snacks then owns vim.ui (picker + input,
      -- both already enabled in plugins/editor/snacks.lua), and dressing is
      -- left doing nothing but the border/padding styling it was imported for.
      -- Set either back to true and snacks stops receiving native LSP/plugin
      -- prompts, which is the bug these two errors were reporting.
      select = { enabled = false },
      input = { enabled = false },
    },
    -- The other half of the fix, and the part that actually matters.
    --
    -- `enabled = false` above stops dressing answering prompts, but it does
    -- NOT hand the prompt to snacks. patch.lua captured `original_mods` at
    -- require time from whatever vim.ui held THEN -- verified here as
    -- /usr/share/nvim/runtime/lua/vim/ui.lua, nvim's built-in dialog, not
    -- snacks. The wrapper forwards to that captured function, so with the
    -- modules merely disabled every vim.ui.select() lands on a plain
    -- `inputlist()` prompt.
    --
    -- So re-point the captured originals at snacks, after dressing has
    -- wrapped. That is what dressing's own unpatch-then-repatch path does, and
    -- it leaves the wrapper in place (dressing keeps its border styling) while
    -- making the call land on the snacks picker. Order is load-bearing and this
    -- is the order: snacks registers, dressing wraps and captures it, this
    -- re-points the capture back at snacks.
    --
    -- NOTE: checkhealth will still report
    --   ERROR `vim.ui.select` is not set to `Snacks.picker.select`
    -- and the same for input, and it cannot be made to pass while dressing is
    -- installed at all. Snacks' check is an identity test
    -- (`vim.ui.select == Snacks.picker.select`, picker/core/_health.lua:7) and
    -- dressing's wrapper owns `vim.ui.select` permanently, so the two can never
    -- be the same function. The prompt routing is verified correct instead in
    -- tests/ui_owner_spec.lua, which follows the call through the wrapper.
    -- Ignore those two lines, or drop dressing and the errors go away.
    config = function(_, opts)
      require('dressing').setup(opts)
      local patch = require 'dressing.patch'
      patch.original_mods.select = Snacks.picker.select
      patch.original_mods.input = Snacks.input
    end,
  },
}
