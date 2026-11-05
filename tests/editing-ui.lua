vim.opt.rtp:prepend(vim.env.NVIM_TEST_ROOT)
vim.g.mapleader = " "
vim.o.swapfile = false
vim.o.hidden = true
vim.o.columns = 160
vim.o.lines = 50
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
for _, name in ipairs {
  "stay-centered.nvim",
  "mini.surround",
  "mini.animate",
  "nvim-treesitter-context",
  "noice.nvim",
  "nui.nvim",
  "snacks.nvim",
  "fff.nvim",
} do
  vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/" .. name)
end
local function spec(file, name)
  local plugin = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/" .. file .. ".lua")
  assert(plugin[1] == name, "Missing plugin: " .. name)
  return plugin
end
local owners = {}
for _, file in ipairs(vim.fn.glob(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/*.lua", false, true)) do
  local plugin = dofile(file)
  assert(type(plugin[1]) == "string" and plugin[2] == nil, "Each file must configure exactly one plugin: " .. file)
  assert(not owners[plugin[1]], "Plugin settings are split across files: " .. plugin[1])
  owners[plugin[1]] = file
end

local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local function check_preview_scroll(input_win, list_win, preview_win, selected)
  local function topline() return vim.api.nvim_win_call(preview_win, vim.fn.winsaveview).topline end
  for _, win in ipairs { input_win, list_win } do
    vim.api.nvim_set_current_win(win)
    for _, mode in ipairs(win == input_win and { "i", "n" } or { "n" }) do
      for _, key in ipairs { "<C-l>", "<C-;>" } do
        assert(vim.fn.maparg(key, mode, false, true).buffer == 1, key .. " must be local to the picker")
      end
    end
    local item, before = selected(), topline()
    feed "<C-;>"
    assert(vim.wait(1000, function() return topline() > before end, 10), "Ctrl-; did not scroll the preview down")
    local after = topline()
    feed "<C-l>"
    assert(vim.wait(1000, function() return topline() < after end, 10), "Ctrl-L did not scroll the preview up")
    assert(selected() == item, "Preview scrolling moved the selected result")
  end
end

local centered = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/stay-centered.lua")
local stay = require "stay-centered"
stay.setup(centered.opts)
assert(not stay.cfg.enabled, "Stay Centered must start disabled")
local toggle = centered.keys[1]
vim.keymap.set("n", toggle[1], toggle[2])
feed " Z"
assert(stay.cfg.enabled, "Stay Centered toggle did not enable centering")
feed " Z"
assert(not stay.cfg.enabled, "Stay Centered toggle did not disable centering")

local animate = require "mini.animate"
local animation = spec("mini-animate", "echasnovski/mini.animate")
local community = dofile(
  vim.env.NVIM_TEST_PLUGINS .. "/astrocommunity/lua/astrocommunity/scrolling/mini-animate/init.lua"
)
animate.setup(vim.tbl_deep_extend("force", community.opts(), animation.opts))
assert(animate.config.scroll.enable, "Mini Animate scrolling must be enabled")
for _, name in ipairs { "cursor", "resize", "open", "close" } do
  assert(not animate.config[name].enable, "Mini Animate must only animate scrolling: " .. name)
end
-- Keep unrelated picker and editing checks independent of animation timing.
vim.g.minianimate_disable = true

require("mini.surround").setup(spec("mini-surround", "nvim-mini/mini.surround").opts)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "word" })
feed 'saiw"'
assert(vim.api.nvim_get_current_line() == '"word"', "Mini Surround did not add quotes")
feed 'sd"'
assert(vim.api.nvim_get_current_line() == "word", "Mini Surround did not remove quotes")
vim.bo.modified = false

local context = require "treesitter-context"
context.setup(spec("treesitter-context", "nvim-treesitter/nvim-treesitter-context").opts)
assert(context.enabled(), "Tree-sitter context is not enabled")
local context_lines = { "local function example()" }
for i = 2, 80 do
  context_lines[i] = "  print(" .. i .. ")"
end
context_lines[81] = "end"
vim.api.nvim_buf_set_lines(0, 0, -1, false, context_lines)
vim.bo.filetype = "lua"
vim.treesitter.start(0, "lua")
vim.api.nvim_win_set_cursor(0, { 60, 0 })
vim.cmd "normal! zz"
vim.cmd.redraw()
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = 0 })
assert(
  vim.wait(2000, function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.w[win].treesitter_context then
        return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, 1, false)[1] == context_lines[1]
      end
    end
    return false
  end, 10),
  "Tree-sitter context did not display the enclosing function"
)
vim.bo.modified = false

local noice = require "noice.config"
noice.setup(spec("noice", "folke/noice.nvim").opts)
for _, name in ipairs { "search_down", "search_up" } do
  local search = noice.options.cmdline.format[name]
  assert(search.view == "cmdline_popup", name .. " must use a popup")
  assert(search.opts.position.row == "50%" and search.opts.position.col == "50%", name .. " is not centered")
end
assert(noice.options.views.cmdline_popup.position.row == 3, "Normal command palette position changed")
assert(noice.options.messages.enabled, "Noice messages must be enabled")
for _, field in ipairs { "view", "view_error", "view_warn" } do
  assert(noice.options.messages[field] == "mini", field .. " must use the bottom-right message view")
end
local mini = require("noice.config.views").get_options "mini"
assert(
  mini.relative == "editor" and mini.position.row == -1 and mini.position.col == "100%",
  "Message popups must appear in the bottom-right corner"
)
assert(noice.options.messages.view_history == "messages", "Message history must remain available")

local fff = spec("fff", "dmtrKovalenko/fff.nvim")
require("fff").setup(fff.opts)
local config = require("fff.conf").get()
local layout = require("fff.layout").compute(config, true)
assert(config.layout.anchor == "bottom" and config.layout.width == 1, "FFF must be full-width at the bottom")
assert(config.layout.height == 0.4, "FFF should leave most of the file visible")
assert(layout.layout.input_row > vim.o.lines / 2, "FFF prompt is not in the lower part of the editor")

require("snacks").setup(spec("snacks", "folke/snacks.nvim").opts)
vim.bo.buflisted = false
local function buffer(name, modified)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, vim.env.NVIM_TEST_TMP .. "/" .. name)
  local lines = { "unsaved text" }
  for i = 2, 200 do
    lines[i] = "-- preview line " .. i
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = modified
  return buf
end
local alpha = buffer("alpha.lua", false)
local beta = buffer("beta.lua", true)
vim.api.nvim_set_current_buf(beta)
local picker = Snacks.picker.buffers()
assert(
  vim.wait(2000, function() return picker:count() == 2 and picker.input.win:valid() end, 10),
  "Buffer picker did not open"
)
assert(picker.resolved_layout.layout.row == -1, "Snacks must be anchored at the bottom")
assert(picker.resolved_layout.layout.width == 0, "Snacks must use the full editor width")
assert(picker.resolved_layout.layout.position == nil, "Snacks should float, not create a split")
assert(picker.opts.win.input.keys["<C-X>"][1] == "bufdelete", "Buffer deletion shortcut is missing")
assert(
  vim.wait(
    2000,
    function() return picker.preview.win:valid() and vim.api.nvim_buf_line_count(picker.preview.win.buf) == 200 end,
    10
  ),
  "Buffer preview did not load"
)
check_preview_scroll(
  picker.input.win.win,
  picker.list.win.win,
  picker.preview.win.win,
  function() return picker:current().buf end
)
for i, item in ipairs(picker:items()) do
  if item.buf == alpha then picker.list:view(i) end
end
picker:action "bufdelete"
assert(
  vim.wait(1000, function() return not vim.api.nvim_buf_is_loaded(alpha) end, 10),
  "Buffer deletion did not remove the selected buffer"
)
assert(vim.bo[beta].modified, "Deleting another buffer discarded unsaved changes")
picker:action "confirm"
assert(vim.wait(1000, function() return picker.closed end, 10), "Selection did not close the picker")
assert(vim.api.nvim_get_current_buf() == beta, "Selection did not return to the remaining buffer")
assert(vim.api.nvim_buf_get_lines(beta, 0, -1, false)[1] == "unsaved text", "Unsaved text changed")

local project = vim.env.NVIM_TEST_TMP .. "/project"
vim.fn.mkdir(project, "p")
local lines = {}
for i = 1, 200 do
  lines[i] = "-- preview line " .. i
end
vim.fn.writefile(lines, project .. "/preview.lua")
require("fff").find_files { cwd = project }
local ui = require "fff.picker_ui.picker_ui"
assert(
  vim.wait(
    3000,
    function()
      return ui.state.active and ui.state.preview_buf and vim.api.nvim_buf_line_count(ui.state.preview_buf) == 200
    end,
    10
  ),
  "FFF preview did not load"
)
check_preview_scroll(ui.state.input_win, ui.state.list_win, ui.state.preview_win, function() return ui.state.cursor end)
ui.close()

-- Exercise the thin AstroNvim hook without touching a real clipboard.
local executable, clipboard, pane = vim.fn.executable, vim.g.clipboard, vim.env.HERDR_PANE_ID
vim.fn.executable = function() return 0 end
vim.env.HERDR_PANE_ID = "test-pane"
dofile(vim.env.NVIM_TEST_ROOT .. "/lua/polish.lua")
assert(vim.g.clipboard.name == "OSC 52", "Clipboard fallback was lost")
assert(vim.deep_equal(vim.g.clipboard.paste["+"](), { {}, "v" }), "Herdr clipboard reads must not block")
vim.fn.executable = function(name) return name == "pbcopy" and 1 or 0 end
vim.g.clipboard = { name = "native clipboard fixture" }
dofile(vim.env.NVIM_TEST_ROOT .. "/lua/polish.lua")
assert(vim.g.clipboard.name == "native clipboard fixture", "Native clipboard configuration was overwritten")
vim.fn.executable, vim.g.clipboard, vim.env.HERDR_PANE_ID = executable, clipboard, pane

-- Local window navigation wins; Herdr is contacted only at the editor edge.
local system, herdr = vim.fn.system, vim.env.HERDR_BIN_PATH
local command
vim.fn.system = function(args)
  command = args
  return ""
end
vim.env.HERDR_PANE_ID, vim.env.HERDR_BIN_PATH = "test-pane", "test-herdr"
dofile(vim.env.NVIM_TEST_ROOT .. "/after/plugin/herdr_nav.lua")
vim.cmd "botright vsplit"
local right = vim.api.nvim_get_current_win()
feed "<C-h>"
assert(vim.api.nvim_get_current_win() ~= right and command == nil, "Navigation skipped a Neovim split")
feed "<C-h>"
assert(
  vim.deep_equal(command, { "test-herdr", "pane", "focus", "--direction", "left", "--pane", "test-pane" }),
  "Herdr navigation lost its explicit pane target"
)
vim.api.nvim_win_close(right, true)
vim.fn.system, vim.env.HERDR_PANE_ID, vim.env.HERDR_BIN_PATH = system, pane, herdr

vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/AstroNvim")
vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/LuaSnip")
dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/luasnip.lua").config(nil, {})
local luasnip = require "luasnip"
local date
for _, snippet in ipairs(luasnip.get_snippets "all") do
  if snippet.trigger == "date" then date = snippet end
end
assert(date, "Personal snippets were not loaded from lua/user/snippets")
vim.cmd.enew()
luasnip.snip_expand(date)
assert(vim.api.nvim_get_current_line() == os.date "%Y-%m-%d", "Relocated date snippet stopped expanding")

print "PASS: one plugin per file, clipboard/navigation/snippet hooks, editing plugins, search/messages, pickers, and preview shortcuts"
