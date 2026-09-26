-- TypeScript / JavaScript via vtsls. Inlay hints are configured here but only
-- render when toggled on with `<leader>th` (they are off by default, so no
-- idle CPU cost). The `@astrojs/ts-plugin` global plugin gives TS-aware Astro.
local inlay_hints = {
  enumMemberValues = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  parameterNames = { enabled = 'literals' },
  parameterTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  variableTypes = { enabled = false },
}

local language_settings = {
  updateImportsOnFileMove = { enabled = 'always' },
  suggest = { completeFunctionCalls = true },
  inlayHints = inlay_hints,
}

-- TS-specific keymaps (previously stuck inside a dead LazyVim-style
-- `opts.servers` block that the native vim.lsp.config API never reads).
-- Registered buffer-locally on attach so they only exist for TS/JS buffers.
local function on_attach(_, bufnr)
  local function map(keys, cmd, desc)
    vim.keymap.set('n', keys, cmd, { buffer = bufnr, desc = 'vtsls: ' .. desc })
  end

  map('gD', function()
    local params = vim.lsp.util.make_position_params()
    require('trouble').open {
      mode = 'lsp_command',
      params = {
        command = 'typescript.goToSourceDefinition',
        arguments = { params.textDocument.uri, params.position },
      },
    }
  end, 'Goto Source Definition')

  map('gR', function()
    require('trouble').open {
      mode = 'lsp_command',
      params = {
        command = 'typescript.findAllFileReferences',
        arguments = { vim.uri_from_bufnr(0) },
      },
    }
  end, 'File References')

  map('<leader>co', '<cmd>VtsExec organize_imports<cr>', 'Organize Imports')
  map('<leader>cM', '<cmd>VtsExec add_missing_imports<cr>', 'Add Missing Imports')
  map('<leader>cu', '<cmd>VtsExec remove_unused_imports<cr>', 'Remove Unused Imports')
  -- NOTE: buffer-local, so it shadows trouble.nvim's global `<leader>cD`
  -- (workspace diagnostics) on TS/JS buffers only. `<leader>cd` (buffer
  -- diagnostics) and `<leader>sD` (snacks workspace diagnostics) remain.
  map('<leader>cD', '<cmd>VtsExec fix_all<cr>', 'Fix All (source.fixAll.ts)')
  map('<leader>cV', '<cmd>VtsExec select_ts_version<cr>', 'Select TS Workspace Version')
end

return {
  on_attach = on_attach,
  settings = {
    complete_function_calls = true,
    vtsls = {
      enableMoveToFileCodeAction = true,
      autoUseWorkspaceTsdk = true,
      experimental = {
        maxInlayHintLength = 30,
        completion = {
          enableServerSideFuzzyMatch = true,
        },
      },
      tsserver = {
        globalPlugins = {
          {
            name = '@astrojs/ts-plugin',
            location = vim.env.MASON
              .. '/packages/astro-language-server/node_modules/@astrojs/ts-plugin',
            enableForWorkspaceTypeScriptVersions = true,
          },
        },
      },
    },
    typescript = language_settings,
    javascript = language_settings,
  },
}
