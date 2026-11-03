-- AstroCommunity's chezmoi pack provides chezmoi.vim (template filetypes) and
-- chezmoi.nvim (apply source edits on save); this adds the target redirect.
---@type LazySpec
return {
  {
    "alker0/chezmoi.vim",
    init = function() require("user.chezmoi").setup() end,
  },
  {
    "AstroNvim/astrocore",
    opts = { options = { g = { ["chezmoi#source_dir_path"] = require("user.chezmoi").source_dir() } } },
  },
}
