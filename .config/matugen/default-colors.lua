-- Default palette for sync-wallpaper.sh when matugen is missing or fails.
-- Every hex below is copied from the tracked .config/kitty/themes/apple-glass.conf
-- (Dark Apple Glass profile) so a clean clone still themes wezterm + tmux.
-- Schema matches templates/wezterm-colors.lua (the matugen output contract).
-- stylua: ignore
return {
   foreground = "#f5f5f7",
   background = "#1c1c1e",
   primary = "#2dd4bf",
   secondary = "#cba6f0",
   tertiary = "#f2d97a",
   success = "#7dce8b",
   error = "#ff6b6b",
   surface0 = "#2c2c2e",
   surface1 = "#3a3a3c",
   surface2 = "#6e6e73",
   outline = "#a1a1a6",
   source_color = "#2dd4bf",
}
