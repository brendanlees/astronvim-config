-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      run_on_start = false,
      ensure_installed = {
        -- language servers
        "systemd-lsp",
        "astro-language-server",
        -- formatters
        "stylua",
      },
    },
    config = function(_, opts)
      require("mason-tool-installer").setup(opts)
      -- Hook into AstroNvim's own registry update rather than triggering a second one
      vim.api.nvim_create_autocmd("User", {
        pattern = "AstroMasonUpdateCompleted",
        once = true,
        callback = function() vim.cmd "MasonToolsInstall" end,
      })
    end,
  },
}
