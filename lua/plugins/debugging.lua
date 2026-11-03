-- No in-editor debugging: turn off the DAP stack that AstroNvim and the
-- language packs add, and skip installing their debug adapters.
local adapters = { "bash-debug-adapter", "debugpy", "php-debug-adapter" }

---@type LazySpec
return {
  { "mfussenegger/nvim-dap", enabled = false },
  { "rcarriga/nvim-dap-ui", enabled = false },
  { "mfussenegger/nvim-dap-python", enabled = false },
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },
  { "rcarriga/cmp-dap", enabled = false },
  { "saghen/blink.compat", enabled = false },
  { "nvim-neotest/nvim-nio", enabled = false },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(
        function(tool) return not vim.list_contains(adapters, type(tool) == "table" and tool[1] or tool) end,
        opts.ensure_installed or {}
      )
    end,
  },
}
