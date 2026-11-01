local bookmarks = require "obsidian.bookmarks"
local note = assert(require("obsidian.api").current_note(0))
local relative = note.path:vault_relative_path()
local root = tostring(require("obsidian.api").resolve_workspace_dir())
local file = root .. "/.obsidian/bookmarks.json"
local original_note = vim.api.nvim_buf_get_lines(0, 0, -1, false)
local toggle = vim.fn.maparg(",b", "n", false, true)
assert(toggle.buffer == 1 and type(toggle.callback) == "function", ",b must be a note-local toggle")
local search = vim.fn.maparg(",.b", "n", false, true)
assert(search.buffer == 1 and search.rhs == "<Cmd>Obsidian bookmarks<CR>", ",.b must open Obsidian bookmarks")

local function read() return vim.json.decode(table.concat(vim.fn.readfile(file), "\n")) end
local function write(data) vim.fn.writefile({ vim.json.encode(data) }, file) end
toggle.callback()
local first = read()
assert(#first.items == 1 and first.items[1].type == "file" and first.items[1].path == relative)
assert(type(first.items[1].ctime) == "number")
toggle.callback()
assert(#read().items == 0, "Second toggle did not remove the note bookmark")

local preserved = {
  { type = "file", path = "another note.md", title = "Other note", ctime = 1 },
  { type = "file", path = relative, subpath = "#Heading", ctime = 2 },
  { type = "file", path = relative, subpath = "#^block-id", ctime = 3 },
  { type = "url", url = "https://example.com", title = "Example", ctime = 4 },
  { type = "search", query = "tag:#project", title = "Projects", ctime = 5 },
  { type = "folder", path = "projects", ctime = 6 },
}
local fixture = {
  custom = "preserve top-level metadata",
  items = vim.deepcopy(preserved),
}
fixture.items[#fixture.items + 1] = { type = "file", path = relative, title = "Named note", ctime = 7 }
fixture.items[#fixture.items + 1] = {
  type = "group",
  title = "Pinned reading",
  ctime = 8,
  items = {
    {
      type = "group",
      title = "Nested",
      ctime = 9,
      items = {
        { type = "file", path = relative, ctime = 10 },
        { type = "file", path = "keep me.md", ctime = 11 },
      },
    },
  },
}
write(fixture)
toggle.callback()
local after = read()
assert(after.custom == fixture.custom, "Top-level bookmark metadata was lost")
assert(#after.items == #preserved + 1, "Duplicate whole-note bookmark was not removed")
for i, item in ipairs(preserved) do
  assert(vim.deep_equal(after.items[i], item), "An unrelated or heading bookmark was changed")
end
local group = after.items[#after.items]
assert(group.title == "Pinned reading" and group.items[1].title == "Nested", "Bookmark groups changed")
assert(
  #group.items[1].items == 1 and group.items[1].items[1].path == "keep me.md",
  "Nested toggle removed the wrong item"
)
toggle.callback()
assert(#read().items == #after.items + 1, "Heading bookmark prevented whole-note bookmarking")

-- Exercise the actual command without opening a picker UI.
local picker = require "obsidian.picker"
local old_select = picker.select
local presented
picker.select = function(items, opts)
  assert(opts.prompt == "Bookmarks")
  presented = items
end
vim.cmd "Obsidian bookmarks"
picker.select = old_select
assert(presented and vim.deep_equal(presented, read().items), "Search did not load the vault's bookmarks")

-- Broken bookmark data must be reported, never silently replaced.
local notify = vim.notify
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = message end
end
for _, broken in ipairs { "{not json", '{"items":{"unexpected":true}}', '{"items":[{"type":"group","items":false}]}' } do
  vim.fn.writefile({ broken }, file)
  toggle.callback()
  assert(table.concat(vim.fn.readfile(file), "\n") == broken, "Malformed bookmarks were overwritten")
end
vim.notify = notify
assert(#errors == 3, "Invalid bookmark data was not reported")
write(after)
assert(vim.deep_equal(original_note, vim.api.nvim_buf_get_lines(0, 0, -1, false)), "Bookmark toggle edited the note")
print "PASS: note bookmark toggle/search, grouped duplicates, heading preservation, and malformed-data safety"
