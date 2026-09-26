-- AI agent harness picker (<leader>a).
--
-- Detection is dynamic: any known agent CLI found on PATH shows up
-- automatically, and the ways you can use it are computed at invoke time —
-- if an in-editor bridge plugin is installed (opencode.nvim /
-- claudecode.nvim) it offers native diff-review; if an ACP client is
-- installed (CodeCompanion / Avante) it offers ACP chat; the terminal TUI
-- is always the fallback. Install a new agent CLI or bridge plugin later
-- and this picker needs no edits.
--
-- Add a harness this list doesn't know: vim.g.agent_picker_extra = {
--   { cmd = 'myagent', label = 'My Agent', kind = 'terminal' },
-- }
-- kind only decides which native/ACP integrations are offered; 'terminal'
-- is always valid.

local KNOWN = {
  { cmd = 'claude', label = 'Claude Code', kind = 'claude' },
  { cmd = 'opencode', label = 'opencode', kind = 'opencode' },
  { cmd = 'codex', label = 'Codex CLI', kind = 'codex' },
  { cmd = 'gemini', label = 'Gemini CLI', kind = 'gemini' },
  { cmd = 'copilot', label = 'GitHub Copilot CLI', kind = 'copilot' },
  { cmd = 'aider', label = 'Aider', kind = 'terminal' },
  { cmd = 'goose', label = 'Goose', kind = 'terminal' },
  { cmd = 'crush', label = 'Crush', kind = 'terminal' },
  { cmd = 'amp', label = 'Amp', kind = 'terminal' },
  { cmd = 'cursor-agent', label = 'Cursor Agent', kind = 'terminal' },
  { cmd = 'q', label = 'Amazon Q', kind = 'terminal' },
  { cmd = 'plandex', label = 'Plandex', kind = 'terminal' },
}

local function installed(plugin)
  return vim.fn.isdirectory(vim.fn.stdpath 'data' .. '/lazy/' .. plugin) == 1
end

local function detected()
  local list = vim.deepcopy(KNOWN)
  vim.list_extend(list, vim.g.agent_picker_extra or {})
  return vim.tbl_filter(function(agent)
    return vim.fn.exepath(agent.cmd) ~= ''
  end, list)
end

local function terminal(agent)
  if vim.env.TMUX then
    vim.system({ 'tmux', 'split-window', '-h', '-c', vim.fn.getcwd(), agent.cmd }, { text = true })
  else
    require('snacks.terminal').open(agent.cmd, { win = { position = 'float' } })
  end
end

local function integrations(agent)
  local options = {}

  if agent.kind == 'opencode' and installed 'opencode.nvim' then
    table.insert(options, {
      name = 'opencode.nvim — in-editor, diff review before apply',
      run = function()
        require('plugins.editor.opencode-harness').ask()
      end,
    })
  end

  if agent.kind == 'claude' and installed 'claudecode.nvim' then
    table.insert(options, {
      name = 'claudecode.nvim — in-editor, diff accept/reject',
      run = function()
        vim.cmd 'ClaudeCode'
      end,
    })
  end

  if installed 'codecompanion.nvim' then
    table.insert(options, {
      name = 'CodeCompanion ACP chat (pick adapter in buffer)',
      run = function()
        vim.cmd 'CodeCompanionChat'
      end,
    })
  elseif installed 'avante.nvim' then
    table.insert(options, {
      name = 'Avante ACP chat',
      run = function()
        vim.cmd 'Avante'
      end,
    })
  end

  table.insert(options, { name = 'Terminal TUI (tmux pane / float)', run = function()
    terminal(agent)
  end })

  return options
end

return {
  {
    -- `virtual` = a local spec with no repo. The name is the lazy key and must
    -- be unique; see model-picker.lua for why the plenary string was wrong.
    'local-agent-picker',
    virtual = true,
    lazy = true,
    keys = {
    {
      '<leader>a',
      function()
        local agents = detected()
        if #agents == 0 then
          vim.notify('No agent CLIs found on PATH', vim.log.levels.WARN)
          return
        end

        local choose = function(agent)
          local options = integrations(agent)
          if #options == 1 then
            options[1].run()
            return
          end
          vim.ui.select(options, {
            prompt = agent.label .. ' — how to use?',
            format_item = function(item)
              return item.name
            end,
          }, function(choice)
            if choice then
              choice.run()
            end
          end)
        end

        if #agents == 1 then
          choose(agents[1])
          return
        end

        vim.ui.select(agents, {
          prompt = 'AI Agent',
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if choice then
            choose(choice)
          end
        end)
      end,
      desc = 'AI Agent (auto-detected harnesses)',
    },
    },
  },
}

