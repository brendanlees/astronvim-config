---@type LazySpec
return {
  "lukas-reineke/indent-blankline.nvim",
  optional = true,
  opts = function() require("user.markdown.indents").setup() end,
}
