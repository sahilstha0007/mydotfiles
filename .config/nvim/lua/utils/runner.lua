-- Integrated Tmux / Terminal Code Runner & REPL
-- Sends code, lines, files, or REPL sessions directly to an adjacent Tmux pane.
local M = {}

---Find or automatically create an adjacent runner pane in the current tmux window.
---@return string|nil pane_id Target pane id (e.g. "%3") or nil
local function get_or_create_runner_pane()
  if not vim.env.TMUX or vim.env.TMUX == '' then
    vim.notify(
      'Not running inside tmux',
      vim.log.levels.WARN,
      { title = 'Runner' }
    )
    return nil
  end

  local cur_pane =
    vim.fn.system("tmux display-message -p '#{pane_id}'"):gsub('%s+', '')
  local panes_raw =
    vim.fn.system "tmux list-panes -F '#{pane_id} #{pane_current_command}'"
  local lines = vim.split(panes_raw, '\n', { trimempty = true })

  -- If there's already an adjacent non-editor pane in this window, reuse it
  for _, line in ipairs(lines) do
    local parts = vim.split(line, ' ', { trimempty = true })
    local pid, cmd = parts[1], parts[2] or ''
    if pid ~= cur_pane and not cmd:match 'nvim' and not cmd:match 'vim' then
      return pid
    end
  end

  -- No runner pane exists: split window horizontally below (30% height)
  local new_pane = vim.fn
    .system("tmux split-window -v -l 30% -P -F '#{pane_id}'")
    :gsub('%s+', '')
  -- Keep cursor focus on Neovim
  vim.fn.system('tmux select-pane -t ' .. cur_pane)
  return new_pane
end

---Send raw command or string to the runner pane.
---@param text string
---@param auto_enter? boolean (default true)
function M.send_to_runner(text, auto_enter)
  local target = get_or_create_runner_pane()
  if not target or target == '' then
    return
  end

  if auto_enter == nil then
    auto_enter = true
  end

  -- Send literal text safely to avoid shell escape ambiguities
  vim.fn.system { 'tmux', 'send-keys', '-t', target, '-l', text }
  if auto_enter then
    vim.fn.system { 'tmux', 'send-keys', '-t', target, 'Enter' }
  end
end

---Execute current file in the runner pane based on filetype.
function M.run_file()
  local file = vim.fn.expand '%:p'
  if file == '' then
    vim.notify('No file to run', vim.log.levels.WARN, { title = 'Runner' })
    return
  end

  if vim.bo.modified then
    vim.cmd 'silent! write'
  end

  local ft = vim.bo.filetype
  local cmd

  if ft == 'python' then
    local ok, py_env = pcall(require, 'utils.python_env')
    local py_bin = ok and py_env.detect() or 'python3'
    cmd = py_bin .. ' ' .. vim.fn.shellescape(file)
  elseif ft == 'javascript' then
    cmd = 'node ' .. vim.fn.shellescape(file)
  elseif ft == 'typescript' then
    if vim.fn.executable 'bun' == 1 then
      cmd = 'bun ' .. vim.fn.shellescape(file)
    elseif vim.fn.executable 'tsx' == 1 then
      cmd = 'npx tsx ' .. vim.fn.shellescape(file)
    else
      cmd = 'npx ts-node ' .. vim.fn.shellescape(file)
    end
  elseif ft == 'go' then
    cmd = 'go run ' .. vim.fn.shellescape(file)
  elseif ft == 'rust' then
    cmd = 'cargo run'
  elseif ft == 'sh' or ft == 'bash' then
    cmd = 'bash ' .. vim.fn.shellescape(file)
  elseif ft == 'zsh' then
    cmd = 'zsh ' .. vim.fn.shellescape(file)
  elseif ft == 'lua' then
    cmd = 'nvim -l ' .. vim.fn.shellescape(file)
  elseif ft == 'php' then
    cmd = 'php ' .. vim.fn.shellescape(file)
  else
    vim.notify(
      'No runner configured for filetype: ' .. ft,
      vim.log.levels.INFO,
      { title = 'Runner' }
    )
    return
  end

  M.send_to_runner(cmd)
  vim.notify('Running: ' .. cmd, vim.log.levels.INFO, { title = 'Runner' })
end

---Send the current line under cursor to runner and step forward.
function M.run_line()
  local line = vim.api.nvim_get_current_line()
  if line:match '^%s*$' then
    return
  end

  M.send_to_runner(line)

  -- Advance cursor to next line
  local r, c = unpack(vim.api.nvim_win_get_cursor(0))
  if r < vim.api.nvim_buf_line_count(0) then
    vim.api.nvim_win_set_cursor(0, { r + 1, c })
  end
end

---Send visual selection to runner pane.
function M.run_selection()
  local _, srow, scol = unpack(vim.fn.getpos "'<")
  local _, erow, ecol = unpack(vim.fn.getpos "'>")
  local lines = vim.api.nvim_buf_get_lines(0, srow - 1, erow, false)
  if #lines == 0 then
    return
  end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], scol, ecol)
  else
    lines[1] = string.sub(lines[1], scol)
    lines[#lines] = string.sub(lines[#lines], 1, ecol)
  end

  local text = table.concat(lines, '\n')
  M.send_to_runner(text)
end

---Switch cursor focus to the runner pane.
function M.focus_runner()
  local target = get_or_create_runner_pane()
  if target and target ~= '' then
    vim.fn.system('tmux select-pane -t ' .. target)
  end
end

---Interrupt running process and clear runner pane.
function M.kill_runner()
  local target = get_or_create_runner_pane()
  if not target or target == '' then
    return
  end
  vim.fn.system { 'tmux', 'send-keys', '-t', target, 'C-c' }
  vim.fn.system { 'tmux', 'send-keys', '-t', target, 'clear', 'Enter' }
  vim.notify(
    'Runner interrupted & cleared',
    vim.log.levels.INFO,
    { title = 'Runner' }
  )
end

---Launch or toggle interactive REPL for current filetype in runner pane.
function M.toggle_repl()
  local target = get_or_create_runner_pane()
  if not target or target == '' then
    return
  end

  local ft = vim.bo.filetype
  local repl_cmd = 'zsh'

  if ft == 'python' then
    if vim.fn.executable 'ipython' == 1 then
      repl_cmd = 'ipython'
    else
      local ok, py_env = pcall(require, 'utils.python_env')
      repl_cmd = (ok and py_env.detect()) or 'python3'
    end
  elseif ft == 'javascript' or ft == 'typescript' then
    if vim.fn.executable 'bun' == 1 then
      repl_cmd = 'bun repl'
    else
      repl_cmd = 'node'
    end
  elseif ft == 'lua' then
    repl_cmd = 'lua'
  elseif ft == 'php' then
    repl_cmd = 'php -a'
  end

  M.send_to_runner(repl_cmd)
  vim.notify(
    'Started REPL: ' .. repl_cmd,
    vim.log.levels.INFO,
    { title = 'Runner' }
  )
end

return M
