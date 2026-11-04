---@type LazySpec
return {
  "arnamak/stay-centered.nvim",
  opts = { enabled = false },
  keys = {
    { "<Leader>Z", function() require("stay-centered").toggle() end, desc = "Toggle Stay Centered" },
  },
}
