-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "williamboman/mason.nvim" },
    init = function()
      local aug = vim.api.nvim_create_augroup("mason-tool-installer", {})
      vim.api.nvim_create_autocmd("User", {
        pattern = "MasonToolsStartingInstall",
        group = aug,
        callback = function() vim.schedule(function() vim.cmd "Mason" end) end,
      })
    end,
    opts = {
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
  },
}
