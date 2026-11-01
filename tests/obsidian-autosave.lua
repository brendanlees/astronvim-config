vim.opt.rtp:prepend(vim.env.NVIM_TEST_ROOT)
vim.o.swapfile = false
vim.o.hidden = true
local vault = vim.env.HOME .. "/Notes/Obsidian/PKM"
local warnings = {}
vim.notify = function(message) warnings[#warnings + 1] = message end
dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/obsidian.lua").init()

local function event(name) vim.api.nvim_exec_autocmds(name, { buffer = 0 }) end
local function text(path) return table.concat(vim.fn.readfile(path), "\n") end
local function open(path, content)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ content or "original" }, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  return vim.api.nvim_get_current_buf()
end
local function change(content, trigger)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { content })
  event(trigger or "TextChanged")
end
local function wait_saved(path, expected)
  assert(vim.wait(2500, function() return text(path) == expected end, 20), "Autosave did not write " .. path)
end

local note = vault .. "/daily/note with spaces.md"
local buf = open(note)
local pre, post = 0, 0
vim.api.nvim_create_autocmd("BufWritePre", { buffer = buf, callback = function() pre = pre + 1 end })
vim.api.nvim_create_autocmd("BufWritePost", { buffer = buf, callback = function() post = post + 1 end })
change("first change", "TextChangedI")
vim.wait(900, function() return false end)
assert(text(note) == "original", "Saved before the idle delay")
change("second change", "TextChangedP")
vim.wait(900, function() return false end)
assert(text(note) == "original", "New typing did not restart the delay")
wait_saved(note, "second change")
assert(not vim.bo.modified and pre == 1 and post == 1, "Idle save skipped write hooks")
event "FocusLost"
assert(pre == 1 and post == 1, "Unchanged note was written again")

change "saved on leave"
vim.cmd.enew()
assert(text(note) == "saved on leave" and pre == 2 and post == 2, "Leaving a note did not save with hooks")
vim.cmd.buffer(buf)
change "saved on focus loss"
event "FocusLost"
assert(text(note) == "saved on focus loss" and pre == 3 and post == 3)
vim.wait(1700, function() return false end)
assert(pre == 3, "Cancelled idle timer wrote again")

local new = vault .. "/new note.md"
vim.cmd.edit(vim.fn.fnameescape(new))
change "new note"
event "FocusLost"
assert(text(new) == "new note", "Named new vault note was not saved")

local readonly = vault .. "/readonly.md"
open(readonly)
change "do not write"
vim.bo.readonly = true
event "FocusLost"
assert(text(readonly) == "original" and vim.bo.modified, "Read-only note was written")

local locked = vault .. "/locked.md"
open(locked)
change "do not write"
vim.bo.modifiable = false
event "FocusLost"
assert(text(locked) == "original", "Non-modifiable note was written")

local outside = vim.env.NVIM_TEST_TMP .. "/outside.md"
open(outside)
change "do not write"
event "FocusLost"
assert(text(outside) == "original", "Non-vault Markdown was saved")

local sibling = vault .. "-other/note.md"
open(sibling)
change "do not write"
event "FocusLost"
assert(text(sibling) == "original", "Vault prefix matched a sibling directory")

local source = vault .. "/script.lua"
open(source)
change "do not write"
event "FocusLost"
assert(text(source) == "original", "Source file was saved")

local temporary = vault .. "/note.md.otter.css"
open(temporary)
change "do not write"
event "FocusLost"
assert(text(temporary) == "original", "Otter buffer was saved")

local scratch = vault .. "/scratch.md"
open(scratch)
vim.bo.buftype = "nofile"
change "do not write"
event "FocusLost"
assert(text(scratch) == "original", "Special buffer was saved")

vim.cmd.enew()
change "unnamed"
event "FocusLost"
assert(vim.bo.modified and vim.api.nvim_buf_get_name(0) == "", "Unnamed buffer was altered")

local external = vim.env.NVIM_TEST_TMP .. "/external"
vim.fn.mkdir(external, "p")
assert(vim.uv.fs_symlink(external, vault .. "/linked"))
local linked = vault .. "/linked/note.md"
open(linked)
change "do not write"
event "FocusLost"
assert(text(linked) == "original", "Symlink outside the vault was saved")

local conflict = vault .. "/conflict.md"
open(conflict)
change "local unsaved version"
vim.fn.writefile({ "replaced" }, conflict) -- Same length as the original; timestamps must still catch it.
local before = #warnings
event "FocusLost"
assert(text(conflict) == "replaced" and vim.bo.modified, "Autosave overwrote an external change")
assert(vim.api.nvim_get_current_line() == "local unsaved version", "Conflict lost local edits")
assert(#warnings == before + 1 and warnings[#warnings]:find("changed outside", 1, true), "Conflict was not reported")
event "FocusLost"
assert(#warnings == before + 1, "Conflict warnings repeat on every attempt")
-- A deliberate manual resolution establishes a fresh baseline.
vim.cmd "silent write!"
change "resolved and edited"
event "FocusLost"
assert(text(conflict) == "resolved and edited", "Autosave did not resume after manual save")
vim.fn.writefile({ "reloaded remote version" }, conflict)
vim.o.autoread = true
vim.cmd "checktime"
assert(vim.api.nvim_get_current_line() == "reloaded remote version", "External change was not reloaded")
change "edited after reload"
event "FocusLost"
assert(text(conflict) == "edited after reload", "Reload did not refresh the disk baseline")
change "unsaved after deletion"
vim.fn.delete(conflict)
event "FocusLost"
assert(vim.fn.filereadable(conflict) == 0 and vim.bo.modified, "Autosave recreated an externally deleted note")

local failure = vault .. "/failure.md"
local failed_buf = open(failure)
local fail_hook = vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = failed_buf,
  callback = function() error "test write failure" end,
})
change "pending after failure"
before = #warnings
event "FocusLost"
assert(text(failure) == "original" and vim.bo.modified, "Write failure lost pending edits")
assert(#warnings == before + 1 and warnings[#warnings]:find("save failed", 1, true), "Write failure was not reported")
vim.api.nvim_del_autocmd(fail_hook)
event "FocusLost"
assert(text(failure) == "pending after failure", "Autosave did not recover after write failure")

local discarded = vault .. "/unloaded.md"
local unloaded = open(discarded)
change "pending timer"
-- Simulate unload before a queued timer can run, without a BufLeave save.
event "BufUnload"
vim.api.nvim_buf_delete(unloaded, { force = true })
vim.wait(1700, function() return false end)
assert(text(discarded) == "original", "Unloaded buffer timer still wrote")

local active = vault .. "/already modified.md"
open(active)
change "existing unsaved edits"
require("user.obsidian.autosave").setup(vault)
event "FocusLost"
assert(text(active) == "original" and vim.bo.modified, "Live setup assumed a dirty buffer matched disk")
vim.cmd "silent write"
change "tracked after manual save"
event "FocusLost"
assert(text(active) == "tracked after manual save")
local clean = vault .. "/clean at setup.md"
open(clean)
require("user.obsidian.autosave").setup(vault)
change "live session edit"
event "FocusLost"
assert(text(clean) == "live session edit", "Existing clean buffer was not attached")

local stale = vault .. "/stale at setup.md"
open(stale)
vim.fn.writefile({ "remote text before setup" }, stale)
require("user.obsidian.autosave").setup(vault)
change "edit to stale text"
event "FocusLost"
assert(text(stale) == "remote text before setup", "Live setup adopted a newer disk baseline for stale text")
assert(not vim.o.autowrite and not vim.o.autowriteall, "Global autowrite was enabled")
assert(text(outside) == "original" and text(source) == "original", "Excluded buffers were saved by an idle timer")
print "PASS: vault-only idle/leave/focus autosave, write hooks, exclusions, sync conflicts, failures, and timer cleanup"
