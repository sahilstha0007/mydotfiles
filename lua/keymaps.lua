local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- Clear highlights on search when pressing <Esc> in normal mode
keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Split windows: <leader>| / <leader>- (LazyVim convention — the key
-- MATCHES the split line you get). `s` is left free for flash.nvim's
-- jump (see plugins/editor/flash.lua), and <C-w>v / <C-w>s still work.
-- tmux mirrors these exactly: <prefix>| / <prefix>- (see tmux.conf).
keymap.set('n', '<leader>|', ':vsplit<Return>', vim.tbl_extend('keep', opts, { desc = 'Split vertical (side-by-side)' }))
keymap.set('n', '<leader>-', ':split<Return>', vim.tbl_extend('keep', opts, { desc = 'Split horizontal (stacked)' }))

-- Window management group: <leader>w (LazyVim convention). The wd/wm
-- pairs match LazyVim exactly; keys live under the group instead of
-- sprawling across random chords. <C-w> native ops (o, r, H, J...) all
-- still work — this only adds the two most-used actions.
keymap.set('n', '<leader>wd', '<C-w>c', vim.tbl_extend('keep', opts, { desc = 'Delete Window' }))
keymap.set('n', '<leader>wm', function()
  -- snacks.zen.zoom: maximize the current window without closing others
  -- (same engine as <leader>Z; require-at-press is the same lazy pattern
  -- pickers.lua uses for snacks.picker).
  require('snacks').zen.zoom()
end, { desc = 'Toggle Zoom Mode' })

-- Tabs: gt/gT are native next/prev; <Tab> is NOT remapped (remapping it
-- kills <C-i> — terminals send Tab and Ctrl-i as the same byte, and <C-i>
-- is jumplist-forward, the partner of <C-o>).
keymap.set('n', '<leader><tab>d', ':tabclose<Return>', opts)

-- Resize with Ctrl+Arrows (LazyVim convention): <C-Up/Down> height,
-- <C-Left/Right> width. 2 cols/rows per press — small enough to be
-- precise, big enough to not need a spam chord.
keymap.set('n', '<C-Up>', '<cmd>resize +2<CR>', { desc = 'Increase Window Height' })
keymap.set('n', '<C-Down>', '<cmd>resize -2<CR>', { desc = 'Decrease Window Height' })
keymap.set('n', '<C-Left>', '<cmd>vertical resize -2<CR>', { desc = 'Decrease Window Width' })
keymap.set('n', '<C-Right>', '<cmd>vertical resize +2<CR>', { desc = 'Increase Window Width' })

-- Terminal mode: double-Esc returns to Normal mode. A single <Esc> goes
-- to the program running inside the terminal (e.g. vim in a :terminal),
-- so use <Esc><Esc> to truly leave insert mode.
keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Diagnostics: unimpaired-style ]d/[d next/prev. vim.diagnostic.jump
-- wraps at the ends by default (wrap=true), so cycling never dead-ends —
-- the same UX as resilient_nav below, without the pcall dance.
keymap.set('n', ']d', function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = 'Next Diagnostic' })
keymap.set('n', '[d', function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = 'Prev Diagnostic' })

-- LSP Rename
vim.keymap.set('n', '<leader>cr', function()
  vim.lsp.buf.rename()
end, { desc = 'LSP Rename' })

-- Buffer functions
local function delete_other_buffers()
  local current_buf = vim.api.nvim_get_current_buf()
  local buffers = vim.api.nvim_list_bufs()

  for _, buf in ipairs(buffers) do
    if buf ~= current_buf and vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_delete(buf, {})
    end
  end
end

-- Quickfix / loclist navigation (unimpaired-style). After grug-far replace
-- or grep-picker picks land in the quickfix, ]q/[q walks them without the
-- picker open. Same for ]l/[l in the location list. Wrapping at the ends
-- (stock :cnext errors E553 "No more items" at boundaries; wrap instead,
-- LazyVim-style, so cycling never dead-ends).
local function resilient_nav(next_cmd, wrap_cmd)
  return function()
    if not pcall(vim.cmd, next_cmd) then
      vim.cmd(wrap_cmd)
    end
  end
end
keymap.set('n', ']q', resilient_nav('cnext', 'cfirst'), { desc = 'Quickfix Next' })
keymap.set('n', '[q', resilient_nav('cprev', 'clast'), { desc = 'Quickfix Prev' })
keymap.set('n', ']l', resilient_nav('lnext', 'lfirst'), { desc = 'Loclist Next' })
keymap.set('n', '[l', resilient_nav('lprev', 'llast'), { desc = 'Loclist Prev' })

-- Buffers
keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
keymap.set('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap.set('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'Delete Buffer' })
keymap.set(
  'n',
  '<leader>bo',
  delete_other_buffers,
  { desc = 'Delete Other Buffers' }
)
keymap.set(
  'n',
  '<leader>bD',
  '<cmd>bd<CR>',
  { desc = 'Delete Buffer and Window' }
)

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup(
    'kickstart-highlight-yank',
    { clear = true }
  ),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Better indenting
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- Skip over closing brackets, quotes, and commas with <C-l>
keymap.set('i', '<C-l>', function()
  local line, col = vim.fn.getline('.'), vim.fn.col('.')
  return vim.tbl_contains({ ')', ']', '}', "'", '"', ',', '`', ';' }, line:sub(col, col))
      and '<Right>'
    or '<C-l>'
end, { expr = true, desc = 'Skip past closing bracket/quote/comma' })

-- Redo: native is <C-r>, which is awkward mid-flow and collides with the
-- terminal (tmux prefix-free <C-r> works, but many people never learn it).
-- LazyVim convention: uppercase U redoes, pairing with lowercase u.
-- (Native U is "make whole line uppercase" — gUgU / VU still do that.)
keymap.set('n', 'U', '<C-r>', vim.tbl_extend('keep', opts, { desc = 'Redo' }))

-- ============ Ctrl+z must NEVER suspend nvim ============
-- Native <C-z> sends SIGTSTP and drops you into the shell with a stopped
-- process — the nvim session (and every tmux pane state) appears to have
-- "quit". The autosave/session setup makes a suspend look like a crash.
-- Nop it everywhere a user could fat-finger it; `:suspend` still exists
-- for the rare deliberate case, and inside :terminal buffers <C-z> keeps
-- its native meaning (suspending the CHILD program is correct there).
keymap.set({ 'n', 'v', 'i' }, '<C-z>', '<nop>', { desc = 'Suspend disabled (nvim stays open)' })

-- ============ q / <Esc> close popups, floats & special windows ============
-- In normal FILE buffers nothing changes: `q` still records macros and
-- <Esc> still clears search highlights (map at the top of this file).
-- In special windows the same keys become "close this": quickfix/loclist,
-- help, man, lspinfo, checkhealth, gitsigns blame, trouble, nvim-tree,
-- LSP hover / diagnostic floats (buftype nofile) — LazyVim behaviour.
-- Implemented as BUFFER-LOCAL maps installed by BufWinEnter, so global
-- `q` macro recording is never shadowed in real buffers. nvim_win_close
-- with force=false refuses to close the last window (E444) — the pcall
-- absorbs that, so a popup can never quit nvim itself.
local popup_close_group = vim.api.nvim_create_augroup('popup-close-keys', { clear = true })
local popup_buftypes = { quickfix = true, nofile = true, prompt = true, help = true }

local function close_current_window()
  pcall(vim.api.nvim_win_close, 0, false)
end

vim.api.nvim_create_autocmd('BufWinEnter', {
  group = popup_close_group,
  desc = 'q / <Esc> close popups and special windows (never real buffers)',
  callback = function(args)
    local bt = vim.bo[args.buf].buftype
    local ft = vim.bo[args.buf].filetype
    -- gitcommit / Oil use special buftypes but are REAL editing surfaces:
    -- a stray q there must never close anything.
    if ft == 'gitcommit' or ft == 'Oil' then
      return
    end
    if popup_buftypes[bt] then
      vim.keymap.set('n', 'q', close_current_window, { buffer = args.buf, desc = 'Close popup' })
      vim.keymap.set('n', '<Esc>', close_current_window, { buffer = args.buf, desc = 'Close popup' })
    end
  end,
})
