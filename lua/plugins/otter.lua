---@type LazySpec
return {
  "jmbuhr/otter.nvim",
  ft = "markdown",
  dependencies = { "nvim-treesitter/nvim-treesitter" },
  opts = {
    buffers = { write_to_disk = false },
  },
  init = function() require("user.markdown.otter").init() end,
  config = function(_, opts) require("user.markdown.otter").setup(opts) end,
}
