-- Customize Mason

---@type LazySpec
return {
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    opts = {
      ensure_installed = {
        "systemd-lsp",
        "astro-language-server",
        "stylua",
      },
    },
  },
}
