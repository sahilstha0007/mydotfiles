-- Keymap registration for checkpoints. The module is lua/checkpoints.lua.
-- `virtual` = a local spec with no repo of its own; the name is the lazy key,
-- so it has to be unique across the config.
return {
  'local-checkpoints',
  virtual = true,
  lazy = true,
  init = function()
    require('checkpoints').setup()
  end,
}
