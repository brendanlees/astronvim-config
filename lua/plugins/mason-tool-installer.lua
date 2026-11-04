---@type LazySpec
return {
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  opts = function(_, opts) return require("user.mason").options(opts) end,
}
