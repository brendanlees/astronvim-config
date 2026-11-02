local M = {}
local states = {}
local delay_ms = 10000

local function cancel(state)
  if state.timer and not state.timer:is_closing() then
    state.timer:stop()
    state.timer:close()
  end
  state.timer = nil
end

local function stamp(path)
  local stat = vim.uv.fs_stat(path)
  return stat and { ino = stat.ino, size = stat.size, mtime = stat.mtime, ctime = stat.ctime } or nil
end

function M.setup(vault)
  for _, state in pairs(states) do
    cancel(state)
  end
  states = {}
  local root = (vim.uv.fs_realpath(vault) or vim.fs.normalize(vault)) .. "/"
  local group = vim.api.nvim_create_augroup("obsidian_autosave", { clear = true })

  local function note_path(buf)
    if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(buf)
    if not name:match "%.md$" then return end
    local parent = vim.uv.fs_realpath(vim.fs.dirname(name))
    if not parent then return end
    local path = vim.uv.fs_realpath(name) or (parent .. "/" .. vim.fs.basename(name))
    if path:sub(1, #root) == root then return path end
  end

  local function track(buf)
    local old = states[buf]
    if old then cancel(old) end
    local path = note_path(buf)
    states[buf] = path and { path = path, stamp = stamp(path) } or nil
  end

  local function warn(state, message)
    if state.warning == message then return end
    state.warning = message
    vim.notify("Note autosave: " .. message .. "\n" .. state.path, vim.log.levels.WARN)
  end

  local function save(buf)
    local state = states[buf]
    if not state or state.saving then return end
    cancel(state)
    if note_path(buf) ~= state.path then return end
    local opts = vim.bo[buf]
    if not opts.modified or not opts.modifiable or opts.readonly then return end
    -- Sync may update a note while it has unsaved local edits. Leave both versions
    -- intact and require a manual resolution rather than silently overwriting disk.
    if not vim.deep_equal(stamp(state.path), state.stamp) then
      warn(state, "paused because the file changed outside Neovim; review both versions before saving.")
      return
    end
    state.saving = true
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd "silent update" end)
    state.saving = false
    if not ok then warn(state, "save failed: " .. tostring(err)) end
  end

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePost" }, {
    group = group,
    callback = function(ev) track(ev.buf) end,
  })
  -- Wait for inactivity, not just a pause in typing while navigating the note.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "CursorMoved", "CursorMovedI" }, {
    group = group,
    callback = function(ev)
      local state = states[ev.buf]
      if not state or state.saving then return end
      cancel(state)
      if not vim.bo[ev.buf].modified then return end
      local timer
      timer = vim.defer_fn(function()
        if states[ev.buf] == state and state.timer == timer then
          state.timer = nil
          save(ev.buf)
        end
      end, delay_ms)
      state.timer = timer
    end,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
    group = group,
    nested = true, -- Keep the usual write hooks, including Obsidian frontmatter updates.
    callback = function(ev) save(ev.buf) end,
  })
  vim.api.nvim_create_autocmd({ "BufUnload", "BufWipeout" }, {
    group = group,
    callback = function(ev)
      if states[ev.buf] then cancel(states[ev.buf]) end
      states[ev.buf] = nil
    end,
  })
  -- Enabling this in an existing session must not adopt a newer disk version
  -- as the baseline for stale buffer text. Other buffers wait for save/reload.
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and not vim.bo[buf].modified then
      local path = note_path(buf)
      if path then
        local ok, lines = pcall(vim.fn.readfile, path)
        if ok and vim.deep_equal(lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false)) then track(buf) end
      end
    end
  end
end

return M
