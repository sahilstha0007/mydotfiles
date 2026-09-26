-- PHP via intelephense. `cmd`, `filetypes`, and `root_markers` are inherited
-- from nvim-lspconfig's bundled `lsp/intelephense.lua`; we only override
-- settings.
return {
  settings = {
    intelephense = {
      files = {
        associations = { '*.php', '*.blade.php' },
        maxSize = 5000000,
      },
    },
  },
}