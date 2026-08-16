-- Disable command line
vim.opt.cmdheight = 0

-- Make line numbers default
vim.opt.number = true

-- Relative numbers
vim.opt.relativenumber = true

-- Enable wrap
vim.wo.wrap = true
vim.wo.linebreak = true
vim.wo.breakindent = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Allow switching away from modified buffers (no E37 when cycling with ]b / <S-h>)
vim.opt.hidden = true

-- Reload files changed on disk (checked again on focus regain)
vim.opt.autoread = true

-- Wrapped lines get a continuation marker
vim.opt.showbreak = '↪ '

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- No cursorline: the current line stays clean, nothing gets a dark
-- background (relative numbers still show you where you are).
vim.opt.cursorline = false

-- Smooth scroll (wheel/paging): glides instead of jumping line-by-line
vim.opt.smoothscroll = true

-- Hide the `~` filler lines at the end of a buffer for a cleaner look
vim.opt.fillchars = { eob = ' ' }

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 10

-- Enable 24-bit colors
vim.opt.termguicolors = true

-- Set statusline to be global
vim.opt.laststatus = 3

-- Window border style
vim.o.winborder = 'rounded'

-- Frosted glass: floating windows (telescope, hover docs, snacks picker,
-- trouble) and the completion menu blend toward the wallpaper behind them
-- instead of painting opaque boxes. 0 = opaque, 100 = fully see-through.
-- The editor bg itself is transparent via catppuccin's
-- transparent_background; these two options frost everything on top of it.
vim.opt.winblend = 25
vim.opt.pumblend = 20

-- No "Press ENTER or type command to continue" pauses: long messages scroll
-- through instead of blocking the editor. Full history still in :messages.
vim.opt.more = false

-- Silence chatty messages that trigger the hit-enter prompt:
--   a  all abbreviations   A  no ATTENTION     c  no completion-menu msgs
--   F  no "[New File]"     I  no intro         s  no "search hit BOTTOM"
--   t  truncate file msgs at start
vim.opt.shortmess:append 'aAcFIst'

-- Re-check buffers when the terminal regains focus, so edits made in another
-- program (git, AI agents, formatters) appear without a manual :e!.
-- Pairs with `set -g focus-events on` in tmux.
vim.api.nvim_create_autocmd('FocusGained', {
  group = vim.api.nvim_create_augroup('autoreload-on-focus', { clear = true }),
  callback = function()
    pcall(vim.cmd, 'checktime')
  end,
})
