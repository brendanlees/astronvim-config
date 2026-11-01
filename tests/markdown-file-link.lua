vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.o.swapfile = false
local copied, writes = nil, 0
vim.g.clipboard = {
  name = "test clipboard",
  copy = {
    ["+"] = function(lines, regtype)
      copied = { lines = lines, regtype = regtype }
      writes = writes + 1
    end,
    ["*"] = function() error "Unexpected primary clipboard write" end,
  },
  paste = {
    ["+"] = function() return copied and copied.lines or {}, "v" end,
    ["*"] = function() return {}, "v" end,
  },
}
local notice
vim.notify = function(message) notice = message end
local spec = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/astrocore.lua")
local command = spec.opts.commands.CopyMarkdownLink
vim.api.nvim_create_user_command("CopyMarkdownLink", command[1], { desc = command.desc })
local mapping = spec.opts.mappings.n["<D-C-M-c>"]
assert(mapping, "Cmd+Ctrl+Alt+C mapping missing")
vim.keymap.set("n", "<D-C-M-c>", mapping[1], { desc = mapping.desc })
assert(vim.fn.maparg("<D-C-M-c>", "n") == "<Cmd>CopyMarkdownLink<CR>")

local cases = {
  { "My note.md", "My note", "My%20note.md" },
  { "index.lua", "index.lua", "index.lua" },
  { "A [draft] (v2) #50%.md", [[A \[draft\] (v2) #50%]], "A%20%5bdraft%5d%20%28v2%29%20%2350%25.md" },
  { "café.md", "café", "caf%c3%a9.md" },
  { "a_b*!&.md", [[a\_b\*\!\&]], "a_b*!&.md" },
}
local prefix = assert(vim.uv.fs_realpath(vim.env.NVIM_TEST_TMP)) .. "/"
vim.fn.setreg('"', "keep my yank", "v")
for i, case in ipairs(cases) do
  vim.cmd.enew()
  local path = prefix .. case[1]
  vim.api.nvim_buf_set_name(0, path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unchanged text" })
  local before = writes
  if i == 1 then
    local keys = vim.api.nvim_replace_termcodes("<D-C-M-c>", true, false, true)
    vim.api.nvim_feedkeys(keys, "xt", false)
  else
    vim.cmd.CopyMarkdownLink()
  end
  local expected = "[" .. case[2] .. "](file://" .. prefix .. case[3] .. ")"
  assert(writes == before + 1, "Shortcut or command did not write to the clipboard")
  assert(vim.deep_equal(copied.lines, { expected }), vim.inspect(copied))
  assert(copied.regtype == "v", "Link must be copied without a trailing newline")
  assert(vim.fn.getreg('"') == "keep my yank", "Copying a link replaced the unnamed register")
  assert(vim.api.nvim_get_current_line() == "unchanged text" and vim.bo.modified, "Copying changed or saved the file")
  assert(not vim.uv.fs_stat(path), "Copying created a file")
  assert(notice == "Copied Markdown file link")
  vim.bo.modified = false
end

local before = writes
vim.cmd.enew()
vim.cmd.CopyMarkdownLink()
assert(writes == before and notice == "Open a file before copying its link.")
vim.api.nvim_buf_set_name(0, prefix .. "scratch")
vim.bo.buftype = "nofile"
vim.cmd.CopyMarkdownLink()
assert(writes == before, "Special buffers must not copy a file link")
vim.bo.buftype = ""
vim.api.nvim_buf_set_name(0, "scheme://remote/path")
vim.cmd.CopyMarkdownLink()
assert(writes == before, "Non-file URIs must not become file links")
print "PASS: Markdown file links, URI and label escaping, clipboard, shortcut, command, and non-file guards"
