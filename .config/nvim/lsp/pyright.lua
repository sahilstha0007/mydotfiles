-- Pyright (Python). Owns completion, hover, go-to-definition, references and
-- type-checking for Python. Ruff (see lsp/ruff.lua) owns lint + format and
-- deliberately disables hover so pyright provides it.
--
-- The interpreter is chosen via venv-selector.nvim (<leader>vs); venv-selector
-- points pyright at the selected virtualenv's python automatically.
return {
  settings = {
    python = {
      analysis = {
        -- 'off' | 'basic' | 'standard' | 'strict' | 'all'
        typeCheckingMode = 'standard',
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        -- Suggest auto-imports for symbols not yet imported (very handy).
        autoImportCompletions = true,
        -- Only diagnose open files to keep big projects snappy.
        diagnosticMode = 'openFilesOnly',
        -- Missing type stubs are a hint, not an error.
        reportMissingTypeStubs = false,
      },
    },
  },
}
