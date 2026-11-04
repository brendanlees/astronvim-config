local M = {}

-- Debugging is disabled, including adapters added by language packs.
local adapters = { "bash-debug-adapter", "debugpy", "php-debug-adapter" }

function M.options(opts)
  opts.ensure_installed = vim.list_extend(opts.ensure_installed or {}, {
    "markdown-oxide",
    "systemd-lsp",
    "astro-language-server",
    "stylua",
  })
  opts.ensure_installed = vim.tbl_filter(
    function(tool) return not vim.list_contains(adapters, type(tool) == "table" and tool[1] or tool) end,
    opts.ensure_installed or {}
  )
  return opts
end

return M
