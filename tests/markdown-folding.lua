vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
for _, name in ipairs { "astrocore", "astroui", "nvim-treesitter", "bullets.nvim" } do
  vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/" .. name)
end
vim.opt.rtp:append(vim.env.NVIM_TEST_PLUGINS .. "/nvim-treesitter/runtime")
vim.o.swapfile = false
vim.o.hidden = true
vim.cmd "filetype plugin on"
require("nvim-treesitter").setup { install_dir = vim.env.NVIM_TEST_SITE }
require("astrocore.treesitter").installed(true)

local astro = dofile(vim.env.NVIM_TEST_PLUGINS .. "/AstroNvim/lua/astronvim/plugins/_astroui.lua")
require("astroui").config.folding = astro.opts.folding
local core_opts = astro.specs[1].opts
for option, value in pairs(core_opts.options.opt) do
  vim.opt[option] = value
end
local persistent = core_opts.autocmds.persistent_astroui_foldexpr[1]
vim.api.nvim_create_autocmd(persistent.event, { callback = persistent.callback })
-- Exercise the actual plugin startup hook, without activating unrelated language servers.
local otter = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/otter.lua")
otter.init()
require("bullets").setup(dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/bullets.lua").opts)
vim.api.nvim_clear_autocmds { group = "markdown_otter" }

local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local function buffer(lines, ft)
  vim.cmd.enew()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft or "markdown"
  require("astrocore.treesitter").enable(vim.api.nvim_get_current_buf())
  vim.cmd "normal! zx"
  vim.cmd "normal! zR"
  return vim.api.nvim_get_current_buf()
end
local function row(text)
  for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == text then return i end
  end
  error("Missing fixture line: " .. text)
end
local function closed(text) return vim.fn.foldclosed(row(text)) ~= -1 end
local function cursor(text) vim.api.nvim_win_set_cursor(0, { row(text), 0 }) end
local function all_open()
  for line = 1, vim.api.nvim_buf_line_count(0) do
    assert(vim.fn.foldclosed(line) == -1, "Unexpected closed fold at " .. line)
  end
end

local fixture = {
  "---",
  "description: |",
  "  ## YAML example",
  "---",
  "",
  "# Title",
  "intro",
  "",
  "## Alpha",
  "alpha body",
  "",
  "### Nested",
  "nested body",
  "",
  "#### Deep",
  "deep body",
  "",
  "##### Deeper",
  "deeper body",
  "",
  "###### Last",
  "last body",
  "",
  "## Beta",
  "beta body",
  "",
  "# Second title",
  "second body",
}
local note = buffer(fixture)
assert(vim.wo.foldexpr == core_opts.options.opt.foldexpr, "AstroNvim's fold provider was replaced")
assert(vim.wo.foldmethod == "expr" and vim.wo.foldtext == "" and vim.wo.foldenable)
for _, key in ipairs { "zj", "zk", "zl", "z;", "zu", "zi", "<CR>" } do
  assert(vim.fn.maparg(key, "n", false, true).buffer == 1, key .. " is not buffer-local")
end
local tick = vim.api.nvim_buf_get_changedtick(0)
cursor "# Title"
feed "zj"
assert(
  closed "# Title" and closed "# Second title",
  vim.inspect {
    first = vim.fn.foldclosed(row "# Title"),
    second = vim.fn.foldclosed(row "# Second title"),
    level = vim.fn.foldlevel(row "# Title"),
    expr = vim.wo.foldexpr,
    error = vim.v.errmsg,
    enabled = require("astrocore.treesitter").is_enabled(),
    parser = require("astrocore.treesitter").has_parser("markdown", "folds"),
    calculated = require("astroui.folding").foldexpr(row "# Title"),
  }
)
feed "zk"
assert(not closed "# Title" and not closed "# Second title")
assert(closed "## Alpha" and closed "## Beta")
assert(vim.fn.foldclosed(row "### Nested") == row "## Alpha", "A child fold closed its parent instead")
feed "zl"
assert(not closed "## Alpha" and not closed "## Beta")
assert(closed "### Nested" and closed "#### Deep")
feed "z;"
assert(not closed "### Nested" and closed "#### Deep" and closed "###### Last")
assert(vim.api.nvim_buf_get_changedtick(0) == tick, "Folding changed note text")
print "PASS: zj/zk/zl/z; fold real headings at levels 1–4 and deeper, without replacing AstroNvim folding"

feed "zu"
all_open()
feed "zu"
assert(closed "# Title" and closed "# Second title")
feed "zu"
all_open()
cursor "## Alpha"
feed "<CR>"
assert(closed "## Alpha" and not closed "## Beta")
feed "zu"
all_open()
cursor "## Beta"
feed "<CR>"
assert(closed "## Beta")
feed "<CR>"
assert(not closed "## Beta")
cursor "nested body"
feed "zi"
assert(closed "### Nested" and not closed "## Alpha")
assert(vim.fn.line "." == row "### Nested")
feed "zi"
assert(not closed "### Nested")
vim.wo.foldenable = false
feed "zu"
assert(vim.wo.foldenable and closed "# Title")
feed "zu"
all_open()
print "PASS: zu uses actual fold state, including partial folds; normal Enter and zi toggle individual sections"

buffer { "## First", "body", "", "#### Skipped", "deep", "", "## Second", "body" }
feed "zk"
assert(closed "## First" and closed "## Second")
feed "zl"
assert(not closed "## First" and closed "#### Skipped" and not closed "## Second")
feed "z;"
assert(not closed "## First" and closed "#### Skipped")
print "PASS: heading levels work without a level-1 title and with skipped levels"

buffer { "# Parent", "intro", "", "## Empty", "## Filled", "body" }
feed "zk"
assert(not closed "# Parent" and closed "## Filled", "An empty heading collapsed its parent")
cursor "## Empty"
feed "zi"
assert(not closed "# Parent" and closed "## Filled", "zi on an empty heading collapsed its parent")
print "PASS: empty adjacent headings do not close their parent"

buffer {
  "---",
  "description: |",
  "  ## Fake YAML",
  "---",
  "",
  "# Title",
  "",
  "```markdown",
  "## Fake code",
  "example",
  "```",
  "",
  "~~~markdown",
  "## Fake tilde code",
  "example",
  "~~~",
  "",
  "> ## Fake quote",
  "> text",
  "",
  "- item",
  "  ## Fake list",
  "  text",
  "",
  "## Real",
  "body",
}
feed "zk"
assert(closed "## Real" and not closed "# Title")
for _, text in ipairs { "  ## Fake YAML", "## Fake code", "## Fake tilde code", "> ## Fake quote", "  ## Fake list" } do
  assert(not closed(text), "Non-heading was folded: " .. text)
end
cursor "## Fake code"
feed "zi"
assert(closed "# Title", "zi treated code-block hashes as a heading")
print "PASS: YAML, code fences, blockquotes, and list contents are not mistaken for note headings"

buffer { "# Tasks", "", "- [ ] todo", "", "## Other", "body" }
vim.api.nvim_win_set_cursor(0, { 3, 7 })
for _, state in ipairs { "~", "!", ">", "x", " " } do
  feed "<CR>"
  assert(vim.api.nvim_get_current_line() == "- [" .. state .. "] todo", "Enter did not cycle checkbox states")
  assert(vim.fn.foldclosed(1) == -1 and vim.fn.foldclosed(5) == -1, "Checkbox Enter folded a heading")
  assert(vim.api.nvim_win_get_cursor(0)[2] == 7, "Checkbox cycling moved the cursor")
end
vim.api.nvim_win_set_cursor(0, { 1, 0 })
feed "<CR>"
assert(vim.fn.foldclosed(1) == 1, "Heading Enter stopped folding")
feed "<CR>"
assert(vim.fn.foldclosed(1) == -1)

for _, fixture in ipairs {
  { lines = { "# Heading", "ordinary prose", "", "- ordinary list" }, row = 2 },
  { lines = { "# Heading", "ordinary prose", "", "- ordinary list" }, row = 4 },
  { lines = { "```markdown", "- [ ] code", "```" }, row = 2 },
  { lines = { "---", "tasks:", "  - [ ] yaml", "---" }, row = 3 },
} do
  buffer(fixture.lines)
  vim.api.nvim_win_set_cursor(0, { fixture.row, 0 })
  feed "<CR>"
  assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), fixture.lines), "Enter changed prose/code/YAML")
  assert(vim.fn.foldclosed(1) == -1, "Enter folded a containing section instead of the heading under the cursor")
end
print "PASS: Enter cycles checkbox states without folding; only real headings fold; prose/code/YAML stay unchanged"

buffer { "plain prose", "another line" }
local before = vim.api.nvim_win_get_cursor(0)
feed "<CR>"
feed "zi"
feed "zu"
feed "zu"
assert(vim.deep_equal(before, vim.api.nvim_win_get_cursor(0)))
print "PASS: notes with no folds remain unchanged"

vim.api.nvim_set_current_buf(note)
vim.cmd "normal! zR"
local original_win = vim.api.nvim_get_current_win()
vim.cmd.split()
local split_win = vim.api.nvim_get_current_win()
feed "zu"
assert(closed "# Title")
vim.api.nvim_win_call(original_win, function() assert(not closed "# Title", "Toggle changed another window") end)
feed "zu"
all_open()
vim.api.nvim_win_close(split_win, true)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(note, 0, -1, false), fixture))

buffer({ "local value = 1", "print(value)" }, "lua")
for _, key in ipairs { "zj", "zk", "zl", "z;", "zu", "zi", "<CR>" } do
  assert(vim.fn.maparg(key, "n") == "", key .. " leaked into source files")
end
local preview = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(preview)
vim.bo.filetype = "markdown"
assert(vim.fn.maparg("zu", "n") == "", "Preview buffer received folding bindings")
print "PASS: folding is window-local, preserves note text, and does not override source-file or preview mappings"
