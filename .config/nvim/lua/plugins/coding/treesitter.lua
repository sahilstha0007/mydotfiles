return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    lazy = false,
    config = function()
      require('nvim-treesitter').setup()

      local ensure_installed = {
        -- language cores
        'bash',
        'c',
        'css',
        'dockerfile',
        'editorconfig',
        'gitignore',
        'go',
        'html',
        'javascript',
        'json',
        'lua',
        'markdown',
        'markdown_inline',
        'python',
        'scss',
        'sql',
        'svelte',
        'tsx',
        'typescript',
        'vim',
        'vue',
        'yaml',
        -- extras you actually use
        'diff',
        'luadoc',
        'ninja', -- python build sys you use
        'rst', -- python docs you use
        'php',
        'blade', -- laravel
        'astro', -- you have astro.lua
        'regex',
        'toml',
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
          vim.bo[args.buf].indentexpr =
            "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
