-- nvim-spider — subword-aware w/e/b/ge motions: stops at camelCase and
-- snake_case boundaries (B-tier gem, huge QoL for JS/TS code).
-- Opt-in via leader keys to keep vanilla motions for learning: <leader>w
-- etc. would fight flash.nvim's jump prefix, so use plain w/e/b remap?
-- No: top configs remap w/e/b directly — motions stay the same key,
-- just smarter. That's the whole point. Keep flash's `s` untouched.
return {
  {
    'chrisgrieser/nvim-spider',
    keys = {
      { 'w', desc = 'Spider-w (subword)' },
      { 'e', desc = 'Spider-e (subword)' },
      { 'b', desc = 'Spider-b (subword)' },
      { 'ge', desc = 'Spider-ge (subword)' },
    },
    config = function()
      vim.keymap.set({ 'n', 'o', 'x' }, 'w', "<cmd>lua require('spider').motion('w')<CR>", { desc = 'Spider-w (subword)' })
      vim.keymap.set({ 'n', 'o', 'x' }, 'e', "<cmd>lua require('spider').motion('e')<CR>", { desc = 'Spider-e (subword)' })
      vim.keymap.set({ 'n', 'o', 'x' }, 'b', "<cmd>lua require('spider').motion('b')<CR>", { desc = 'Spider-b (subword)' })
      vim.keymap.set({ 'n', 'o', 'x' }, 'ge', "<cmd>lua require('spider').motion('ge')<CR>", { desc = 'Spider-ge (subword)' })
    end,
  },
}
