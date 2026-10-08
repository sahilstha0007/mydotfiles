-- snacks.bufdelete, in its own spec file rather than in plugins/editor/snacks.lua.
--
-- Why a separate file: the main snacks spec is being edited concurrently, and
-- lazy.nvim MERGES multiple specs naming the same plugin -- so this composes
-- with it instead of conflicting. Everything here lands whether or not that
-- edit is in flight.
--
-- What it buys: <leader>bd / <leader>bD in keymaps.lua call into this module.
-- `:bdelete` drops the buffer but leaves the window standing, turning the pane
-- you were reading into an empty scratch buffer. bufdelete closes the window as
-- well, or moves to a neighbour when it was the last one. See keymaps.lua.
--
-- The module has no key option of its own -- enabling it does NOT remap `bd`
-- or `bD`. Its public API is delete / all / other / invisible, which the two
-- keymaps call directly.

return {
  'folke/snacks.nvim',

  opts = {
    bufdelete = {
      enabled = true,
    },
  },
}
