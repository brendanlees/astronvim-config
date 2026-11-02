vim.o.lines = 80
vim.o.columns = 120
local path = vim.env.HOME .. "/Notes/Obsidian/PKM/Rendering probe.md"
local fixture = {
  "Plain prose.",
  "",
  "# Heading one",
  "## Heading two",
  "Setext heading",
  "--------------",
  "",
  "| Name | Value |",
  "| ---- | ----- |",
  "| [[Query fixture book]] | ==Highlighted cell== |",
  "",
  "***",
  "",
  "> Ordinary quotation",
  "> Continued",
  "",
  "> [!NOTE] Callout title",
  "> Callout body",
  "",
  "> [!WARNING]",
  "> Watch out",
  "",
  "- Plain bullet",
  "- [ ] Existing checkbox",
  "[Link](https://example.com)",
  "[[Query fixture book]]",
  "==Existing highlight==",
  "`inline code`",
  "",
  "```lua",
  "local value = 1",
  "```",
  "",
  "```markdown",
  "# Heading inside code",
  "> [!NOTE] Not a callout",
  "| Nested | Table |",
  "| ------ | ----- |",
  "| no | renderer |",
  "```",
  "",
  "Inline answer: `= 20 + 22`",
  "",
  "```dataview",
  "LIST FROM #query-fixture",
  "```",
  "",
  "```dataviewjs",
  "dv.span('hidden')",
  "```",
  "",
  "Tail prose.",
}
vim.fn.writefile(fixture, path)
vim.cmd.edit(vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
local tick = vim.api.nvim_buf_get_changedtick(buf)
require("user.markdown.appearance").attach(buf)
local config = require("render-markdown.state").get(buf)
for _, name in ipairs { "heading", "dash", "quote", "pipe_table" } do
  assert(config[name].enabled, name .. " rendering was not enabled")
end
for _, name in ipairs {
  "bullet",
  "checkbox",
  "code",
  "document",
  "html",
  "indent",
  "inline_highlight",
  "latex",
  "link",
  "paragraph",
  "sign",
  "yaml",
} do
  assert(not config[name].enabled, name .. " rendering would overlap with existing behavior")
end
assert(not config.pipe_table.wrap, "Table replacements would hide Obsidian's cell decorations")

local ns = vim.api.nvim_get_namespaces()["render-markdown.nvim"]
local function marks() return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true }) end
local function row(text)
  for i, line in ipairs(fixture) do
    if line == text then return i - 1 end
  end
  error("Missing fixture line: " .. text)
end
local function styled(text, group)
  for _, mark in ipairs(marks()) do
    if mark[2] == row(text) and vim.inspect(mark[4]):find(group, 1, true) then return true end
  end
  return false
end
local function selected_styles()
  return styled("# Heading one", "RenderMarkdownH1")
    and styled("## Heading two", "RenderMarkdownH2")
    and styled("Setext heading", "RenderMarkdownH2")
    and styled("| Name | Value |", "RenderMarkdownTableHead")
    and styled("***", "RenderMarkdownDash")
    and styled("> Ordinary quotation", "RenderMarkdownQuote1")
    and styled("> [!NOTE] Callout title", config.callout.note.highlight)
    and styled("> [!WARNING]", config.callout.warning.highlight)
end
assert(vim.wait(3000, selected_styles), "Selected visuals did not render: " .. vim.inspect(marks()))
assert(vim.inspect(marks()):find("Callout title", 1, true), "Custom callout title was lost")

local excluded = {
  "- Plain bullet",
  "- [ ] Existing checkbox",
  "[Link](https://example.com)",
  "[[Query fixture book]]",
  "==Existing highlight==",
  "`inline code`",
  "```lua",
  "local value = 1",
  "# Heading inside code",
  "> [!NOTE] Not a callout",
  "| Nested | Table |",
}
for _, text in ipairs(excluded) do
  for _, mark in ipairs(marks()) do
    assert(mark[2] ~= row(text), "Renderer decorated an excluded element: " .. text)
  end
end
local obsidian_ns = vim.api.nvim_get_namespaces().ObsidianUI
local function obsidian_style(text, group)
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, obsidian_ns, 0, -1, { details = true })) do
    if mark[2] == row(text) and mark[4].hl_group == group then return true end
  end
  return false
end
local table_row = "| [[Query fixture book]] | ==Highlighted cell== |"
assert(
  vim.wait(
    2000,
    function()
      return obsidian_style("- [ ] Existing checkbox", "ObsidianTodo")
        and obsidian_style("[[Query fixture book]]", "ObsidianRefText")
        and obsidian_style("==Existing highlight==", "ObsidianHighlightText")
        and obsidian_style(table_row, "ObsidianRefText")
        and obsidian_style(table_row, "ObsidianHighlightText")
    end
  ),
  "Obsidian styling was lost, including links or highlights inside table cells"
)
local backgrounds = vim.api.nvim_get_namespaces().markdown_code_background
assert(#vim.api.nvim_buf_get_extmarks(buf, backgrounds, 0, -1, {}) == 4, "Existing code-block shading was lost")
assert(
  vim.wait(3000, function()
    local text = vim.inspect(marks())
    return text:find("Query fixture book", 1, true) and text:find('"42"', 1, true)
  end),
  "Markdown visuals replaced Dataview or inline query results"
)
print "PASS: headings, tables, rules, quotes, and callouts render without duplicating Obsidian or code styling"

local renderer = require "render-markdown.api"
renderer.buf_disable()
assert(vim.wait(2000, function() return #marks() == 0 end), "Rendering toggle left visual marks behind")
assert(obsidian_style("- [ ] Existing checkbox", "ObsidianTodo"))
renderer.buf_enable()
assert(vim.wait(3000, selected_styles), "Rendering toggle failed to restore selected visuals")
assert(vim.api.nvim_buf_get_changedtick(buf) == tick and not vim.bo.modified, "Visuals modified note text")
assert(vim.deep_equal(vim.fn.readfile(path), fixture), "Visuals changed the note file")
print "PASS: selected visuals toggle cleanly and leave note contents unchanged"
