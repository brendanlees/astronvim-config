---@type LazySpec
return {
  "shortcuts/no-neck-pain.nvim",
  version = "*",
  cmd = { "NoNeckPain", "NoNeckPainToggleLeftSide", "NoNeckPainToggleRightSide" },
  keys = {
    { "<Leader>z", "<cmd>NoNeckPain<cr>", desc = "Toggle No Neck Pain" },
  },
}
