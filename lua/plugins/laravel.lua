return {
  {
    "adalessa/laravel.nvim",
    cond = function()
      return vim.fn.filereadable("artisan") == 1
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = require("astrocore").list_insert_unique(opts.ensure_installed or {}, {})
      -- Remove pint from ensure_installed
      opts.ensure_installed = vim.tbl_filter(function(tool)
        local name = type(tool) == "table" and tool[1] or tool
        return name ~= "pint"
      end, opts.ensure_installed)
    end,
  },
}
