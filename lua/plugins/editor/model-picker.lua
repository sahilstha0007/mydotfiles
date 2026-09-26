-- Model picker for the terminal harnesses (<leader>am).
--
-- Reads the IDs you have actually used (`model-history.lua`), lets you type a
-- new one, and launches `claude --model <id>` in a tmux pane or a float — the
-- same two paths the harness picker uses at <leader>a.

local history = require('plugins.editor.model-history')

local function launch(id)
  if vim.env.TMUX then
    vim.system({ 'tmux', 'split-window', '-h', '-c', vim.fn.getcwd(), 'claude', '--model', id })
  else
    require('snacks.terminal').open({ 'claude', '--model', id }, { win = { position = 'float' } })
  end
end

local function pick()
  local recent = history.models()
  if #recent == 0 then
    vim.notify('No `claude --model` usage found in shell history', vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = 'Model (empty = recent list): ' }, function(input)
    -- Empty input lists what you have used before; anything else is taken as a
    -- literal id, so a model the history has never seen still works.
    if not input or input == '' then
      vim.ui.select(recent, {
        prompt = 'Model (' .. #recent .. ' from your history)',
        format_item = function(id)
          return id
        end,
      }, function(choice)
        if choice then
          launch(choice)
        end
      end)
      return
    end
    launch(input)
  end)
end

return {
  {
    -- `virtual` = a local spec with no repo of its own. The name here is what
    -- lazy keys it by, so it must be unique. The previous
    -- { 'nvim-lua/plenary.nvim', ... } named this plugin `plenary.nvim` --
    -- the same name as the other local specs that borrowed it, so they all
    -- merged into one and every keymap after the first was silently dropped.
    'local-model-picker',
    virtual = true,
    lazy = true,
    keys = {
      { '<leader>am', pick, desc = 'AI Model (launch claude --model <id>)' },
    },
  },
}
