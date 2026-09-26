-- smear-cursor: kitty-style cursor glide. WezTerm can't animate cursor
-- movement yet (upstream feature request #7067, still open), so nvim does it.
--
-- Everything glides — including 1-cell hjkl in normal mode — because the
-- distance threshold is 1 (the plugin default of 0.1 also animates sub-cell
-- jitter, which is unnecessary). Stiffness stays at the plugin default 0.6:
-- snappy (~2 frames to settle), so the glide reads as smooth, never laggy.
--
-- Cursor color is left unset: it picks up the terminal cursor color, which is
-- the wallpaper-synced gold via wezterm's colors/custom.lua.
return {
  {
    'sphamba/smear-cursor.nvim',
    event = 'VeryLazy',
    opts = {
      -- animate every move >= 1 cell (normal-mode hjkl included, kitty-style)
      distance_stop_animating = 1,
    },
  },
}