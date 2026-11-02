local Note = require "obsidian.note"
local metadata = require "user.obsidian.metadata"
local root = tostring(require("obsidian.api").resolve_workspace_dir())
local original_time = os.time
local clock = 1893456000 -- 2030-01-01 00:00:00 UTC, independent of the local timezone.
os.time = function(value)
  if value then return original_time(value) end
  return clock
end

local function open(relative, lines)
  local path = root .. "/" .. relative
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if lines then vim.fn.writefile(lines, path) end
  vim.cmd.edit(vim.fn.fnameescape(path))
  if not relative:match "^system/templates/nvim/" then
    assert(vim.b.obsidian_buffer, "fixture was not attached to Obsidian: " .. relative)
  end
  if lines then assert(vim.deep_equal(lines, vim.fn.readfile(path)), "opening a note changed it") end
  return path
end

local function read(path) return Note.from_file(path).metadata end
local function body_edit(text)
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { text })
  vim.cmd.write()
end

local ok, err = xpcall(function()
  local path = open("metadata fixtures/existing.md", {
    "---",
    "zebra: keep",
    "type: permanent",
    "id: stable-custom-id",
    'aliases: ["Older title", "Actual heading", "Older title", "existing"]',
    'tags: ["zeta", "#alpha", "alpha"]',
    "links:",
    '  - "[[Z]]"',
    '  - "[[A]]"',
    "created: 2018-03-04 05:06:07",
    "modified: 2020-01-01 00:00:00",
    "date: 2017-01-02",
    "status: open",
    "custom:",
    "  enabled: true",
    "  count: 2",
    "alpha: keep too",
    "---",
    "```markdown",
    "# Not a heading",
    "```",
    "<!--",
    "# Also not a heading",
    "-->",
    "# Actual heading",
    "# Later heading",
    "Original body",
  })
  body_edit "Edited body"
  local data = read(path)
  assert(data.id == "stable-custom-id", "existing ID changed")
  assert(data.created == "2018-03-04 05:06:07", "creation date changed")
  assert(data.modified == "2030-01-01 00:00:00", "edited note did not receive a UTC timestamp")
  assert(vim.deep_equal(data.aliases, { "Actual heading", "Older title" }), "heading is not the first unique alias")
  assert(vim.deep_equal(data.tags, { "alpha", "zeta" }), "tags were not normalised")
  assert(vim.deep_equal(data.links, { "[[Z]]", "[[A]]" }), "unrelated array changed: " .. vim.inspect(data.links))
  assert(data.date == "2017-01-02", "semantic date changed")
  assert(vim.deep_equal(data.custom, { enabled = true, count = 2 }), "custom properties changed")

  local keys = {}
  local saved = vim.fn.readfile(path)
  for i = 2, #saved do
    if saved[i] == "---" then break end
    local key = saved[i]:match "^([%w_-]+):"
    if key then keys[#keys + 1] = key end
  end
  assert(
    vim.deep_equal(keys, {
      "id",
      "type",
      "aliases",
      "links",
      "tags",
      "created",
      "modified",
      "date",
      "status",
      "alpha",
      "custom",
      "zebra",
    }),
    "wrong property order: " .. vim.inspect(keys)
  )

  clock = clock + 60
  vim.cmd.write()
  assert(vim.deep_equal(saved, vim.fn.readfile(path)), "unchanged save rewrote metadata")
  vim.bo.modified = true
  vim.cmd.write()
  assert(vim.deep_equal(saved, vim.fn.readfile(path)), "dirty-but-identical save advanced modified")

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(lines) do
    if line == "# Actual heading" then lines[i] = "# Renamed heading" end
  end
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  -- Exercise the existing autosave path, not just :write.
  vim.api.nvim_exec_autocmds("FocusLost", { buffer = 0 })
  data = read(path)
  assert(data.modified == "2030-01-01 00:01:00", "autosave missed metadata updates")
  assert(
    vim.deep_equal(data.aliases, { "Renamed heading", "Actual heading", "Older title" }),
    "renaming a heading lost existing aliases"
  )

  path = open "metadata fixtures/new.md"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# A new note" })
  vim.cmd.write()
  data = read(path)
  assert(data.id == "new", "filename-derived ID missing")
  assert(data.created == "2030-01-01 00:01:00" and data.modified == data.created, "new-note dates missing")
  assert(vim.deep_equal(data.aliases, { "A new note" }))

  path = open("metadata fixtures/placeholders.md", {
    "---",
    "created:",
    'modified: ""',
    "aliases:",
    "tags:",
    "---",
    "# placeholders",
  })
  local stat = assert(vim.uv.fs_stat(path))
  local birth = stat.birthtime.sec > 0 and stat.birthtime.sec or stat.mtime.sec
  vim.cmd.write()
  data = read(path)
  assert(data.created == os.date("!%Y-%m-%d %H:%M:%S", birth), "missing creation date was not backfilled")
  assert(data.modified == os.date("!%Y-%m-%d %H:%M:%S", stat.mtime.sec), "missing modified date ignored disk time")
  assert(vim.deep_equal(data.aliases, {}), "filename-equivalent alias was retained")

  path = open("metadata fixtures/setext.md", { "Setext title", "============", "", "# Later" })
  vim.cmd.write()
  assert(vim.deep_equal(read(path).aliases, { "Setext title" }), "setext H1 was missed")
  path = open("metadata fixtures/no-heading.md", { "## Not an H1", "Body" })
  vim.cmd.write()
  assert(vim.deep_equal(read(path).aliases, {}), "invented an alias without an H1")

  for _, folder in ipairs { "system", "system/templates/nvim", "archive", "agents/hermes", "agents/hermes-artifacts" } do
    local original = { "---", "aliases: [untouched]", "---", "# Excluded note", "Edited body" }
    path = open(folder .. "/metadata-excluded.md", original)
    vim.bo.modified = true
    vim.cmd.write()
    assert(vim.deep_equal(vim.fn.readfile(path), original), "excluded folder rewritten: " .. folder)
  end
  path = open("agents/hermes-extra/included.md", { "# Included" })
  vim.cmd.write()
  assert(read(path).created, "folder prefix incorrectly excluded a sibling")

  local risky = { "---", 'links: ["[[Z]]", "[[A]]"]', "---", "# Inline wikilinks" }
  path = open("metadata fixtures/inline-wikilinks.md", risky)
  vim.cmd.write()
  assert(vim.deep_equal(vim.fn.readfile(path), risky), "inline wikilink list was silently converted to a string")

  local malformed = { "---", 'aliases: ["unterminated', "---", "# Invalid YAML" }
  path = open("metadata fixtures/invalid.md", malformed)
  vim.cmd.write()
  assert(vim.deep_equal(vim.fn.readfile(path), malformed), "invalid YAML was replaced")
  local unclosed = { "---", "type: permanent", "# Unclosed YAML" }
  path = open("metadata fixtures/unclosed.md", unclosed)
  vim.cmd.write()
  assert(vim.deep_equal(vim.fn.readfile(path), unclosed), "unclosed YAML gained a duplicate frontmatter block")

  -- Note creation also goes through the custom writer, before a buffer exists.
  local created = Note.create {
    id = "metadata-created",
    title = "Created via plugin",
    dir = root .. "/metadata fixtures",
    verbatim = true,
  }
  created:write()
  data = read(tostring(created.path))
  assert(data.id == "metadata-created" and data.created and data.modified, "plugin creation missed metadata")

  -- Unavailable birth times fall back to mtime, not ctime (which is not creation time).
  local fallback_note = Note.from_lines({ "# Fallback" }, root .. "/fallback.md")
  local real_stat = vim.uv.fs_stat
  vim.uv.fs_stat = function() return { birthtime = { sec = 0 }, mtime = { sec = 946684800 } } end
  local fallback_ok, fallback = pcall(metadata.frontmatter, fallback_note)
  vim.uv.fs_stat = real_stat
  assert(fallback_ok, fallback)
  assert(
    fallback.created == "2000-01-01 00:00:00" and fallback.modified == fallback.created,
    "filesystem fallback used the wrong date"
  )
end, debug.traceback)
os.time = original_time
assert(ok, err)
print "PASS: metadata timestamps, stable IDs, aliases, property order, exclusions, and autosave"
