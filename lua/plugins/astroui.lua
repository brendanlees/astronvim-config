local theme = require("user.theme").active()
if theme.background then vim.opt.background = theme.background end

---@type LazySpec
return {
  "AstroNvim/astroui",
  opts = { colorscheme = theme.colorscheme },
}
