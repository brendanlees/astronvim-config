---@type LazySpec
return {
  "L3MON4D3/LuaSnip",
  config = function(plugin, opts) require("user.snippets").setup(plugin, opts) end,
}
