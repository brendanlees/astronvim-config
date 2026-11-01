vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
for _, name in ipairs { "bullets.nvim", "blink.cmp", "otter.nvim", "nvim-treesitter", "nvim-lspconfig" } do
  vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/" .. name)
end
vim.g.maplocalleader = ","
vim.o.hidden = true
vim.o.swapfile = false
vim.cmd "filetype plugin on"
local specs = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/markdown.lua")
local otter_spec, bullets_spec, blink_spec = specs[1], specs[2], specs[3]
bullets_spec.config(nil, bullets_spec.opts)
local cmp = require "blink.cmp"
local blink_opts = {
  keymap = {
    ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
    ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
  },
}
blink_spec.opts(nil, blink_opts)
cmp.setup(vim.tbl_deep_extend("force", blink_opts, {
  fuzzy = { implementation = "lua" },
  sources = { default = { "buffer" } },
  completion = { menu = { auto_show = false }, list = { selection = { preselect = false, auto_insert = false } } },
}))
assert(vim.wait(1000, function() return require("blink.cmp.fuzzy").implementation ~= nil end, 5))
local counter = 0
local function buffer(lines, row, ft)
  vim.cmd.enew()
  counter = counter + 1
  vim.api.nvim_buf_set_name(0, vim.env.NVIM_TEST_TMP .. "/markdown-" .. counter .. (ft == "lua" and ".lua" or ".md"))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft or "markdown"
  vim.bo.autoindent = true
  vim.bo.shiftwidth = 2
  vim.bo.expandtab = true
  vim.api.nvim_win_set_cursor(0, { row or 1, 0 })
  require("blink.cmp.keymap.apply").keymap_to_current_buffer {
    ["<CR>"] = require("blink.cmp.config").keymap["<CR>"],
    ["<Tab>"] = require("blink.cmp.config").keymap["<Tab>"],
    ["<S-Tab>"] = require("blink.cmp.config").keymap["<S-Tab>"],
  }
  return vim.api.nvim_get_current_buf()
end
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local function lines() return vim.api.nvim_buf_get_lines(0, 0, -1, false) end
buffer { "- first" }
feed "A<CR>second<Esc>"
assert(vim.deep_equal(lines(), { "- first", "- second" }), vim.inspect(lines()))
buffer { "1. first" }
feed "A<CR>second<Esc>"
assert(vim.deep_equal(lines(), { "1. first", "2. second" }), vim.inspect(lines()))
buffer { "- [x] done" }
feed "A<CR>next<Esc>"
assert(vim.deep_equal(lines(), { "- [x] done", "- [ ] next" }), vim.inspect(lines()))
buffer { "- " }
feed "A<CR><Esc>"
assert(vim.deep_equal(lines(), { "" }), vim.inspect(lines()))
buffer { "- first" }
feed "osecond<Esc>"
assert(vim.deep_equal(lines(), { "- first", "- second" }), vim.inspect(lines()))
buffer { "1. a", "8. b", "12. c" }
feed "gN"
assert(vim.deep_equal(lines(), { "1. a", "2. b", "3. c" }), vim.inspect(lines()))
print "PASS: bullets, numbering, unchecked task continuation, empty-list exit, normal o, and gN"

buffer { "- first" }
local original_accept = cmp.accept
local accepted = 0
cmp.accept = function()
  accepted = accepted + 1
  return true
end
feed "A<CR><Esc>"
cmp.accept = original_accept
assert(accepted == 1 and #lines() == 1)
vim.keymap.set("n", "<CR>", "<Cmd>let g:smart_seen=1<CR>", { buffer = true })
feed "<CR>"
assert(vim.g.smart_seen == 1)
assert(vim.fn.maparg(".", "n") == "")
assert(vim.fn.maparg("<Space>x", "n") == "")
print "PASS: selected-completion dispatch precedes list handling; normal Enter, dot-repeat key and Space-x remain untouched"

buffer({ "```text", "- not a list", "```" }, 2)
feed "A<CR>plain<Esc>"
assert(lines()[3] == "plain", vim.inspect(lines()))
buffer({ "```text", "- not a list", "```" }, 2)
feed "oplain<Esc>"
assert(lines()[3] == "plain", vim.inspect(lines()))
buffer({ "---", "tags:", "  - one", "---" }, 3)
feed "A<CR>two<Esc>"
assert(not lines()[4]:find("-", 1, true), vim.inspect(lines()))
buffer({ "local value = 1" }, 1, "lua")
assert(vim.fn.maparg("o", "n") == "")
feed "A<CR>local next_value = 2<Esc>"
assert(#lines() == 2)
print "PASS: list automation excluded from fenced code, YAML frontmatter, and non-Markdown buffers"

local editing = require "user.markdown.editing"
for _, marker in ipairs { "- ", "1. ", "- [ ] " } do
  buffer({ "- parent", marker }, 2)
  feed "A<Tab><Esc>"
  assert(lines()[2] == "    " .. marker, vim.inspect(lines()))
  feed "A<S-Tab><Esc>"
  assert(lines()[2] == marker, vim.inspect(lines()))
end
buffer({ "- parent", "- " }, 2)
local numbered = buffer({ "1. parent", "2. " }, 2)
feed "A<Tab>child<Esc>"
assert(lines()[2] == "    1. child" and vim.bo.shiftwidth == 2, vim.inspect(lines()))
local parser = vim.treesitter.get_parser(numbered, "markdown")
parser:parse()
local node = vim.treesitter.get_node { bufnr = numbered, pos = { 1, 7 }, ignore_injections = true }
local lists = 0
while node do
  if node:type() == "list" then lists = lists + 1 end
  node = node:parent()
end
assert(lists == 2, "Numbered child was not parsed as a nested list")
buffer({ "- parent", "- " }, 2)
local old_next = cmp.select_next
local selected = 0
cmp.select_next = function()
  selected = selected + 1
  return true
end
feed "A<Tab><Esc>"
assert(lines()[2] == "    - " and selected == 0)
buffer { "- text" }
feed "A<Tab><Esc>"
assert(selected == 1 and lines()[1] == "- text")
cmp.select_next = old_next
buffer({ "---", "- ", "---" }, 2)
assert(editing.tab(1) == nil)
buffer({ "~~~text", "- ", "~~~" }, 2)
assert(editing.tab(1) == nil)
print "PASS: Tab/Shift-Tab move empty bullets, numbers and checkboxes; completion elsewhere and syntax exclusions preserved"

local b = buffer { "- one", "- [x] two", "  - nested", "- three" }
editing.convert(b, 1, 4, "number")
assert(vim.deep_equal(lines(), { "1. one", "2. two", "  1. nested", "3. three" }), vim.inspect(lines()))
editing.convert(b, 1, 4, "checkbox")
assert(vim.deep_equal(lines(), { "- [ ] one", "- [ ] two", "  - [ ] nested", "- [ ] three" }))
editing.convert(b, 1, 4, "bullet")
assert(vim.deep_equal(lines(), { "- one", "- two", "  - nested", "- three" }))
b = buffer { "- [x] done", "- [ ] todo" }
editing.convert(b, 1, 2, "checkbox")
assert(lines()[1] == "- [x] done")
b = buffer { "---", "- yaml", "---", "", "- real", "", "```text", "- code", "```" }
editing.convert(b, 1, 9, "number")
assert(lines()[2] == "- yaml" and lines()[5] == "1. real" and lines()[8] == "- code" and lines()[4] == "")
local select = vim.ui.select
buffer { "- one", "- two", "- untouched" }
vim.ui.select = function(items, opts, cb) cb(items[2]) end
feed "ggVj,L"
assert(vim.deep_equal(lines(), { "1. one", "2. two", "- untouched" }), vim.inspect(lines()))
vim.ui.select = function(_, _, cb) cb(nil) end
feed ",L"
assert(lines()[1] == "1. one")
local callback
vim.ui.select = function(_, _, cb) callback = cb end
feed ",L"
vim.api.nvim_buf_set_lines(0, 0, 1, false, { "edited meanwhile" })
callback { kind = "checkbox" }
assert(lines()[1] == "edited meanwhile")
vim.ui.select = select
print "PASS: list menu mapping, selected/current conversion, nested numbering, checkbox states, code/YAML exclusions, cancellation and stale selections"

otter_spec.config(nil, otter_spec.opts)
otter_spec.init()
local main = buffer { "# Example", "", "```lua", "local value = 1", "print(value)", "```" }
assert(
  vim.wait(5000, function()
    local raft = require("otter.keeper").rafts[main]
    return raft and raft.buffers.lua and raft.otterls.client_id
  end, 10),
  "Otter did not activate"
)
local raft = require("otter.keeper").rafts[main]
assert(vim.api.nvim_buf_is_valid(raft.buffers.lua))
assert(vim.bo[raft.buffers.lua].filetype == "lua")
assert(not vim.uv.fs_stat(vim.api.nvim_buf_get_name(raft.buffers.lua)), "Otter wrote a sidecar")
local chunks = vim.api.nvim_buf_get_lines(raft.buffers.lua, 0, -1, false)
assert(table.concat(chunks, "\n"):find("local value = 1", 1, true))
vim.api.nvim_buf_set_lines(main, 3, 4, false, { "local value = 2" })
require("otter").sync_raft(main)
chunks = vim.api.nvim_buf_get_lines(raft.buffers.lua, 0, -1, false)
assert(table.concat(chunks, "\n"):find("local value = 2", 1, true))
vim.api.nvim_buf_set_lines(main, -1, -1, false, { "", "```python", "answer = 42", "```" })
vim.cmd.OtterActivate()
raft = require("otter.keeper").rafts[main]
assert(raft.buffers.python and vim.api.nvim_buf_is_valid(raft.buffers.python))
assert(not vim.uv.fs_stat(vim.api.nvim_buf_get_name(raft.buffers.python)))
print "PASS: Otter auto-activation, Lua extraction, edited-code synchronization, manual new-language refresh, and no disk sidecars"
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
print "ALL MARKDOWN INTEGRATION CHECKS PASSED"
