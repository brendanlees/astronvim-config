-- AstroUI provides the basis for configuring the AstroNvim User Interface
-- Configuration documentation can be found with `:h astroui`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

-- Active theme is driven by the chezmoi global theme registry
-- (.chezmoidata/themes.yml in the dotfiles repo). chezmoi templates the
-- bridge file at ~/.config/chezmoi-theme/active.lua on every `chezmoi apply`,
-- so a `theme <name>` swap propagates here automatically. Falls back to a
-- hardcoded default if the bridge file is missing (fresh machine, etc.).
local function active_theme()
  local ok, t = pcall(dofile, vim.fn.expand("~/.config/chezmoi-theme/active.lua"))
  if ok and type(t) == "table" then return t end
  return { colorscheme = "tokyonight-night", background = "dark" }
end

local theme = active_theme()
if theme.background then vim.opt.background = theme.background end

---@type LazySpec
return {
  "AstroNvim/astroui",
  ---@type AstroUIOpts
  opts = {
    colorscheme = theme.colorscheme,
  },
}
