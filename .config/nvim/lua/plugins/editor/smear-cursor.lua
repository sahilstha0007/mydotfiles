-- smear-cursor: kitty-style cursor glide. WezTerm can't animate cursor
-- movement yet (upstream feature request #7067, still open), so nvim does it.
--
-- Only animate jumps >= 5 cells (search results, gg/G, Ctrl+d/u).
-- 1-cell hjkl is high-frequency; animating every keystroke adds latency noise.
-- Per ui-craft motion rules: high-frequency interactions -> speed is the feature.
-- Stiffness stays at the plugin default 0.6: snappy (~2 frames to settle).
--
-- Cursor color is left unset: it picks up the terminal cursor color, which is
-- the wallpaper-synced gold via wezterm's colors/custom.lua.
return {
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    opts = {
      -- animate only jumps of 5+ cells to preserve instant typing/hjkl speed
      distance_stop_animating = 5,
    },
  },
}
