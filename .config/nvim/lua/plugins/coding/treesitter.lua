return {
  {
    'nvim-treesitter/nvim-treesitter',
    branch = 'main',
    build = ':TSUpdate',
    lazy = false,
    config = function(_, opts)
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

      if type(opts) == 'table' and type(opts.ensure_installed) == 'table' then
        for _, lang in ipairs(opts.ensure_installed) do
          if not vim.tbl_contains(ensure_installed, lang) then
            table.insert(ensure_installed, lang)
          end
        end
      end

      if vim.env.NVIM_NO_AUTO_INSTALL ~= '1' then
        require('nvim-treesitter').install(ensure_installed)
      end

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
