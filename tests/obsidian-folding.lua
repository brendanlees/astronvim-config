local plugins = vim.fs.dirname(vim.env.OBSIDIAN_TEST_PLUGIN)
vim.opt.rtp:append(vim.env.OBSIDIAN_TEST_SITE)
vim.opt.rtp:append(plugins .. "/astrocore")
vim.opt.rtp:append(plugins .. "/astroui")
local astro = dofile(plugins .. "/AstroNvim/lua/astronvim/plugins/_astroui.lua")
require("astroui").config.folding = astro.opts.folding

local path = vim.env.HOME .. "/Notes/Obsidian/PKM/folding probe.md"
vim.fn.writefile({
  "# Title",
  "intro",
  "",
  "## Alpha",
  "body",
  "",
  "### Nested",
  "nested body",
  "",
  "#### Deep",
  "deep body",
  "",
  "## Beta",
  "body",
}, path)
vim.cmd.edit(vim.fn.fnameescape(path))
local buf = vim.api.nvim_get_current_buf()
assert(
  vim.wait(5000, function()
    local clients = vim.lsp.get_clients { bufnr = buf, name = "obsidian-ls", method = "textDocument/foldingRange" }
    return #clients == 1 and clients[1].initialized
  end),
  "Obsidian folding provider did not attach"
)
for option, value in pairs(astro.specs[1].opts.options.opt) do
  vim.opt_local[option] = value
end
require("astroui.folding").refresh(buf)
assert(
  vim.wait(5000, function()
    vim.cmd "normal! zx"
    return vim.fn.foldlevel(4) > 1
  end),
  "AstroNvim did not receive Obsidian heading folds"
)
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local function all_open()
  for line = 1, vim.api.nvim_buf_line_count(0) do
    assert(vim.fn.foldclosed(line) == -1, "Unexpected closed fold on line " .. line)
  end
end

feed "zk"
assert(vim.fn.foldclosed(1) == -1 and vim.fn.foldclosed(4) == 4 and vim.fn.foldclosed(13) == 13)
feed "zl"
assert(vim.fn.foldclosed(4) == -1 and vim.fn.foldclosed(7) == 7 and vim.fn.foldclosed(13) == -1)
feed "z;"
assert(vim.fn.foldclosed(7) == -1 and vim.fn.foldclosed(10) == 10)
feed "zu"
all_open()
feed "zu"
assert(vim.fn.foldclosed(1) == 1)
feed "zu"
all_open()
vim.api.nvim_win_set_cursor(0, { 8, 0 })
feed "zi"
assert(vim.fn.foldclosed(7) == 7)
feed "<CR>"
assert(vim.fn.foldclosed(7) == -1)
assert(not vim.bo.modified, "Fold mappings modified a note")
assert(vim.fn.maparg(",h", "n", false, true).desc == "Previous periodic note")
assert(vim.fn.maparg(",.u", "n") ~= "", "Obsidian search mappings were lost")
print "PASS: Markdown fold mappings work with AstroNvim's real Obsidian LSP provider and preserve note helpers"
