---@type LazySpec
return {
  "AstroNvim/astrolsp",
  init = function() require("user.obsidian.completion").setup() end,
  opts = {
    servers = { "markdown_oxide" },
    config = {
      markdown_oxide = require("user.obsidian.oxide").config,
    },
  },
}
