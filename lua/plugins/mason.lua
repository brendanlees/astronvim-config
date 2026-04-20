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
        -- other
        "tree-sitter-cli",
      },
    },
    config = function(_, opts)
      require("mason-tool-installer").setup(opts)
      -- Only install after Mason registries have fully updated
      vim.api.nvim_create_autocmd("User", {
        pattern = "MasonRegistryUpdateSuccess",
        once = true,
        callback = function() vim.cmd "MasonToolsInstall" end,
      })
      -- Trigger the registry update
      require("mason-registry").update()
    end,
  },
}
