-- Model IDs you have actually used with `claude --model`, newest first.
--
-- Split out from the picker so the parser can be tested without a UI, and so
-- the picker file stays a lazy spec. `omniroute models` is deliberately not
-- used: it lists upstream display names and paginates, and none of what it
-- returns is a valid `claude --model` argument.

local M = {}

local function history_path()
  return vim.env.ZSH_HISTORY or (vim.env.HOME .. '/.zsh_history')
end

function M.models()
  local path = history_path()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local seen, ordered = {}, {}
  local lines = vim.fn.readfile(path)
  -- Walk backwards so the most recent model sorts first.
  for i = #lines, 1, -1 do
    -- zsh extended history prefixes each line with "<index> <timestamp> ".
    -- %f[%w] keeps the match anchored to a word boundary so that a bare
    -- "myclaude --model x" is not mistaken for the real command.
    -- The class has to carry @ and : ("cf/@cf/...", "kc/minimax/minimax-m3:free")
    -- — leaving them out truncated ids to a prefix that does not exist upstream.
    -- Trailing shell punctuation (' and \) is dropped for free: neither is in the
    -- class, so a match simply stops before them.
    local id = lines[i]:match('%f[%w]claude%s+%-%-model%s+([%w/_%-%.:@]+)')
    if id and not seen[id] then
      seen[id] = true
      table.insert(ordered, id)
    end
  end
  return ordered
end

return M
