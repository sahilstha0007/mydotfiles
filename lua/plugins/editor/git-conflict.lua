-- git-conflict.nvim — inline merge-conflict resolution: highlights
-- conflicts, ]x/[x to jump between them, <leader>gco/gcO pick ours/theirs
-- (or both) with one key. Complements diffview's merge UI.
return {
  {
    'akinsho/git-conflict.nvim',
    event = 'BufReadPre',
    opts = {
      default_commands = true, -- co/ct/cb commands
      disable_diagnostics = true, -- diagnostics on conflict markers are noise
      highlights = {
        incoming = 'DiffAdd',
        current = 'DiffText',
      },
    },
    keys = {
      { ']x', '<cmd>GitConflictNextConflict<cr>', desc = 'Next conflict' },
      { '[x', '<cmd>GitConflictPrevConflict<cr>', desc = 'Prev conflict' },
      { '<leader>gco', '<cmd>GitConflictChooseOurs<cr>', desc = 'Conflict: choose ours' },
      { '<leader>gct', '<cmd>GitConflictChooseTheirs<cr>', desc = 'Conflict: choose theirs' },
      { '<leader>gcb', '<cmd>GitConflictChooseBoth<cr>', desc = 'Conflict: choose both' },
      { '<leader>gc0', '<cmd>GitConflictChooseNone<cr>', desc = 'Conflict: choose none' },
    },
  },
}
