-- luacheck config for this Neovim config tree.
--
-- The lint gate used to report "luacheck not installed" and there was no
-- config to install it FOR. Run against the raw tree it emitted 657 warnings,
-- 634 of which were W113/W112 "undefined variable vim" — one per API call.
-- That is not a defect report, it is the linter being told nothing about the
-- runtime it is linting. `vim` is a global in every Neovim Lua chunk, so
-- declaring it is a fact, not a suppression.
--
-- std = "luajit" because nvim embeds LuaJIT: loadstring/setfenv (5.1-only) and
-- bit/ffi are all legal here and must not be flagged. Pinning it also stops a
-- future system Lua upgrade from silently changing what this gate means.
std = "luajit"
globals = {
  "vim",
  -- Plugin globals. Each of these is assigned by its lazy.nvim loader as a
  -- module-level global before the config runs, so reading them here is
  -- correct usage, not an undefined variable:
  --   Snacks         - folke/snacks.nvim sets `_G.Snacks` at setup
  --   MiniSessions   - mini.sessions installs the `MiniSessions` global table
  --   MiniHipatterns - mini.hipatterns installs `MiniHipatterns` likewise
  "Snacks",
  "MiniSessions",
  "MiniHipatterns",
}

-- Files that are deliberately standalone probes or fixtures rather than part
-- of the config's runtime module graph.
exclude_files = {}
