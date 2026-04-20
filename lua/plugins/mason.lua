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
    config = function(_, opts)
      local mason_tool_installer = require "mason-tool-installer"
      mason_tool_installer.setup(opts)
      -- Wait for registry to be ready before checking installs
      local mr = require "mason-registry"
      if mr.refresh then
        mr.refresh(function()
          if opts.run_on_start ~= false then mason_tool_installer.run_on_start() end
        end)
      else
        if opts.run_on_start ~= false then mason_tool_installer.run_on_start() end
      end
    end,
  },
}
