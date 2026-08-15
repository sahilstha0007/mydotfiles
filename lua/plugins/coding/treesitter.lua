return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    lazy = false,
    config = function()
      require('nvim-treesitter').setup()

      local ensure_installed = {
        'astro',
        'bash',
        'c',
        'css',
        'diff',
        'dockerfile',
        'editorconfig',
        'gitignore',
        'go',
        'gomod',
        'gosum',
        'gowork',
        'html',
        'javascript',
        'json',
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'python',
        'sql',
        'tsx',
        'typescript',
        'vim',
        'vimdoc',
        'yaml',
      }

      require('nvim-treesitter').install(ensure_installed)

      vim.filetype.add {
        pattern = {
          ['config'] = 'dosini',
        },
      }

      vim.api.nvim_create_autocmd('FileType', {
        pattern = ensure_installed,
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
