local vault = assert(vim.uv.fs_realpath(vim.env.HOME .. "/Notes/Obsidian/PKM"))
local cache = require "obsidian.cache"
assert(vim.wait(5000, cache.is_ready), "Obsidian cache did not become ready")
local book = vault .. "/Query fixture book.md"
vim.fn.writefile({
  "---",
  "tags: [query-fixture]",
  "rating: 5",
  "---",
  "# Query fixture book",
  "- [ ] Read the query fixture",
}, book)
cache.notes.refresh(book)

local path = vault .. "/Query probe.md"
local fixture = {
  "# Queries",
  "Before the queries.",
  "",
  "```dataview",
  "TABLE rating FROM #query-fixture",
  "```",
  "",
  "Inline answer: `= 20 + 22`",
  "",
  "```dataviewjs",
  'dv.paragraph("Hidden JavaScript");',
  "```",
  "After JavaScript.",
  "",
  "~~~dataviewjs",
  'dv.paragraph("Hidden tilde block");',
  "~~~",
  "",
  "```lua",
  "print('ordinary code')",
  "```",
  "",
  "````markdown",
  "```dataviewjs",
  "This is an example, not an executable block.",
  "```",
  "````",
  "",
  "```dataviewjsx",
  "This language must stay visible.",
  "```",
  "",
  "After all blocks.",
  "- [ ] Render this checkbox",
  "[[Query fixture book]]",
  "==Render this highlight==",
}
vim.fn.writefile(fixture, path)
cache.notes.refresh(path)
vim.cmd.edit(vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
local tick = vim.api.nvim_buf_get_changedtick(buf)
local function note_ui()
  local ns = vim.api.nvim_get_namespaces().ObsidianUI
  local groups = {}
  if ns then
    for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
      groups[mark[4].hl_group or ""] = true
    end
  end
  return groups
end
assert(
  vim.wait(2000, function()
    local groups = note_ui()
    return groups.ObsidianTodo and groups.ObsidianRefText and groups.ObsidianHighlightText
  end),
  "Opening a note did not automatically render checkboxes, links, and highlights: " .. vim.inspect(note_ui())
)
require("user.markdown.appearance").attach(buf)
local helpers = require "user.obsidian.queries"
local opts = helpers.render_options()
assert(not opts.ignore(buf), "Vault note was excluded from query rendering")
assert(opts.custom_handlers.markdown.extends and opts.custom_handlers.markdown_inline.extends)
print "PASS: Obsidian checkboxes, links, and highlights render alongside Markdown and query visuals"

local renderer = require "render-markdown.api"
local ns = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
local function marks() return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }) end
local source_ns = vim.api.nvim_get_namespaces().obsidian_query_source
local function source_marks() return vim.api.nvim_buf_get_extmarks(buf, source_ns, 0, -1, { details = true }) end
local function hidden_blocks()
  local blocks = {}
  for _, mark in ipairs(source_marks()) do
    if mark[4].conceal_lines ~= nil then blocks[#blocks + 1] = { mark[2], mark[4].end_row + 1 } end
  end
  return blocks
end
local function at(row)
  for _, block in ipairs(hidden_blocks()) do
    if block[1] == row then return true end
  end
  return false
end
local function move(row)
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf })
end
move(1)
assert(
  vim.wait(5000, function()
    local text = vim.inspect(marks())
    return at(3) and at(9) and at(14) and text:find("Query fixture book", 1, true) and text:find('"42"', 1, true)
  end),
  "Query results, inline values, or DataviewJS concealment were not rendered: " .. vim.inspect(marks())
)
assert(#vim.diagnostic.get(buf, { namespace = vim.api.nvim_get_namespaces()["obsidian-query"] }) == 0)
assert(vim.wo.conceallevel == 2, "Renderer changed the existing conceal level")
assert(vim.deep_equal(hidden_blocks(), { { 3, 5 }, { 9, 12 }, { 14, 17 } }), vim.inspect(hidden_blocks()))
vim.cmd.redraw()
assert(
  vim.api.nvim_win_text_height(0, { start_row = 12, end_row = 12 }).all == 1,
  "JavaScript concealed the following prose"
)
assert(
  vim.api.nvim_win_text_height(0, { start_row = 3, end_row = 4 }).all == 0,
  "Collapsed query source still takes up screen lines"
)
for _, row in ipairs { 4, 5, 6 } do
  move(row)
  assert(vim.wait(2000, function() return not at(3) end), "Entering a query did not reveal all its source")
  assert(vim.inspect(marks()):find("Query fixture book", 1, true), "Revealing source removed its results")
  move(1)
  assert(vim.wait(2000, function() return at(3) end), "Leaving a query did not collapse it again")
end
move(11)
assert(vim.wait(2000, function() return not at(9) and at(14) end), "Cursor did not reveal the full JavaScript block")
move(13)
assert(
  vim.wait(2000, function() return at(9) and at(14) end),
  "Leaving JavaScript did not hide it again: " .. vim.inspect(marks())
)
renderer.buf_disable()
assert(
  vim.wait(2000, function() return #marks() == 0 and #source_marks() == 0 end),
  "Disabling rendering did not reveal raw queries"
)
renderer.buf_enable()
assert(
  vim.wait(3000, function() return at(3) and at(9) and at(14) end),
  "Re-enabling rendering did not hide query source"
)
assert(vim.api.nvim_buf_get_changedtick(buf) == tick and not vim.bo.modified, "Rendering modified the buffer")
assert(vim.deep_equal(vim.fn.readfile(path), fixture), "Rendering modified the file")
assert(note_ui().ObsidianTodo and note_ui().ObsidianRefText and note_ui().ObsidianHighlightText)
print "PASS: query source collapses to a label, results stay visible, cursor entry reveals source, and toggling preserves note styling and text"

local engine = require "obsidian-query.dataview"
for _, query in ipairs {
  "LIST FROM #query-fixture",
  "TASK FROM #query-fixture WHERE !completed",
  "CALENDAR file.mtime FROM #query-fixture",
} do
  local result
  engine.run(engine.parse(query), { root = vault, buf = buf }, function(value) result = value end)
  assert(vim.wait(5000, function() return result ~= nil end), "Query timed out: " .. query)
  assert(result.ok ~= false and not result.error, vim.inspect(result))
  assert(#engine.lines(result) > 0, "Query produced no display lines: " .. query)
end
print "PASS: LIST, TASK, and CALENDAR queries execute against the installed Obsidian cache"

-- Check dispatch without opening an interactive picker in a headless test.
local query = require "obsidian-query"
local folding = require "user.markdown.folding"
local old_picker, old_fold = query.open_picker, folding.toggle_fold
local picked, folded = 0, 0
query.open_picker = function() picked = picked + 1 end
folding.toggle_fold = function() folded = folded + 1 end
local enter = vim.fn.maparg("<CR>", "n", false, true)
assert(enter.desc == "Query results / toggle fold")
move(6) -- The collapsed Dataview summary sits on the closing fence.
enter.callback()
move(2)
enter.callback()
assert(picked == 1 and folded == 1, "Enter did not preserve query and fold actions")
query.open_picker, folding.toggle_fold = old_picker, old_fold

-- UI updates must come from normal editor events, not explicit obsidian.ui.update calls.
for row, line in ipairs(fixture) do
  if line == "- [ ] Render this checkbox" then
    vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { "- [x] Render this checkbox" })
  end
end
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
assert(
  vim.wait(2000, function()
    local groups = note_ui()
    return groups.ObsidianDone and not groups.ObsidianTodo and groups.ObsidianRefText and groups.ObsidianHighlightText
  end),
  "Checkbox rendering did not automatically follow an edit"
)

-- Edits and language changes must not leave stale hiding marks.
vim.api.nvim_buf_set_lines(buf, 9, 10, false, { "```javascript" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
move(1)
assert(vim.wait(3000, function() return not at(9) and at(14) end), "Changing a fence left stale concealment")
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "No code blocks remain." })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
renderer.render { buf = buf }
assert(
  vim.wait(
    3000,
    function()
      return #marks() == 0 and #source_marks() == 0 and not require("render-markdown.core.ui").get(buf):changed()
    end
  ),
  "Deleting queries left stale renderer marks"
)
-- Results need a visible anchor even when the next block is hidden or the query ends the note.
for _, case in ipairs {
  {
    lines = { "# EOF", "```dataview", "LIST FROM #query-fixture", "```" },
    results = 1,
  },
  {
    lines = {
      "# Adjacent",
      "```dataview",
      "LIST FROM #query-fixture",
      "```",
      "```dataview",
      "TABLE rating FROM #query-fixture",
      "```",
      "```dataviewjs",
      'dv.paragraph("hidden");',
      "```",
    },
    results = 2,
  },
} do
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, case.lines)
  vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
  move(1)
  local function result_rows()
    if require("render-markdown.core.ui").get(buf):changed() then return 0, 0 end
    local blocks, rows = 0, 0
    for _, mark in ipairs(marks()) do
      local lines = mark[4].virt_lines
      if lines and vim.inspect(lines):find("Query fixture book", 1, true) then
        blocks, rows = blocks + 1, rows + #lines
        assert(case.lines[mark[2] + 1] == "```" and mark[4].virt_lines_above)
        for _, hidden in ipairs(hidden_blocks()) do
          assert(mark[2] < hidden[1] or mark[2] >= hidden[2], "Results were anchored on hidden source")
        end
      end
    end
    return blocks, rows
  end
  assert(
    vim.wait(5000, function() return result_rows() == case.results end),
    "Adjacent/EOF results did not render: "
      .. vim.inspect {
        lines = case.lines,
        marks = marks(),
        source = source_marks(),
        diagnostics = vim.diagnostic.get(buf),
        cursor = vim.api.nvim_win_get_cursor(0),
      }
  )
  local _, expected_rows = result_rows()
  -- Count query rows only; Obsidian also decorates the last source line with a footer.
  local footer_ns = vim.api.nvim_get_namespaces()["obsidian.footer"]
  vim.api.nvim_buf_clear_namespace(buf, footer_ns, 0, -1)
  vim.cmd.redraw()
  local rendered_fill = vim.api.nvim_win_text_height(0, {}).fill
  renderer.buf_disable()
  assert(vim.wait(2000, function() return #marks() == 0 and #source_marks() == 0 end))
  vim.api.nvim_buf_clear_namespace(buf, footer_ns, 0, -1)
  vim.cmd.redraw()
  local plain_fill = vim.api.nvim_win_text_height(0, {}).fill
  assert(
    rendered_fill - plain_fill == expected_rows,
    "Hidden source swallowed query result rows: "
      .. vim.inspect { fixture = case.lines, rendered = rendered_fill, plain = plain_fill, expected = expected_rows }
  )
  renderer.buf_enable()
  assert(vim.wait(3000, function() return result_rows() == case.results end))
end
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "# Incomplete", "```dataview", "LIST FROM #query-fixture" })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
move(1)
assert(vim.wait(3000, function() return #source_marks() == 0 end), "An incomplete query was collapsed")
vim.bo.modified = false
print "PASS: UI follows edits, adjacent and EOF queries keep every result line, and incomplete queries stay visible"

local outside = vim.env.HOME .. "/outside.md"
vim.fn.writefile({ "# Outside", "```dataviewjs", "keep visible", "```" }, outside)
vim.cmd.edit(vim.fn.fnameescape(outside))
assert(opts.ignore(vim.api.nvim_get_current_buf()), "Non-vault Markdown was included")
assert(not require("render-markdown.core.manager").attached(vim.api.nvim_get_current_buf()))
assert(vim.fn.maparg("<CR>", "n", false, true).desc == "Toggle fold under cursor")
local preview = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(preview, vault .. "/preview.md")
assert(opts.ignore(preview), "Preview buffers were included")
print "PASS: Enter preserves folding, edits clear stale marks, and rendering stays scoped to vault notes"
