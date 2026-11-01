vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
vim.o.swapfile = false
local appearance = require "markdown_appearance"
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
vim.cmd.colorscheme "habamax"
local changed = vim.api.nvim_get_hl(0, { name = "@markup.raw.block.markdown", link = false })
local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
assert(changed.bg and changed.bg ~= normal.bg and changed.bg ~= bg.bg, vim.inspect(changed))
print "PASS: backtick/tilde fences and language labels visible; block backgrounds survive theme changes; injected foregrounds, inline queries and conceallevel preserved"
