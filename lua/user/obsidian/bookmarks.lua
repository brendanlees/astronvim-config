local M = {}

function M.toggle()
  local note = require("obsidian.api").current_note(0)
  if not note then return end
  local path = note.path:vault_relative_path()
  if not path then return end
  local bookmarks = require "obsidian.bookmarks"
  local file = bookmarks.resolve_bookmark_file { create = true }
  if not file then return end

  local matches = {}
  local function collect(items)
    assert(type(items) == "table" and vim.islist(items), "invalid bookmark list")
    for _, bookmark in ipairs(items) do
      assert(type(bookmark) == "table", "invalid bookmark entry")
      -- A note bookmark is distinct from a bookmark to one of its headings/blocks.
      if bookmark.type == "file" and bookmark.path == path and (not bookmark.subpath or bookmark.subpath == "") then
        assert(type(bookmark.ctime) == "number", "bookmark has no creation time")
        matches[#matches + 1] = bookmark
      elseif bookmark.type == "group" then
        collect(bookmark.items == nil and {} or bookmark.items)
      end
    end
  end
  local ok, err = pcall(function() collect(bookmarks.parse(table.concat(vim.fn.readfile(file), "\n"))) end)
  if not ok then
    vim.notify("Cannot toggle bookmark: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  if #matches > 0 then
    -- Remove duplicate whole-note entries too, including those inside groups.
    for _, bookmark in ipairs(matches) do
      if not bookmarks.del(bookmark) then
        vim.notify("Could not remove note bookmark: " .. path, vim.log.levels.ERROR)
        return
      end
    end
    vim.notify("Removed note bookmark: " .. path)
  elseif bookmarks.add { type = "file", path = path, ctime = bookmarks.new_ctime() } then
    vim.notify("Bookmarked note: " .. path)
  end
end

function M.attach() vim.keymap.set("n", "<LocalLeader>b", M.toggle, { buffer = true, desc = "Toggle note bookmark" }) end

return M
