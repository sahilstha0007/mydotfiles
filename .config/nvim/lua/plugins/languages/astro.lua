return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = { ensure_installed = { 'astro', 'css' } },
  },

  {
    'conform.nvim',
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.astro = { 'prettier', 'prettierd' }
      -- Astro is prettier-only (not in biome_supported in conform.lua's
      -- format_after_save), so keep both prettier + prettierd.
      -- JS/TS/JSON/CSS use biome only now (see conform.lua): biome is faster
      -- and covers them; prettier stays as fallback for non-biome filetypes.
    end,
  },
}
