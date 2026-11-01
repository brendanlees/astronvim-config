local api = require "obsidian.api"
local picker = require "obsidian.picker"
local periodic = require "user.obsidian.periodic"
local root = tostring(api.resolve_workspace_dir())
local original_folder = Obsidian.opts.daily_notes.folder
Obsidian.opts.daily_notes.folder = "periodic search fixtures"
local folder = root .. "/" .. Obsidian.opts.daily_notes.folder

local function fixture(relative, lines)
  local path = folder .. "/" .. relative
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile(lines or { "# " .. vim.fs.basename(path) }, path)
  return path
end
local expected = {
  daily = {
    fixture "2025/01/2025-01-10 -- Fri 10 January.md",
    fixture "2025/01/2025-01-9 -- Thu 9 January.md",
    fixture "2024/02/2024-02-29 -- Thu 29 February.md",
  },
  weekly = {
    fixture("2025/01/2025-01-13 - Week 03 ---.md", {
      "---", 'aliases: ["Week 3: planning", "Another alias", "Not displayed"]', "---", "# Weekly note",
    }),
    fixture "2025/01/2025-01-06 - Week 02 ---.md",
    fixture("2024/12/2024-12-30 - Week 01 ---.md", { "---", 'aliases: [""]', "---" }),
    fixture("2024/12/2024-12-23 - Week 52 ---.md", { "---", 'aliases: ["One alias"]', "---" }),
  },
  monthly = {
    fixture "2025/02/2025-02 --- February 2025 ---.md",
    fixture "2025/01/2025-01 --- January 2025 ---.md",
    fixture "2024/12/2024-12 --- December 2024 ---.md",
  },
}
-- Aliases must not change daily or monthly picker labels.
for _, kind in ipairs { "daily", "monthly" } do
  vim.fn.writefile({ "---", 'aliases: ["Do not use this label"]', "---" }, expected[kind][1])
end
fixture "2025/01/ordinary note.md"
fixture "2024/02/2024-02-30 -- Invalid date.md"
fixture "2025/13/2025-13 --- Invalid month ---.md"
fixture "2025/01/2025-01-01 -- Wed 1 January.txt"
vim.fn.writefile({ "Outside periodic folder" }, root .. "/2025-01-20 -- Mon 20 January.md")

local select, preview, open = picker.select, picker.preview_path, api.open_note
local presented, selected, opened, previewed
picker.select = function(items, opts, callback)
  presented = { items = items, opts = opts }
  selected = callback
end
picker.preview_path = function(path)
  previewed = path
  return { file = path }
end
api.open_note = function(path) opened = path end

for key, kind in pairs { d = "daily", w = "weekly", e = "monthly" } do
  local mapping = vim.fn.maparg(",." .. key, "n", false, true)
  assert(mapping.buffer == 1 and type(mapping.callback) == "function", "Missing periodic search mapping")
  mapping.callback()
  assert(presented.opts.prompt == "Search " .. kind .. " notes")
  local paths = {}
  for i, item in ipairs(presented.items) do
    paths[i] = item.path
    assert(item.kind == kind, "Picker mixed periodic note types")
    local weekly_labels = { [1] = "Week 3: planning - Another alias", [4] = "One alias" }
    local label = kind == "weekly" and weekly_labels[i] or vim.fs.basename(item.path):sub(1, -4)
    assert(presented.opts.format_item(item) == label, "Wrong picker label: " .. presented.opts.format_item(item))
  end
  assert(vim.deep_equal(paths, expected[kind]), "Filtering or date order is wrong: " .. vim.inspect(paths))
  presented.opts.preview_item(presented.items[1])
  assert(previewed == expected[kind][1], "Preview targeted the wrong note")
  opened = nil
  selected(nil)
  selected {}
  assert(opened == nil, "Cancelling the picker opened a note")
  selected { presented.items[2] }
  assert(opened == expected[kind][2], "Selected note was not opened")

  local current = vim.fn.maparg("," .. key, "n", false, true)
  assert(current.buffer == 1 and type(current.callback) == "function")
  local open_current, invoked = periodic.open_current
  periodic.open_current = function(value) invoked = value end
  current.callback()
  periodic.open_current = open_current
  assert(invoked == kind, "The current-period shortcut was replaced")
end

local cache = require "obsidian.cache"
assert(vim.wait(3000, cache.is_ready), "Metadata cache did not become ready")
local unreviewed_paths = {}
for _, kind in ipairs { "daily", "weekly", "monthly" } do
  local path = expected[kind][1]
  vim.fn.writefile({ "---", 'tags: ["_unreviewed"]', "---" }, path)
  cache.notes.refresh(path)
  unreviewed_paths[#unreviewed_paths + 1] = path
end
table.sort(unreviewed_paths)
local excluded = {
  fixture("2025/01/ordinary note.md", { "#_unreviewed" }),
  fixture("2024/02/2024-02-30 -- Invalid date.md", { "#_unreviewed" }),
  fixture("2025/01/2025-01-9 -- Thu 9 January.md", { "#_unreviewed/child" }),
  fixture("../2025-01-20 -- Mon 20 January.md", { "#_unreviewed" }),
  fixture("../periodic search fixtures-extra/2025-01-21 -- Tue 21 January.md", { "#_unreviewed" }),
}
for _, path in ipairs(excluded) do cache.notes.refresh(path) end
for _, path in ipairs { expected.weekly[2], expected.monthly[2] } do cache.notes.refresh(path) end

presented = nil
vim.fn.maparg(",.u", "n", false, true).callback()
assert(vim.wait(3000, function() return presented ~= nil end), "Unreviewed picker did not open")
assert(presented.opts.prompt == "Periodic notes: #_unreviewed")
local paths = {}
for _, item in ipairs(presented.items) do paths[#paths + 1] = item.path end
assert(vim.deep_equal(paths, unreviewed_paths), "Unreviewed filter returned wrong notes: " .. vim.inspect(paths))
presented.opts.preview_item(presented.items[1])
assert(previewed == unreviewed_paths[1], "Unreviewed preview targeted the wrong note")
selected { presented.items[1] }
assert(opened == unreviewed_paths[1], "Unreviewed selection opened the wrong note")

-- The restriction must not leak into the general names-and-aliases search.
presented = nil
require("user.obsidian.search").names()
assert(vim.wait(3000, function() return presented ~= nil end), "Names picker did not open")
local all_paths = {}
for _, item in ipairs(presented.items) do all_paths[item.path] = true end
for _, path in ipairs(excluded) do
  assert(all_paths[vim.fs.normalize(path)], "Names search lost a non-periodic or reviewed note")
end
print "PASS: unreviewed search includes only tagged periodic notes; other searches remain unrestricted"

local notify, message = vim.notify
vim.notify = function(value) message = value end
Obsidian.opts.daily_notes.folder = "missing periodic folder"
presented = nil
periodic.search "monthly"
assert(presented == nil and message == "No monthly notes found", "Empty search was not handled")
assert(vim.fn.isdirectory(root .. "/missing periodic folder") == 0, "Search created a folder")

picker.select, picker.preview_path, api.open_note = select, preview, open
vim.notify = notify
Obsidian.opts.daily_notes.folder = original_folder
print "PASS: periodic search bindings, weekly aliases and filename fallbacks, date ordering, filtering, previews, cancellation, and current-period shortcuts"
