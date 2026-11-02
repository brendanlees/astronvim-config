-- Exercise the real creation path, not only shortcut dispatch.
local api = require "obsidian.api"
local periodic = require "user.obsidian.periodic"
local root = tostring(api.resolve_workspace_dir())
local original_folder = Obsidian.opts.daily_notes.folder
Obsidian.opts.daily_notes.folder = "periodic creation fixtures"
local templates = tostring(api.templates_dir())

for _, kind in ipairs { "monthly", "weekly" } do
  vim.fn.writefile({
    "---",
    "type: " .. kind,
    'date: "{{period:YYYY-MM-DD}}"',
    'aliases: ["{{period:MMMM YYYY}}"]',
    "tags: [_unreviewed]",
    "---",
    "# {{period:MMMM YYYY ([Month] MM [of 12])}}",
    "",
    "## Allocate / Action",
    "",
    'FROM "__notes/daily"',
    "WHERE date >= date({{period:YYYY-MM-DD}})",
    "",
    "## Review",
  }, templates .. "/" .. kind .. ".md")
end
for key, kind in pairs { e = "monthly", w = "weekly" } do
  vim.fn.maparg("," .. key, "n", false, true).callback()
  local path = vim.api.nvim_buf_get_name(0)
  assert(path:find("/periodic creation fixtures/", 1, true), "Wrong periodic folder: " .. path)
  local text = table.concat(vim.fn.readfile(path), "\n")
  assert(text:find("type: " .. kind, 1, true), kind .. " template frontmatter missing: " .. text)
  assert(text:find("## Allocate / Action", 1, true), kind .. " template body missing")
  assert(not text:find("{{", 1, true), kind .. " substitutions not expanded")
  local note_date = assert(text:match "date: (%d%d%d%d%-%d%d%-%d%d)", "Missing period date")
  assert(text:find("Month " .. note_date:sub(6, 7) .. " of 12", 1, true), "Heading substitution missing")
  assert(vim.tbl_contains(require("obsidian.note").from_file(path).tags, "_unreviewed"))
  if kind == "monthly" then assert(text:find(os.date "date: %Y-%m-01", 1, true), "Wrong monthly date: " .. text) end
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Keep my notes" })
  vim.cmd.write()
  local saved = vim.fn.readfile(path)
  periodic.open_current(kind)
  assert(vim.api.nvim_buf_get_name(0) == path)
  assert(vim.deep_equal(vim.fn.readfile(path), saved), "Reopening replaced existing content")
end
Obsidian.opts.daily_notes.folder = original_folder
print "PASS: weekly/monthly shortcuts apply templates, expand dates, and preserve existing notes"
