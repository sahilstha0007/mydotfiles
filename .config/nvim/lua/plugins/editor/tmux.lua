-- tmux integration. tmux.nvim covers both pane navigation (<C-h/j/k/l>) and
-- resizing (M-h/j/k/l) with default keybindings, so vim-tmux-navigator (which
-- duplicates the navigation maps) is not needed. The tmux side of this same
-- plugin (installed via TPM) forwards those keys to nvim when it's focused —
-- tune via @tmux-nvim-* options in tmux.conf if needed.
return {
  {
    'aserowy/tmux.nvim',
    config = function()
      local tmux = require 'tmux'
      tmux.setup {
        copy_sync = {
          enable = true,
          sync_clipboard = false, -- Neovim's native unnamedplus + OSC52 handles system clipboard
          sync_registers = true,
          sync_deletes = false, -- avoid overwriting tmux paste buffers on simple deletes (dd/dw)
          sync_unnamed = true,
        },
        navigation = {
          cycle_navigation = true,
          persist_zoom = true,
        },
        resize = {
          enable_default_keybindings = false,
        },
      }
    end,
  },
}
