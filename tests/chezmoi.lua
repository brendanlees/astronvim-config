vim.opt.rtp:prepend(vim.env.NVIM_TEST_ROOT)
vim.o.swapfile = false
vim.o.hidden = true
local root = vim.env.HOME .. "/fixture"
vim.fn.mkdir(root .. "/source", "p")
local entries = {}
local function managed(name, source_name)
  local entry = { absolute = root .. "/" .. name, sourceAbsolute = root .. "/source/" .. source_name }
  vim.fn.writefile({ "live" }, entry.absolute)
  vim.fn.writefile({ "source" }, entry.sourceAbsolute)
  table.insert(entries, entry)
  return entry
end
local plain = managed("plain.json", "plain.json")
local created = managed("settings.json", "create_private_settings.json")
local modified = managed("shortcuts.json", "modify_private_shortcuts.json")
vim.fn.mkdir(vim.fn.stdpath "cache", "p")
vim.fn.writefile({ vim.json.encode(entries) }, vim.fn.stdpath "cache" .. "/chezmoi-managed.json")
require("user.chezmoi").setup()

-- macOS temp paths are symlinks, and Neovim may name buffers by either path.
local real = vim.uv.fs_realpath
local function open(path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  vim.wait(50, function() return false end)
  return real(vim.api.nvim_buf_get_name(0))
end

assert(open(plain.absolute) == real(plain.sourceAbsolute), "Managed files should open their chezmoi source")
assert(not vim.api.nvim_buf_is_valid(vim.fn.bufnr(real(plain.absolute))), "The redirected target buffer should be removed")
for _, entry in ipairs { created, modified } do
  assert(open(entry.absolute) == real(entry.absolute), "Seed and modify sources must not replace " .. entry.absolute)
  assert(vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == "live", "The live file should be shown")
end

local current = vim.api.nvim_get_current_buf()
local background = vim.fn.bufadd(plain.absolute)
vim.fn.bufload(background)
vim.wait(50, function() return false end)
assert(vim.api.nvim_get_current_buf() == current, "Background loads must not take over the current window")
assert(vim.api.nvim_buf_is_valid(background), "Background buffers must not be deleted")
