---@type LazySpec
return {
  "bullets-vim/bullets.nvim",
  ft = "markdown",
  opts = {
    enabled_file_types = { "markdown" },
    set_mappings = false,
    delete_last_bullet_if_empty = 2, -- Enter on an empty nested item returns to its parent level.
    nested_checkboxes = false,
    checkbox_markers = " ~!>x",
    custom_mappings = {
      { "i", "<C-CR>", "<CR>" },
      { "n", "gN", "<Plug>(bullets-renumber)" },
      { "x", "gN", "<Plug>(bullets-renumber)" },
    },
  },
  config = function(_, opts) require("user.markdown.editing").setup_bullets(opts) end,
}
