return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "neo-tree",
        callback = function()
          vim.wo.winblend = 15
        end,
      })
      return opts
    end,
  },
}
