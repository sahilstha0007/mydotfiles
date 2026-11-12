-- Basedpyright (Python). Owns completion, hover, go-to-definition, references,
-- semantic tokens, inlay hints, and type-checking for Python.
-- Ruff (see lsp/ruff.lua) owns lint + format and deliberately disables hover
-- so basedpyright provides it.
--
-- The interpreter is chosen via venv-selector.nvim (<leader>vs); venv-selector
-- points basedpyright at the selected virtualenv's python automatically.
return {
  before_init = function(_, config)
    config.settings = config.settings or {}
    config.settings.python = config.settings.python or {}
    if config.settings.python.pythonPath then
      return
    end

    local py = nil
    if package.loaded['venv-selector'] then
      py = require('venv-selector').python()
    end
    if not py then
      py = require('utils.python_env').detect(config.root_dir)
    end
    if py then
      config.settings.python.pythonPath = py
    end
  end,
  settings = {
    basedpyright = {
      analysis = {
        -- 'off' | 'basic' | 'standard' | 'strict' | 'all'
        typeCheckingMode = 'standard',
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        autoImportCompletions = true,
        diagnosticMode = 'openFilesOnly',
        reportMissingTypeStubs = false,
        -- Avoid overly noisy any-type reports for standard dev flow
        reportAny = false,
        inlayHints = {
          variableTypes = true,
          callArgumentNames = true,
          functionReturnTypes = true,
          genericTypes = true,
        },
      },
    },
  },
}
