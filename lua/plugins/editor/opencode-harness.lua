local M = {}

-- What the agent is told about your state, pre-filled into every ask.
--
-- Order matters: @this first so the selection/cursor leads, then the wider
-- context. @this was silently missing before (see opencode-agent.lua) -- with
-- it gone, "explain this" meant "explain this whole file", which is how an
-- agent produces a confident answer to the wrong question.
--
-- @visible and @marks are deliberately NOT here: both dump large amounts of
-- text on every single ask, and they are one `@` away in the input when you
-- actually want them.
M.default = '@this @buffer @diagnostics @quickfix @agents '

---Ask with a specific prefix (used by the picker and by keymaps that want a
---different context set without editing M.default).
function M.ask_with(prefix)
  require('opencode').ask(prefix or M.default)
end

function M.ask()
  local buf = vim.api.nvim_get_current_buf()
  local path = vim.api.nvim_buf_get_name(buf)

  -- Refusing to ask on an unsaved buffer feels arbitrary, but it is not:
  -- `autoread` is on (options.lua:36), so when the agent writes to this file
  -- the buffer RELOADS. Undo history does not survive a reload, and any
  -- unsaved edit is silently replaced on disk. This used to hard-refuse and
  -- just notify -- technically safe, practically useless, because the buffer
  -- you most want to ask about is the one mid-edit.
  --
  -- So: save first, but let the user decide. Snacks' confirm returns a
  -- boolean; cancelling is a normal outcome, not an error.
  if path ~= '' and vim.bo[buf].modified then
    local name = vim.fn.fnamemodify(path, ':t')
    local choice = Snacks.picker.select({
      { id = 'save', label = 'Save and ask', desc = name .. ' has unsaved changes' },
      { id = 'discard', label = 'Discard changes and ask', desc = 'Drops your unsaved edits' },
      { id = 'cancel', label = 'Cancel', desc = 'Do not ask' },
    }, {
      prompt = 'Buffer has unsaved changes',
      format_item = function(item)
        return item.label .. (item.desc and ('  — ' .. item.desc) or '')
      end,
    })
    if not choice then
      return
    end
    if choice.id == 'save' then
      vim.cmd('silent write')
    elseif choice.id == 'discard' then
      -- Only offered because autoread makes the alternative "lose them anyway",
      -- silently, after the agent has already overwritten the file.
      vim.cmd('silent edit!')
    end
  end

  M.ask_with(M.default)
end

return M
