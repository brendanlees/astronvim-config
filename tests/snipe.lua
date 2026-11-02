vim.go.loadplugins = true
vim.opt.rtp:prepend(vim.env.NVIM_TEST_PLUGINS .. "/lazy.nvim")
vim.o.swapfile = false
vim.o.hidden = true
local spec
for _, plugin in ipairs(dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/navigation.lua")) do
  if plugin[1] == "leath-dub/snipe.nvim" then spec = plugin end
end
assert(spec, "Snipe configuration missing")
local ui_select = vim.ui.select
require("lazy").setup({ spec }, {
  root = vim.env.NVIM_TEST_PLUGINS,
  lockfile = vim.env.NVIM_TEST_TMP .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
assert(not package.loaded.snipe, "Snipe should load on demand")
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
vim.bo.buflisted = false
local alpha = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(alpha, vim.env.NVIM_TEST_TMP .. "/alpha.md")
vim.api.nvim_set_current_buf(alpha)
local beta = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(beta, vim.env.NVIM_TEST_TMP .. "/beta.lua")
vim.api.nvim_set_current_buf(beta)
vim.api.nvim_buf_set_lines(beta, 0, -1, false, { "unsaved text" })

feed "gb"
local snipe = require "snipe"
local menu = snipe.global_menu
assert(vim.api.nvim_win_is_valid(menu.win), "gb did not open the menu")
assert(require("snipe.config").sort == "last", "Recent-buffer ordering was not configured")
local expected = require("snipe.buffer").get_buffers "ls t"
assert(#menu.items == 2 and #expected == 2, "Menu should contain the two listed buffers")
for i, item in ipairs(menu.items) do
  assert(item.id == expected[i].id, "Menu did not follow recent-buffer ordering")
end
local win = menu.win
local hint
for i, item in ipairs(menu.items) do
  if item.id == alpha then hint = vim.api.nvim_buf_get_lines(menu.buf, i - 1, i, false)[1]:match "^%S+" end
end
feed(assert(hint, "Alpha has no navigation hint"))
assert(vim.api.nvim_get_current_buf() == alpha, "Hint did not select the target buffer")
assert(not vim.api.nvim_win_is_valid(win), "Selection left the menu open")
assert(vim.bo[beta].modified, "Switching discarded unsaved changes")
assert(vim.api.nvim_buf_get_lines(beta, 0, -1, false)[1] == "unsaved text")

feed "gb"
win = menu.win
feed "<Esc>"
assert(not vim.api.nvim_win_is_valid(win), "Escape did not close the menu")
assert(vim.api.nvim_get_current_buf() == alpha, "Cancelling switched buffers")
assert(vim.ui.select == ui_select, "Snipe replaced unrelated selection menus")
print "PASS: gb lazy-loads Snipe, recent-buffer ordering, hint selection, Escape, and unsaved-buffer preservation"
