---@type LazySpec
return {
  "MeanderingProgrammer/render-markdown.nvim",
  commit = "8e8795368391036643b622875a6da6a51bcd33f4",
  lazy = true, -- Load only as an Obsidian query dependency.
  opts = function() return require("user.obsidian.queries").render_options() end,
}
