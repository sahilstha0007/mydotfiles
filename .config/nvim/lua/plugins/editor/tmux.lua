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
        resize = {
          enable_default_keybindings = false,
        },
      }

      -- When running inside Kitty without tmux, allow Ctrl+h/j/k/l to jump across Kitty splits
      if
        not vim.env.TMUX
        and (
          vim.env.KITTY_WINDOW_ID
          or vim.env.TERMINAL_STACK_PROFILE == 'kitty'
        )
      then
        local dir_map = { h = 'left', j = 'bottom', k = 'top', l = 'right' }
        for key, dir in pairs(dir_map) do
          vim.keymap.set({ 'n', 't' }, '<C-' .. key .. '>', function()
            local cur_win = vim.api.nvim_get_current_win()
            vim.cmd.wincmd(key)
            if vim.api.nvim_get_current_win() == cur_win then
              pcall(
                vim.fn.system,
                { 'kitty', '@', 'focus-window', '-m', 'neighbor:' .. dir }
              )
            end
          end, { desc = 'Navigate split (Kitty & Neovim)' })
        end
      end
    end,
  },
}
