local M = {}

-- Chezmoi writes this bridge from the shared theme registry on each apply.
function M.active()
  local ok, t = pcall(dofile, vim.fn.expand "~/.config/chezmoi-theme/active.lua")
  if ok and type(t) == "table" then return t end
  return { colorscheme = "tokyonight-night", background = "dark" }
end

return M
