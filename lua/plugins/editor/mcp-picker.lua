-- <Space>aM — MCP server manager. Module is lua/mcp-picker.lua; the spec is a
-- thin wrapper, for the same reason as checkpoints: a file on disk is not a
-- registered plugin, and lazy needs a name to key it by.
--
-- `aM`, not `as`: the opencode plugin already owns <Space>as, and lazy does
-- not warn on a duplicate key — the later spec simply loses, so the picker
-- would have been registered and unreachable. Uppercase M reads as "MCP" and
-- leaves lowercase am (model) alone.
return {
  'local-mcp-picker',
  virtual = true,
  lazy = true,
  keys = {
    {
      '<leader>aM',
      function()
        require('mcp-picker').pick()
      end,
      desc = 'MCP servers (add / list / remove)',
    },
  },
}
