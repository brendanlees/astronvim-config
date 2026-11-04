---@type LazySpec
return {
  "saghen/blink.cmp",
  opts = function(_, opts)
    opts.cmdline = vim.tbl_deep_extend("force", opts.cmdline or {}, {
      completion = { menu = { auto_show = false } },
    })
    require("user.markdown.editing").completion_options(opts)
  end,
}
