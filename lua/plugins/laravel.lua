return {
  {
    "adalessa/laravel.nvim",
    cond = function()
      return vim.fn.filereadable("artisan") == 1
    end,
  },
}
