vim.opt.rtp:append(vim.env.NVIM_TEST_ROOT)
vim.o.swapfile = false
local copied
vim.g.clipboard = {
  name = "test clipboard",
  copy = {
    ["+"] = function(lines) copied = lines[1] end,
    ["*"] = function() error "Unexpected primary clipboard write" end,
  },
  paste = {
    ["+"] = function() return { copied }, "v" end,
    ["*"] = function() return {}, "v" end,
  },
}
vim.notify = function() end
local spec = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/astrocore.lua")
local command = spec.opts.commands.CopyPiReference
vim.api.nvim_create_user_command("CopyPiReference", command[1], { range = command.range, desc = command.desc })
assert(spec.opts.mappings.n["<Leader>ar"][1] == "<Cmd>CopyPiReference<CR>")
assert(spec.opts.mappings.x["<Leader>ar"][1] == ":CopyPiReference<CR>", "Visual mapping must pass the line range")

local root = assert(vim.uv.fs_realpath(vim.env.NVIM_TEST_TMP))
vim.fn.mkdir(root .. "/vault/notes", "p")
vim.cmd.cd(root .. "/vault")
local function open(path)
  vim.cmd.enew()
  vim.api.nvim_buf_set_name(0, path)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "1", "2", "3", "4", "5" })
end

open(root .. "/vault/notes/plain.md")
vim.cmd "CopyPiReference"
assert(copied == "@notes/plain.md", copied)
vim.cmd "2,4CopyPiReference"
assert(copied == "@notes/plain.md#L2-4", copied)
vim.cmd "3CopyPiReference"
assert(copied == "@notes/plain.md#L3", copied)

open(root .. "/vault/notes/2026-11-03 -- My note.md")
vim.cmd "1,2CopyPiReference"
assert(copied == '@"notes/2026-11-03 -- My note.md"#L1-2', copied)

open(root .. "/elsewhere.md")
vim.cmd "CopyPiReference"
assert(copied == "@" .. root .. "/elsewhere.md", "Files outside the cwd must use absolute paths: " .. copied)

copied = nil
vim.cmd.enew()
vim.cmd "CopyPiReference"
assert(copied == nil, "Unnamed buffers must not copy a reference")
print "PASS: pi @ references for files, line ranges, quoted names, paths outside cwd, and mappings"
