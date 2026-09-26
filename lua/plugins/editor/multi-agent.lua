-- <Space>aA — run another agent beside this one.
--
-- virtual = true + a unique name, per the three silent ways a local spec never
-- reaches the keyboard (see wiki: Lazy.nvim Local Specs).
return {
  'local-multi-agent',
  virtual = true,
  lazy = true,
  init = function()
    require('multi-agent').setup()
  end,
  keys = {
    {
      '<leader>aA',
      function()
        require('multi-agent').pick()
      end,
      desc = 'Agents: run another beside this one',
    },
  },
}
