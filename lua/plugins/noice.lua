---@type LazySpec
return {
  "folke/noice.nvim",
  opts = {
    cmdline = {
      format = {
        search_down = { view = "cmdline_popup", opts = { position = { row = "50%", col = "50%" } } },
        search_up = { view = "cmdline_popup", opts = { position = { row = "50%", col = "50%" } } },
      },
    },
    messages = {
      enabled = true,
      view = "mini",
      view_error = "mini",
      view_warn = "mini",
    },
    notify = { enabled = false },
    popupmenu = { enabled = false },
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false },
      message = { enabled = false },
    },
    presets = {
      bottom_search = false,
      command_palette = true,
      long_message_to_split = false,
      lsp_doc_border = false,
      inc_rename = false,
    },
  },
}
