local M = {}

local formats = {
  weekly = "YYYY/MM/YYYY-MM-D - [Week] ww ---",
  monthly = "YYYY/MM/YYYY-MM --- MMMM YYYY ---",
}

local function parse_note(path)
  local name = vim.fs.basename(path)
  local year, month, day = name:match "^(%d%d%d%d)%-(%d%d)%-(%d%d?) %-%- .+%.md$"
  local kind = "daily"
  if not year then
    year, month, day = name:match "^(%d%d%d%d)%-(%d%d)%-(%d%d?) %- Week %d+ %-%-%-%.md$"
    kind = "weekly"
  end
  if not year then
    year, month = name:match "^(%d%d%d%d)%-(%d%d) %-%-%- .+ %-%-%-%.md$"
    day, kind = "1", "monthly"
  end
  if not year then return end

  year, month, day = tonumber(year), tonumber(month), tonumber(day)
  local timestamp = os.time { year = year, month = month, day = day, hour = 12 }
  local date = os.date("*t", timestamp)
  if date.year ~= year or date.month ~= month or date.day ~= day then return end
  return { path = path, kind = kind, timestamp = timestamp }
end

local function notes_folder()
  local root = tostring(require("obsidian.api").resolve_workspace_dir())
  return vim.fs.joinpath(root, Obsidian.opts.daily_notes.folder)
end

local function list_notes(folder, kind)
  local notes = {}
  for _, path in
    ipairs(vim.fs.find(function(name) return name:sub(-3) == ".md" end, {
      path = folder,
      type = "file",
      limit = math.huge,
    }))
  do
    local note = parse_note(path)
    if note and note.kind == kind then notes[#notes + 1] = note end
  end
  table.sort(notes, function(a, b) return a.timestamp < b.timestamp end)
  return notes
end

local function current_period(kind)
  local date = os.date("*t", os.time())
  date.hour, date.min, date.sec, date.isdst = 12, 0, 0, nil
  if kind == "weekly" then
    -- The vault's Periodic Notes weekly entries start on Monday.
    date.day = date.day - (date.wday + 5) % 7
  elseif kind == "monthly" then
    date.day = 1
  end
  return os.time(date)
end

function M.navigate(direction)
  local folder = notes_folder()
  local path = vim.api.nvim_buf_get_name(0)
  path = vim.uv.fs_realpath(path) or path
  local current = vim.startswith(path, folder .. "/") and parse_note(path) or nil
  local kind = current and current.kind or "daily"
  local timestamp = current and current.timestamp or current_period "daily"
  local target
  for _, note in ipairs(list_notes(folder, kind)) do
    if direction < 0 and note.timestamp < timestamp then
      target = note
    elseif direction > 0 and note.timestamp > timestamp then
      target = note
      break
    end
  end
  if target then
    require("obsidian.api").open_note(target.path)
  else
    vim.notify("No " .. (direction < 0 and "earlier" or "later") .. " " .. kind .. " note", vim.log.levels.INFO)
  end
end

function M.search(kind)
  local notes = list_notes(notes_folder(), kind)
  if #notes == 0 then
    vim.notify("No " .. kind .. " notes found", vim.log.levels.INFO)
    return
  end
  table.sort(notes, function(a, b)
    if a.timestamp == b.timestamp then return a.path < b.path end
    return a.timestamp > b.timestamp
  end)
  local picker = require "obsidian.picker"
  picker.select(notes, {
    prompt = "Search " .. kind .. " notes",
    format_item = function(note) return vim.fs.basename(note.path):sub(1, -4) end,
    preview_item = function(note) return picker.preview_path(note.path) end,
  }, function(choices)
    if choices and choices[1] then require("obsidian.api").open_note(choices[1].path) end
  end)
end

function M.open_current(kind)
  local folder = notes_folder()
  local timestamp = current_period(kind)

  -- Reuse existing files, including older filenames with zero-padded days.
  for _, note in ipairs(list_notes(folder, kind)) do
    if note.timestamp == timestamp then
      require("obsidian.api").open_note(note.path)
      return
    end
  end

  local note
  if kind == "daily" then
    note = require("obsidian.daily").daily { date = timestamp }
  else
    local relative = require("obsidian.date").format(timestamp, formats[kind], 1) .. ".md"
    local path = vim.fs.joinpath(folder, relative)
    note = require("obsidian.note").create {
      id = vim.fs.basename(path):sub(1, -4),
      dir = vim.fs.dirname(path),
      verbatim = true,
      scope = kind,
      template = kind .. ".md",
    }
  end
  if not note:exists() then
    note:write()
    require("obsidian.cache").notes.refresh(tostring(note.path))
  end
  require("obsidian.api").open_note(tostring(note.path))
end

function M.template_for_note(note)
  local path = tostring(note.path)
  if not vim.startswith(path, notes_folder() .. "/") then return end
  local info = parse_note(path)
  return info and (info.kind .. ".md") or nil
end

function M.template_date(ctx, format)
  -- Use the destination date, not today's date, for backdated/future notes.
  local path = ctx.destination_path or (ctx.partial_note and ctx.partial_note.path)
  local info = path and parse_note(tostring(path))
  assert(info, "Periodic templates require a dated daily, weekly, or monthly filename")
  return require("obsidian.date").format(info.timestamp, format, 1)
end

function M.attach()
  local mappings = {
    h = { function() M.navigate(-1) end, "Previous periodic note" },
    l = { function() M.navigate(1) end, "Next periodic note" },
    d = { function() M.open_current "daily" end, "Today's daily note" },
    w = { function() M.open_current "weekly" end, "This week's note" },
    e = { function() M.open_current "monthly" end, "This month's note" },
    f = { "<Cmd>Obsidian quick_switch<CR>", "Find Obsidian note" },
  }
  for key, mapping in pairs(mappings) do
    vim.keymap.set("n", "<LocalLeader>" .. key, mapping[1], { buffer = true, desc = mapping[2] })
  end
end

return M
