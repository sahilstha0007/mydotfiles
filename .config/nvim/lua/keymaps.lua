local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- Clear highlights on search when pressing <Esc> in normal mode
keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Split windows: <leader>| / <leader>- (LazyVim convention — the key
-- MATCHES the split line you get). `s` is left free for flash.nvim's
-- jump (see plugins/editor/flash.lua), and <C-w>v / <C-w>s still work.
-- tmux mirrors these exactly: <prefix>| / <prefix>- (see tmux.conf).
keymap.set(
  'n',
  '<leader>|',
  ':vsplit<Return>',
  vim.tbl_extend('keep', opts, { desc = 'Split vertical (side-by-side)' })
)
keymap.set(
  'n',
  '<leader>-',
  ':split<Return>',
  vim.tbl_extend('keep', opts, { desc = 'Split horizontal (stacked)' })
)

-- Window management group: <leader>w (LazyVim convention). The wd/wm
-- pairs match LazyVim exactly; keys live under the group instead of
-- sprawling across random chords. <C-w> native ops (o, r, H, J...) all
-- still work — this only adds the two most-used actions.
keymap.set(
  'n',
  '<leader>wd',
  '<C-w>c',
  vim.tbl_extend('keep', opts, { desc = 'Delete Window' })
)
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
keymap.set(
  'n',
  '<C-Up>',
  '<cmd>resize +2<CR>',
  { desc = 'Increase Window Height' }
)
keymap.set(
  'n',
  '<C-Down>',
  '<cmd>resize -2<CR>',
  { desc = 'Decrease Window Height' }
)
keymap.set(
  'n',
  '<C-Left>',
  '<cmd>vertical resize -2<CR>',
  { desc = 'Decrease Window Width' }
)
keymap.set(
  'n',
  '<C-Right>',
  '<cmd>vertical resize +2<CR>',
  { desc = 'Increase Window Width' }
)

-- Terminal mode: double-Esc returns to Normal mode. A single <Esc> goes
-- to the program running inside the terminal (e.g. vim in a :terminal),
-- so use <Esc><Esc> to truly leave insert mode.
keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Diagnostics: unimpaired-style ]d/[d next/prev. vim.diagnostic.jump
-- wraps at the ends by default (wrap=true), so cycling never dead-ends —
-- the same UX as resilient_nav below, without the pcall dance.
keymap.set('n', ']d', function()
  vim.diagnostic.jump { count = 1, float = true }
end, { desc = 'Next Diagnostic' })
keymap.set('n', '[d', function()
  vim.diagnostic.jump { count = -1, float = true }
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
keymap.set(
  'n',
  ']q',
  resilient_nav('cnext', 'cfirst'),
  { desc = 'Quickfix Next' }
)
keymap.set(
  'n',
  '[q',
  resilient_nav('cprev', 'clast'),
  { desc = 'Quickfix Prev' }
)
keymap.set(
  'n',
  ']l',
  resilient_nav('lnext', 'lfirst'),
  { desc = 'Loclist Next' }
)
keymap.set(
  'n',
  '[l',
  resilient_nav('lprev', 'llast'),
  { desc = 'Loclist Prev' }
)

-- Quickfix list editing: dd in normal mode or d in visual mode deletes items
-- from the quickfix list, turning it into a real triage queue.
local function delete_qf_item()
  local qf = vim.fn.getqflist()
  local line = vim.fn.line '.'
  if #qf > 0 and line <= #qf then
    table.remove(qf, line)
    vim.fn.setqflist(qf, 'r')
    if line <= #qf then
      vim.fn.cursor(line, 1)
    else
      vim.fn.cursor(#qf, 1)
    end
  end
end

local function delete_qf_range()
  local qf = vim.fn.getqflist()
  local s = vim.fn.line "'<"
  local e = vim.fn.line "'>"
  if #qf > 0 and s <= #qf then
    for _ = s, math.min(e, #qf) do
      table.remove(qf, s)
    end
    vim.fn.setqflist(qf, 'r')
    vim.fn.cursor(math.min(s, #qf), 1)
  end
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  desc = 'dd and visual d delete items from quickfix list',
  callback = function(args)
    keymap.set(
      'n',
      'dd',
      delete_qf_item,
      { buffer = args.buf, desc = 'Delete item from quickfix' }
    )
    keymap.set(
      'x',
      'd',
      delete_qf_range,
      { buffer = args.buf, desc = 'Delete range from quickfix' }
    )
  end,
})

-- Buffers
keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap.set('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
keymap.set('n', '[b', '<cmd>bprevious<cr>', { desc = 'Prev Buffer' })
keymap.set('n', ']b', '<cmd>bnext<cr>', { desc = 'Next Buffer' })
-- snacks.bufdelete, whose own meta description is "delete buffers without
-- disrupting window layout". Measured against plain :bdelete on a 2-window
-- split: :bdelete takes the window with it, 2 windows -> 1; this keeps both
-- and swaps a neighbouring buffer into the vacated pane, so deleting a buffer
-- no longer collapses a split you wanted to keep. Module enabled in
-- plugins/editor/snacks-bufdelete.lua.
keymap.set('n', '<leader>bd', function()
  Snacks.bufdelete.delete()
end, vim.tbl_extend('keep', opts, { desc = 'Delete Buffer' }))
keymap.set(
  'n',
  '<leader>bo',
  delete_other_buffers,
  { desc = 'Delete Other Buffers' }
)
-- bD was `<cmd>bd<CR>`, and :bd is an abbreviation of :bdelete -- so this key
-- was an exact duplicate of <leader>bd above, while its description promised
-- "and Window" that it never closed. The cap now means the opposite of bd:
-- the buffer is WIPED rather than merely deleted, so it leaves :ls and cannot
-- come back via :bnext. Neither variant closes a window -- snacks preserves
-- the layout, which is the point. (delete() defaults to `buf = 0`.)
keymap.set('n', '<leader>bD', function()
  Snacks.bufdelete.delete { wipe = true }
end, vim.tbl_extend('keep', opts, { desc = 'Wipe Buffer (stronger delete)' }))

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
  local line, col = vim.fn.getline '.', vim.fn.col '.'
  return vim.tbl_contains(
    { ')', ']', '}', "'", '"', ',', '`', ';' },
    line:sub(col, col)
  ) and '<Right>' or '<C-l>'
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
keymap.set(
  { 'n', 'v', 'i' },
  '<C-z>',
  '<nop>',
  { desc = 'Suspend disabled (nvim stays open)' }
)

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
local popup_close_group =
  vim.api.nvim_create_augroup('popup-close-keys', { clear = true })
local popup_buftypes =
  { quickfix = true, nofile = true, prompt = true, help = true }

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
      vim.wo.wrap = true
      vim.wo.linebreak = true
      vim.keymap.set(
        'n',
        'q',
        close_current_window,
        { buffer = args.buf, desc = 'Close popup' }
      )
      vim.keymap.set(
        'n',
        '<Esc>',
        close_current_window,
        { buffer = args.buf, desc = 'Close popup' }
      )
    end
  end,
})

-- ============================================================
-- Line movement with Alt+j / Alt+k (normal, insert, visual)
-- ============================================================
vim.keymap.set('n', '<A-j>', '<cmd>m .+1<cr>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', '<cmd>m .-2<cr>==', { desc = 'Move line up' })
vim.keymap.set(
  'i',
  '<A-j>',
  '<esc><cmd>m .+1<cr>==gi',
  { desc = 'Move line down' }
)
vim.keymap.set(
  'i',
  '<A-k>',
  '<esc><cmd>m .-2<cr>==gi',
  { desc = 'Move line up' }
)
vim.keymap.set(
  'v',
  '<A-j>',
  ":m '>+1<cr>gv=gv",
  { desc = 'Move selection down' }
)
vim.keymap.set('v', '<A-k>', ":m '<-2<cr>gv=gv", { desc = 'Move selection up' })

-- Navigate visual lines when text is wrapped, unless preceded by a count
keymap.set(
  { 'n', 'x' },
  'j',
  "v:count == 0 ? 'gj' : 'j'",
  { expr = true, silent = true, desc = 'Down (visual line when wrapping)' }
)
keymap.set(
  { 'n', 'x' },
  'k',
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true, desc = 'Up (visual line when wrapping)' }
)
keymap.set({ 'n', 'x' }, '<Down>', "v:count == 0 ? 'gj' : 'j'", {
  expr = true,
  silent = true,
  desc = 'Down arrow (visual line when wrapping)',
})
keymap.set(
  { 'n', 'x' },
  '<Up>',
  "v:count == 0 ? 'gk' : 'k'",
  { expr = true, silent = true, desc = 'Up arrow (visual line when wrapping)' }
)
keymap.set('i', '<Down>', function()
  return vim.fn.pumvisible() == 1 and '<Down>' or '<C-o>gj'
end, {
  expr = true,
  silent = true,
  desc = 'Down arrow (visual line when wrapping)',
})
keymap.set(
  'i',
  '<Up>',
  function()
    return vim.fn.pumvisible() == 1 and '<Up>' or '<C-o>gk'
  end,
  { expr = true, silent = true, desc = 'Up arrow (visual line when wrapping)' }
)

-- ============================================================
-- UI Toggles (<leader>u*)
-- ============================================================
vim.keymap.set('n', '<leader>uw', function()
  vim.wo.wrap = not vim.wo.wrap
  vim.notify('Wrap: ' .. (vim.wo.wrap and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle line wrap' })

vim.keymap.set('n', '<leader>ul', function()
  local nu = not vim.wo.number
  vim.wo.number = nu
  vim.wo.relativenumber = nu
  vim.notify('Line numbers: ' .. (nu and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle line numbers' })

vim.keymap.set('n', '<leader>ud', function()
  local enabled = vim.diagnostic.is_enabled()
  vim.diagnostic.enable(not enabled)
  vim.notify(
    'Diagnostics: ' .. (not enabled and 'ON' or 'OFF'),
    vim.log.levels.INFO
  )
end, { desc = 'Toggle diagnostics' })

vim.keymap.set('n', '<leader>uc', function()
  local cl = vim.wo.conceallevel == 0 and 2 or 0
  vim.wo.conceallevel = cl
  vim.notify('Conceal level: ' .. cl, vim.log.levels.INFO)
end, { desc = 'Toggle conceal level' })

vim.keymap.set('n', '<leader>uh', function()
  local enabled = vim.lsp.inlay_hint.is_enabled()
  vim.lsp.inlay_hint.enable(not enabled)
  vim.notify(
    'Inlay hints: ' .. (not enabled and 'ON' or 'OFF'),
    vim.log.levels.INFO
  )
end, { desc = 'Toggle inlay hints' })

vim.keymap.set('n', '<leader>us', function()
  vim.wo.spell = not vim.wo.spell
  vim.notify('Spell: ' .. (vim.wo.spell and 'ON' or 'OFF'), vim.log.levels.INFO)
end, { desc = 'Toggle spell check' })
