--- AI coding-agent CLI launcher.
---
--- Opens Claude Code, opencode, or any future agent TUI. Strategy:
---   * inside tmux  -> open as a new tmux pane (right split). All your tmux
---     features (vim-tmux-navigator hopping, tmux.nvim resize, pane scrollback)
---     then apply to the agent automatically.
---   * otherwise    -> floating nvim terminal window.
---
--- keymaps:
---   <leader>a  pick & open an agent (focus the pane if already open)
---
--- Adding a new agent -> copy ONE line from the TEMPLATE block below.

-- ---------------------------------------------------------------------------
-- TEMPLATE — add any new AI CLI in ONE line. That's the whole integration.
--
--   { name = 'Codex',    cmd = 'codex' },          -- plain
--   { name = 'Aider',    cmd = 'aider --watch' },  -- with args
--   { name = 'Gemini',   cmd = 'gemini-cli' },
--
-- Uncomment a line or paste one here; `<leader>a` auto-lists it.
-- ---------------------------------------------------------------------------
local tools = {
  { name = 'Claude Code', cmd = 'claude' },
  { name = 'opencode', cmd = 'opencode' },
}

-- tmux split width % of the layout for the new pane
local SPLIT_PERCENT = '55'

-- floating-window fallback state (only used when not inside tmux)
local state = { win = nil }

local function open_in_tmux(cmd)
  vim.fn.system({
    'tmux', 'split-window', '-h', '-p', SPLIT_PERCENT,
    '-c', vim.uv.cwd(), cmd,
  })
  return vim.v.shell_error == 0
end

local function open_in_float(cmd)
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  local w, h = vim.o.columns, vim.o.lines
  local buf = vim.api.nvim_create_buf(false, true)
  state.win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    style = 'minimal',
    border = 'single',
    width = math.floor(w * 0.92),
    height = math.floor(h * 0.9),
    row = math.floor(h * 0.05),
    col = math.floor(w * 0.04),
  })
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false

  vim.fn.termopen(cmd, {
    on_exit = function()
      state.win = nil
    end,
  })
  vim.cmd 'startinsert'
end

local function open(cmd)
  if vim.env.TMUX and open_in_tmux(cmd) then
    return -- tmux pane owns it: full nav/resize/scrollback control
  end
  open_in_float(cmd) -- not in tmux, or tmux call failed
end

local function pick_and_open()
  if #tools == 1 then
    open(tools[1].cmd)
    return
  end
  vim.ui.select(tools, {
    prompt = 'Open AI agent (tmux pane):',
    format_item = function(t)
      return t.name
    end,
  }, function(sel)
    if sel then
      open(sel.cmd)
    end
  end)
end

return {
  {
    'folke/snacks.nvim',
    keys = {
      { '<leader>a', pick_and_open, desc = 'Open AI agent (claude/opencode)' },
    },
  },
}