vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
vim.o.swapfile = false
local appearance = require "user.markdown.appearance"
local inline = vim.treesitter.query.get("markdown_inline", "highlights")
local function captures(source)
  local root = vim.treesitter.get_string_parser(source, "markdown"):parse()[1]:root()
  local q = vim.treesitter.query.get("markdown", "highlights")
  local hidden, blocks, labels = 0, 0, 0
  for _, match, meta in q:iter_matches(root, source, 0, -1) do
    for id, nodes in pairs(match) do
      local attributes = meta[id] or {}
      if
        meta.conceal ~= nil
        or meta.conceal_lines ~= nil
        or attributes.conceal ~= nil
        or attributes.conceal_lines ~= nil
      then
        hidden = hidden + 1
      end
      if q.captures[id] == "markup.raw.block" then blocks = blocks + 1 end
      if q.captures[id] == "label" then labels = labels + 1 end
    end
  end
  return hidden, blocks, labels
end
local code = "```lua\nlocal answer = 42\n```\n"

vim.api.nvim_set_hl(0, "Normal", { bg = "#080808", fg = "#c6c6c6" })
vim.g.colors_name = "moonfly"
appearance.setup()
local bg = vim.api.nvim_get_hl(0, { name = "@markup.raw.block.markdown", link = false })
assert(bg.bg == 0x323437 and bg.fg == nil, vim.inspect(bg))
vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(code, "\n"))
vim.bo.filetype = "markdown"
vim.wo.conceallevel = 2
appearance.attach(0)
assert(vim.wo.conceallevel == 2)
for _, source in ipairs { code, "~~~python\nanswer = 42\n~~~\n", "```\nplain text\n```\n" } do
  local hidden, blocks, labels = captures(source)
  assert(hidden == 0 and blocks > 0, "Missing block highlight or lingering concealed fence")
end
local _, _, labels = captures(code)
assert(labels > 0, "Language label lost its highlighting")
assert(vim.treesitter.query.get("markdown_inline", "highlights") == inline, "Inline conceal query changed")
appearance.attach(0)
assert(captures(code) == 0, "Repeat attachment changed visibility")
local function shaded_rows()
  local ns = vim.api.nvim_get_namespaces().markdown_code_background
  assert(ns, "Full-width code-block background namespace is missing")
  local rows = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
    local details = mark[4]
    assert(mark[3] == 0 and details.end_col == 0 and details.hl_eol, "Background must fill each screen line")
    assert(details.hl_group == "@markup.raw.block.markdown" and details.priority < 100)
    for row = mark[2], details.end_row - 1 do
      rows[row + 1] = true
    end
  end
  return rows
end
assert(vim.deep_equal(shaded_rows(), { true, true, true }), "Fence rows must be fully shaded")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {
  "outside",
  "```lua",
  "local answer = 42",
  "",
  "print(answer)",
  "```",
  "outside again",
  "~~~",
  "plain",
  "~~~",
})
vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
assert(
  vim.deep_equal(shaded_rows(), {
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [8] = true,
    [9] = true,
    [10] = true,
  }),
  "Blank lines and closing fences should be shaded, but prose should not"
)
appearance.attach(0)
assert(#vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_get_namespaces().markdown_code_background, 0, -1, {}) == 2)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "plain text" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 })
assert(vim.tbl_isempty(shaded_rows()), "Deleted fences left stale background marks")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "```lua", "", "local answer = 42" })
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 })
assert(vim.deep_equal(shaded_rows(), { true, true, true }), "An unfinished block should shade through EOF")
vim.bo.filetype = "text"
vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
assert(vim.tbl_isempty(shaded_rows()), "Non-Markdown buffers should not retain code backgrounds")
vim.bo.filetype = "markdown"
appearance.attach(0)
vim.cmd.colorscheme "habamax"
local changed = vim.api.nvim_get_hl(0, { name = "@markup.raw.block.markdown", link = false })
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(changed.bg and changed.bg ~= normal.bg and changed.bg ~= bg.bg, vim.inspect(changed))
print "PASS: full-width code backgrounds cover blank lines and fences, follow edits, and survive theme changes; syntax colors and inline concealment preserved"
