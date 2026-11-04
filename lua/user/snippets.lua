local M = {}

function M.setup(plugin, opts)
  -- Preserve AstroNvim's bundled loaders and add the personal Lua collection.
  require "astronvim.plugins.configs.luasnip"(plugin, opts)
  require("luasnip.loaders.from_lua").lazy_load {
    paths = vim.api.nvim_get_runtime_file("lua/user/snippets", false),
  }
end

return M
