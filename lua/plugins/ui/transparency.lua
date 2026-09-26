return {
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "NvimTree",
        callback = function()
          -- full transparency: no frost on the tree
          vim.wo.winblend = 0
        end,
      })
      return opts
    end,
  },
}
