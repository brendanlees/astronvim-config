vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/obsidian.nvim")
vim.g.maplocalleader = ","
vim.o.swapfile = false
vim.o.hidden = true
local highlights = require "user.obsidian.highlights"
highlights.setup()
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local function buffer(lines, row, col, ft)
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft or "markdown"
  vim.api.nvim_win_set_cursor(0, { row or 1, col or 0 })
  highlights.attach()
end
local function expect(expected)
  local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(vim.deep_equal(actual, expected), vim.inspect(actual))
end
buffer { "A whole line" }
feed ",hh"
expect { "==A whole line==" }
feed ",hh"
expect { "A whole line" }

for _, pair in ipairs {
  { "  indented prose  ", "  ==indented prose==  " },
  { "- a bullet", "- ==a bullet==" },
  { "12. numbered item", "12. ==numbered item==" },
  { "- [ ] an unchecked task", "- [ ] ==an unchecked task==" },
  { "- [x] a completed task", "- [x] ==a completed task==" },
  { "## A heading", "## ==A heading==" },
  { "> quoted text", "> ==quoted text==" },
  { "> - quoted bullet", "> - ==quoted bullet==" },
  { "==one== and ==two==", "==one and two==" },
} do
  buffer { pair[1] }
  feed ",hh"
  expect { pair[2] }
  feed ",hh"
  expect { (pair[2]:gsub("==", "")) }
end

buffer({ "some words here" }, 1, 6)
feed ",h"
expect { "some ==words== here" }
vim.api.nvim_win_set_cursor(0, { 1, 9 })
feed ",h"
expect { "some words here" }
buffer({ "an ==existing passage== here" }, 1, 13)
feed ",h"
expect { "an existing passage here" }
buffer({ "café naïve" }, 1, 7)
feed ",h"
expect { "café ==naïve==" }

buffer { "one two three" }
feed "0wvaw,h"
expect { "one ==two== three" }
buffer { "one two three" }
feed "0wveo,h"
expect { "one ==two== three" }
buffer { "café is good" }
feed "0ve,h"
expect { "==café== is good" }
buffer { "one two" }
vim.o.selection = "exclusive"
feed "0v3l,h"
expect { "==one== two" }
vim.o.selection = "inclusive"

buffer { "- first item", "", "second line" }
feed "V2j,h"
expect { "- ==first item==", "", "==second line==" }
feed "u"
expect { "- first item", "", "second line" }
buffer { "first line", "second line" }
feed "0wvj0e,h"
expect { "first ==line==", "==second== line" }

buffer { "---", "title: protected", "---", "```lua", "local value = 1", "```", "plain text" }
for _, row in ipairs { 1, 2, 3, 4, 5, 6 } do
  vim.api.nvim_win_set_cursor(0, { row, 0 })
  feed ",hh"
end
expect { "---", "title: protected", "---", "```lua", "local value = 1", "```", "plain text" }
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed "V6j,h"
expect { "---", "title: protected", "---", "```lua", "local value = 1", "```", "==plain text==" }
buffer { "", "   ", "- " }
feed "V2j,h"
expect { "", "   ", "- " }
for _, code in ipairs {
  "    indented code",
  "text with `inline code`",
  "<!-- hidden comment -->",
  "%% hidden comment %%",
} do
  buffer { code }
  feed ",hh"
  expect { code }
end
buffer({ "text `inline code` here" }, 1, 7)
feed ",h"
expect { "text `inline code` here" }
buffer({ "local value = 1" }, 1, 0, "lua")
feed ",hh"
expect { "local value = 1" }

buffer { "read-only text" }
vim.bo.readonly = true
feed ",hh"
expect { "read-only text" }
vim.bo.readonly = false
vim.bo.modifiable = false
feed ",hh"
expect { "read-only text" }
vim.bo.modifiable = true

local function style()
  local hl = vim.api.nvim_get_hl(0, { name = "ObsidianHighlightText", link = false })
  assert(hl.fg == 0xffffff and hl.bg == 0x806600, vim.inspect(hl))
end
style()
vim.cmd.colorscheme "habamax"
style()
print "PASS: line/word/selection highlights, Unicode, Markdown prefixes, undo, syntax exclusions, and theme-stable colours"
