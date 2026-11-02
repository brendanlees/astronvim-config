local M = {}

M.order = { "id", "type", "subtype", "aliases", "links", "tags", "created", "modified", "cssclasses", "date", "status" }

local excluded = { "system", "archive", "agents/hermes", "agents/hermes-artifacts" }

function M.enabled(path)
  if not path then return false end
  for _, folder in ipairs(excluded) do
    if path == folder or path:sub(1, #folder + 1) == folder .. "/" then return false end
  end
  return true
end

local function missing(value)
  return value == nil or value == vim.NIL or (type(value) == "string" and vim.trim(value) == "")
end

local function timestamp(seconds) return os.date("!%Y-%m-%d %H:%M:%S", seconds) end

local function file_time(stat, field)
  local value = stat and stat[field]
  return value and value.sec > 0 and value.sec or nil
end

local function unique(values, transform)
  local out, seen = {}, {}
  for _, value in ipairs(values) do
    value = transform(value)
    if value and value ~= "" and not seen[value] then
      out[#out + 1], seen[value] = value, true
    end
  end
  return out
end

function M.frontmatter(note)
  -- The plugin cannot safely replace an unterminated frontmatter block.
  if note.has_frontmatter and not note.frontmatter_end_line then
    vim.notify_once("Note metadata unchanged: unclosed YAML in " .. tostring(note.path), vim.log.levels.WARN)
    return nil
  end

  -- Keep the plugin's ID handling and all unrelated properties.
  local out = vim.deepcopy(require("obsidian.builtin").frontmatter(note))
  local path = tostring(note.path)
  local stat = vim.uv.fs_stat(path)
  local now = os.time()
  local lines = note.raw_contents or note.contents or {}
  local changed = stat == nil

  if note.bufnr and vim.api.nvim_buf_is_loaded(note.bufnr) then
    lines = vim.api.nvim_buf_get_lines(note.bufnr, 0, -1, false)
    if stat and vim.bo[note.bufnr].modified then
      -- A dirty buffer can still match disk after undo or a no-op edit.
      changed = not vim.deep_equal(lines, vim.fn.readfile(path))
    end
  end

  -- This plugin version can misread flow collections containing wikilinks as
  -- scalars. Do not turn a YAML list into a quoted string on the next save.
  for _, element in ipairs(note.frontmatter_elements or {}) do
    if type(element.value) == "string" then
      local range = element.range
      local source = (lines[range.start_row + 1] or ""):sub(range.start_col + 1)
      if source:match "^%{" or (source:match "^%[" and not source:match "^%[%[") then
        vim.notify_once(
          "Note metadata unchanged: the YAML parser could not read a collection in "
            .. path
            .. ". Use a multiline list/mapping before automatic metadata updates.",
          vim.log.levels.WARN
        )
        return nil
      end
    end
  end

  if missing(out.created) then
    -- Birth time may be unavailable after copying/syncing; never replace a
    -- recorded creation date with a later filesystem timestamp.
    out.created = timestamp(file_time(stat, "birthtime") or file_time(stat, "mtime") or now)
  end
  if changed or missing(out.modified) then
    out.modified = timestamp(changed and now or (file_time(stat, "mtime") or now))
  end

  local title
  for _, section in ipairs(require("obsidian.section").parse(lines)) do
    if section.level == 1 then
      title = section.header
      break
    end
  end

  local aliases = {}
  if title then aliases[#aliases + 1] = title end
  vim.list_extend(aliases, out.aliases or {})
  -- Old headings remain useful aliases; without a tracking property we cannot
  -- distinguish an old generated alias from one deliberately added by hand.
  out.aliases = unique(aliases, function(alias)
    if alias ~= note.path.stem then return alias end
  end)
  out.tags = unique(out.tags or {}, function(tag) return tag:gsub("^#+", "") end)
  table.sort(out.tags)

  return out
end

return M
