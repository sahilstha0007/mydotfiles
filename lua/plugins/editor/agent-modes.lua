-- Keymap registration for the agent/session picker. The module is
-- lua/agent-modes.lua. `virtual` = a local spec with no repo of its own; the
-- name is the lazy key, so it has to be unique across the config.
return {
  'local-agent-modes',
  virtual = true,
  lazy = true,
  init = function()
    require('agent-modes').setup()
  end,
}
