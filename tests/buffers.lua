vim.opt.rtp:prepend(vim.env.NVIM_TEST_ROOT)
vim.go.loadplugins = true
vim.opt.rtp:prepend(vim.env.NVIM_TEST_PLUGINS .. "/lazy.nvim")
vim.o.swapfile = false
vim.o.hidden = true
vim.g.mapleader = " "
vim.o.columns = 160
vim.o.lines = 50
local function spec(file, name)
  local plugin = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/" .. file .. ".lua")
  assert(plugin[1] == name, "Missing plugin: " .. name)
  return plugin
end
require("lazy").setup({
  spec("snacks", "folke/snacks.nvim"),
  spec("fff", "dmtrKovalenko/fff.nvim"),
}, {
  root = vim.env.NVIM_TEST_PLUGINS,
  lockfile = vim.env.NVIM_TEST_TMP .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
assert(not require("lazy.core.config").plugins["snipe.nvim"], "Snipe should no longer own gb")
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
vim.bo.buflisted = false
local function buffer(name, modified)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, vim.env.NVIM_TEST_TMP .. "/" .. name .. ".lua")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- unsaved text" })
  vim.bo[buf].modified = modified
  return buf
end
local alpha, beta = buffer("alpha", false), buffer("beta", true)
local gamma, delta = buffer("gamma", false), buffer("delta", false)
vim.api.nvim_set_current_buf(beta)
feed "gb"
local picker = assert(Snacks.picker.get()[1], "gb did not open Snacks")
assert(vim.wait(2000, function() return picker:count() == 4 and picker.list.win:valid() end, 10))
assert(picker.opts.source == "buffers", "gb did not open buffer view")
assert(picker.opts.sort_lastused, "Buffer view should retain recent-buffer ordering")
assert(vim.api.nvim_get_current_win() == picker.list.win.win, "Buffer manager should start in the result list")
local function highlight(buf)
  for i, item in ipairs(picker:items()) do
    if item.buf == buf then
      picker.list:view(i)
      return
    end
  end
  error("Buffer is missing from picker: " .. buf)
end
local function shown(buf)
  assert(vim.api.nvim_win_get_buf(picker.main) == buf, "g did not show the highlighted buffer")
  assert(not picker.closed and picker:is_focused(), "g must leave the picker open and focused")
end
highlight(alpha)
feed "<Tab>"
assert(#picker:selected() == 1 and picker:selected()[1].buf == alpha, "Tab did not select a buffer")
highlight(delta)
feed "g"
shown(delta)
assert(#picker:selected() == 1, "g should not change multi-selection")
highlight(beta)
vim.api.nvim_set_current_win(picker.input.win.win)
vim.cmd.stopinsert()
feed "g"
shown(beta)
assert(
  vim.fn.maparg("d", "i") == "" and vim.fn.maparg("g", "i") == "",
  "Typing a search must not trigger buffer actions"
)
vim.api.nvim_set_current_win(picker.list.win.win)
highlight(gamma)
feed "<Tab>"
assert(#picker:selected() == 2, "Tab did not select multiple buffers")
feed "d"
assert(
  vim.wait(
    2000,
    function()
      return not vim.api.nvim_buf_is_loaded(alpha) and not vim.api.nvim_buf_is_loaded(gamma) and picker:count() == 2
    end,
    10
  ),
  "d did not delete the selected buffers"
)
assert(not picker.closed, "Deleting buffers closed the picker")
assert(vim.bo[beta].modified, "Deleting other buffers discarded unsaved changes")
highlight(delta)
feed "d"
assert(
  vim.wait(2000, function() return not vim.api.nvim_buf_is_loaded(delta) and picker:count() == 1 end, 10),
  "d without a selection did not delete the highlighted buffer"
)
local confirm, prompted = vim.fn.confirm, false
vim.fn.confirm = function()
  prompted = true
  return 3
end
feed "d"
vim.fn.confirm = confirm
assert(
  prompted and vim.api.nvim_buf_is_loaded(beta) and vim.bo[beta].modified,
  "Deleting a modified buffer must allow cancellation"
)
feed "<CR>"
assert(vim.wait(1000, function() return picker.closed end, 10), "Enter should close the picker")
assert(vim.api.nvim_get_current_buf() == beta, "Enter did not open the remaining buffer")
assert(vim.api.nvim_buf_get_lines(beta, 0, -1, false)[1] == "-- unsaved text", "Unsaved text changed")
feed "gb"
picker = assert(Snacks.picker.get()[1])
assert(vim.wait(1000, function() return picker.list.win:valid() end, 10))
feed "<Esc>"
assert(picker.closed and vim.api.nvim_get_current_buf() == beta, "Escape should cancel without switching buffers")
-- Exercise the actual shortcuts and floating windows, not mocked picker APIs.
local project = vim.env.NVIM_TEST_TMP .. "/project"
vim.fn.mkdir(project, "p")
vim.fn.writefile({ "local needle = true" }, project .. "/needle.lua")
vim.cmd.cd(project)
local config = vim.fn.stdpath "config"
vim.fn.mkdir(config, "p")
vim.fn.writefile({ "-- config fixture" }, config .. "/init.lua")
local fff = require "fff.picker_ui.picker_ui"
local function snacks_windows(p)
  local wins = {}
  for _, win in pairs(p.layout.wins) do
    if win.win then wins[#wins + 1] = win.win end
  end
  for _, win in ipairs(p.layout.box_wins) do
    if win.win then wins[#wins + 1] = win.win end
  end
  return wins
end
local function closed(wins)
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then return false end
  end
  return true
end
for _, keys in ipairs { " ff", " fF", " fg", " fw", " fW", " fc", " fa", ":FFFFind<CR>" } do
  feed "gb"
  picker = assert(Snacks.picker.get()[1], "gb did not open Snacks")
  assert(vim.wait(2000, function() return picker.list.win:valid() end, 10))
  local old_wins = snacks_windows(picker)
  feed(keys)
  assert(fff.state.active, keys .. " did not open FFF")
  assert(
    vim.wait(1000, function() return picker.closed and closed(old_wins) end, 10),
    keys .. " left Snacks covering FFF"
  )
  assert(vim.api.nvim_get_current_win() == fff.state.input_win, "FFF prompt lost focus")
  vim.cmd.stopinsert()
  feed "ineedle<C-\\><C-n>"
  assert(
    vim.wait(1000, function() return fff.state.query:find("needle", 1, true) ~= nil end, 10),
    "FFF prompt did not accept input after switching from Snacks"
  )
  local fff_wins = { fff.state.input_win, fff.state.list_win, fff.state.preview_win, fff.state.file_info_win }
  feed "gb"
  picker = assert(Snacks.picker.get()[1], "gb did not replace FFF")
  assert(
    vim.wait(1000, function() return not fff.state.active and closed(fff_wins) and picker:is_focused() end, 10),
    "Snacks did not replace FFF and take focus"
  )
  feed "<Esc>"
  assert(picker.closed and vim.api.nvim_get_current_buf() == beta, "Cancelling did not restore the edited buffer")
  assert(vim.bo[beta].modified, "Switching pickers discarded unsaved changes")
end
print "PASS: buffer management, unsaved-change protection, and last-opened picker priority for FFF files/grep/config and Snacks"
