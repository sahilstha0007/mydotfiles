-- Undo history browser. options.lua already sets undofile=true (persistent
-- per-file history) — this is the UI that makes that history actually
-- usable: timeline, diff vs any point, branch/redo points.
--
-- Plus the one key that matters for agent work.
--
-- MEASURED (headless nvim, re-runnable via tests/undo_isolation_spec.lua):
-- when the agent rewrites a file you have open, autoread reloads it silently
-- if the buffer is clean, and the agent's change becomes just another undo
-- block. Measured cost of walking back out of it: with the agent having
-- written 3 times, it took 3 `u` presses to reach your last save — and one
-- press more than that ate your own earlier work. So "revert what the agent
-- did" and "revert my own mistake" are the same keypress, and you have to
-- count. That is the thing that makes people avoid running an agent.
--
-- `:earlier 1f` is the built-in fix, already tested by Vim: :h :earlier says
-- "go back N file writes", so 1f lands on the state the file had when you
-- last wrote it, regardless of how many changes the agent piled in above it.
-- Verified: 3 agent writes -> `earlier 1f` -> exact pre-agent text, one
-- keystroke; `later 1f` returns to the agent's version; a following `u` still
-- reaches your own prior state rather than dead-ending.
--
-- So this is NOT an 'u_sync' wrapper. I tried to build one, measured it, and
-- found 'u_sync' is not an option Vim has — the whole module was scaffolding
-- around a flag that did not exist. Vim's own write-history does the job.
return {
  'mbbill/undotree',
  cmd = 'UndotreeToggle',
  keys = {
    { '<leader>uu', '<cmd>UndotreeToggle<CR>', desc = 'Undo Tree' },
    {
      '<leader>uf',
      '<cmd>earlier 1f<cr>',
      desc = 'Undo agent changes (back to your last write)',
    },
    {
      '<leader>uF',
      '<cmd>later 1f<cr>',
      desc = 'Redo to next write (undo the undo)',
    },
  },
  init = function()
    -- Keep the cursor in the undo tree window after toggling open.
    vim.g.undotree_SetFocusWhenToggle = 1
  end,
}
