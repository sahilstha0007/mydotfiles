-- Basedpyright (Python). Owns completion, hover, go-to-definition, references,
-- semantic tokens, inlay hints, and type-checking for Python.
-- Ruff (see lsp/ruff.lua) owns lint + format and deliberately disables hover
-- so basedpyright provides it.
--
-- The interpreter is chosen via venv-selector.nvim (<leader>vs); venv-selector
-- points basedpyright at the selected virtualenv's python automatically.
return {
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
