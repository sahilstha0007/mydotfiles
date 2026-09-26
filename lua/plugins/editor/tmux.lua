-- tmux integration. tmux.nvim covers both pane navigation (<C-h/j/k/l>) and
-- resizing (M-h/j/k/l) with default keybindings, so vim-tmux-navigator (which
-- duplicates the navigation maps) is not needed. The tmux side of this same
-- plugin (installed via TPM) forwards those keys to nvim when it's focused —
-- tune via @tmux-nvim-* options in tmux.conf if needed.
return {
  {
    'aserowy/tmux.nvim',
    config = function()
      return require('tmux').setup {
        resize = {
          enable_default_keybindings = true,
        },
      }
    end,
  },
}