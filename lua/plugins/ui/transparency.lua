return {
  {
    "nvim-tree/nvim-tree.lua",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "NvimTree",
        callback = function()
          vim.wo.winblend = 25
        end,
      })
      return opts
    end,
  },
}
