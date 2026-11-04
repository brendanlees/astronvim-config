---@type LazySpec
return {
  "dpezto/obsidian-query.nvim",
  -- Pin the trial to the versions checked with our Obsidian cache and renderer hooks.
  commit = "9c1de910ca42eb535326f2645f9654c62868ff1c",
  lazy = true,
  opts = { picker = { style = "rich" } },
  config = function(_, opts)
    require("user.obsidian.queries").setup()
    require("obsidian-query").setup(opts)
  end,
  dependencies = {
    "MeanderingProgrammer/render-markdown.nvim",
  },
}
