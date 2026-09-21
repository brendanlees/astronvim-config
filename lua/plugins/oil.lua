---@type LazySpec
return {
  {
    "stevearc/oil.nvim",
    -- Keep Neo-tree as the default explorer while Oil is evaluated.
    opts = {
      default_file_explorer = false,
      view_options = {
        show_hidden = true,
      },
    },
  },
}
