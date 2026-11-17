return {
  {
    -- nvim-vtsls: helper plugin for the vtsls language server. Provides the
    -- buffer-local `:VtsExec` command (organize_imports, fix_all, ...) and
    -- `:VtsRename`. REQUIRED for the keymaps in `lsp/vtsls.lua` — without it
    -- every `<leader>c{...}` TS keymap is a dead binding. It self-wires via a
    -- LspAttach autocmd (plugin/init.lua), so it only needs to be loaded
    -- before a TS/JS buffer attaches; `ft` lazy-load does exactly that.
    'yioneko/nvim-vtsls',
    ft = {
      'typescript',
      'typescriptreact',
      'javascript',
      'javascriptreact',
    },
    -- The plugin exposes no `setup()`, so `opts` alone would never apply:
    -- lazy's default config path calls require('vtsls').setup(opts), which
    -- does not exist. Its README pattern is require('vtsls').config({...}).
    config = function()
      require('vtsls').config {
        -- After an LSP "extract to function/constant" refactor, run rename
        -- on the new symbol immediately so you can name it inline.
        refactor_auto_rename = true,
      }
    end,
  },
}
