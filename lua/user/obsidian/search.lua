local M = {}

local function context()
  local root = tostring(require("obsidian.api").resolve_workspace_dir())
  local exclude = { "system/templates/**", ".obsidian/**", ".trash/**" }
  vim.list_extend(exclude, Obsidian.opts.file.ignore_filters or {})
  return root, exclude
end

local function note_types(properties)
  local value = properties and properties.type
  local values = type(value) == "table" and value or { value }
  local result, seen = {}, {}
  for _, item in ipairs(values) do
    if type(item) == "string" then
      local kind = vim.trim(item):lower()
      if kind == "source" or kind:match "^source%s*," then
        kind = "source"
      elseif kind == "study note - course" or kind == "study note - course module" then
        kind = "course"
      elseif kind == "study note - tutorial" then
        kind = "tutorial"
      end
      if kind ~= "" and not seen[kind] then
        seen[kind] = true
        result[#result + 1] = kind:gsub("^%l", string.upper)
      end
    end
  end
  return result
end

local buffer_rows = require("obsidian.cache.volatile").buffer_values { max_entries_per_buffer = 1 }

local function modified_buffer_row(buf, path, root)
  local version = { epoch = root, revision = { path, vim.api.nvim_buf_get_changedtick(buf) } }
  local row = buffer_rows:get(buf, "search", version)
  if row then return row end

  local note = require("obsidian.note").from_buffer(buf)
  local tags = {}
  for _, item in
    ipairs(require("obsidian.tag").extract(note.raw_contents, {
      frontmatter_end_line = note.frontmatter_end_line,
      frontmatter_elements = note.frontmatter_elements,
      document = require("obsidian.document").get(buf),
    }))
  do
    tags[#tags + 1] = item.tag
  end
  row = { aliases = note.aliases, tags = tags, properties = note.metadata }
  buffer_rows:set(buf, "search", version, row)
  return row
end

local function unreviewed(row)
  local tags = require "obsidian.tag"
  for _, tag in ipairs(row.tags or {}) do
    if tags.matches(vim.trim(tag), "_unreviewed", "exact") then return true end
  end
  return false
end

local function scan(mode, callback)
  local cache = require "obsidian.cache"
  if not cache.is_enabled() then
    vim.notify(
      "Obsidian's metadata cache is disabled. Restart Neovim to load the updated configuration.",
      vim.log.levels.WARN
    )
    return
  end
  local root, exclude = context()
  local ignored = require("obsidian.lib.glob").gitignore(exclude, { ignoreCase = true })
  local function eligible(path)
    if not vim.startswith(path, root .. "/") or not path:lower():match "%.md$" then return false end
    if mode == "unreviewed" and not require("user.obsidian.periodic").is_note(path) then return false end
    local relative = path:sub(#root + 2)
    return not vim.startswith(relative, ".") and not relative:find("/.", 1, true) and not ignored:check(relative)
  end

  cache.when_ready(function()
    -- Do not show another workspace if it changed while the initial index was building.
    if not cache.is_ready() or tostring(Obsidian.dir) ~= root then return end
    local rows = cache.notes.all()
    local skipped = 0
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified then
        local name = vim.api.nvim_buf_get_name(buf)
        local path = vim.uv.fs_realpath(name) or vim.fs.normalize(name)
        if eligible(path) then
          local ok, row = pcall(modified_buffer_row, buf, path, root)
          -- Override this query's rows only; unsaved text must not enter the disk cache.
          rows[path] = ok and row or nil
          if not ok then skipped = skipped + 1 end
        end
      end
    end

    local entries = {}
    for path, row in pairs(rows) do
      if eligible(path) and (mode ~= "unreviewed" or unreviewed(row)) then
        local name = vim.fs.basename(path):sub(1, -4)
        local aliases = {}
        for _, alias in ipairs(row.aliases or {}) do
          if alias ~= name then aliases[#aliases + 1] = alias end
        end
        entries[#entries + 1] = {
          path = path,
          label = name .. (#aliases > 0 and (" | " .. table.concat(aliases, " | ")) or ""),
          relative = path:sub(#root + 2),
          types = note_types(row.properties),
        }
      end
    end
    table.sort(entries, function(a, b) return a.path < b.path end)
    if skipped > 0 then vim.notify("Skipped " .. skipped .. " unreadable buffers", vim.log.levels.WARN) end
    callback(entries)
  end)
end

local function pick_notes(entries, title)
  if #entries == 0 then
    vim.notify("No notes found: " .. title, vim.log.levels.INFO)
    return
  end
  local picker = require "obsidian.picker"
  picker.select(entries, {
    prompt = title,
    format_item = function(item) return item.label .. "  [" .. item.relative .. "]" end,
    preview_item = function(item) return picker.preview_path(item.path) end,
  }, function(choices)
    if choices and choices[1] then require("obsidian.api").open_note(choices[1].path) end
  end)
end

function M.names()
  scan("names", function(entries) pick_notes(entries, "Notes: names and aliases") end)
end

function M.unreviewed()
  scan("unreviewed", function(entries) pick_notes(entries, "Periodic notes: #_unreviewed") end)
end

function M.types()
  scan("types", function(entries)
    local groups = {}
    for _, item in ipairs(entries) do
      for _, kind in ipairs(item.types) do
        groups[kind] = groups[kind] or {}
        groups[kind][#groups[kind] + 1] = item
      end
    end
    local labels = vim.tbl_keys(groups)
    table.sort(labels)
    if #labels == 0 then
      vim.notify("No note types found in frontmatter", vim.log.levels.INFO)
      return
    end
    require("obsidian.picker").select(labels, { prompt = "Choose note type" }, function(choices)
      if choices and choices[1] then
        vim.schedule(function() pick_notes(groups[choices[1]], "Notes: " .. choices[1]) end)
      end
    end)
  end)
end

function M.grep()
  local root, exclude = context()
  local cmd = require("obsidian.search").build_grep_cmd { exclude = exclude, fixed_strings = true, sort_by = false }
  -- Put the inclusion first so the later exclusion globs still take precedence.
  table.insert(cmd, 2, "--glob=*.md")
  require("obsidian.picker").grep {
    cmd = cmd,
    dir = root,
    prompt_title = "Search vault text",
    callback = function(entries)
      if entries and entries[1] then require("obsidian.api").open_note(entries[1]) end
    end,
  }
end

function M.incoming()
  local api = require "obsidian.api"
  local note = api.current_note(0)
  if not note then return end
  local root, exclude = context()
  local ignored = require("obsidian.lib.glob").gitignore(exclude, { ignoreCase = true })

  -- Passing the note directly avoids the native command's cursor-dependent scope.
  require("obsidian.search").find_backlinks_async(note, function(matches)
    local entries = {}
    for _, match in ipairs(matches) do
      local path = tostring(match.path)
      local relative = path:sub(#root + 2)
      if vim.startswith(path, root .. "/") and not ignored:check(relative) then
        entries[#entries + 1] = {
          filename = path,
          lnum = match.line,
          col = (match.start or 0) + 1,
          text = relative .. ":" .. match.line .. "  " .. vim.trim(match.text),
        }
      end
    end
    if #entries == 0 then
      vim.notify("No incoming links to this note", vim.log.levels.INFO)
      return
    end
    table.sort(entries, function(a, b)
      if a.filename ~= b.filename then return a.filename < b.filename end
      if a.lnum ~= b.lnum then return a.lnum < b.lnum end
      return a.col < b.col
    end)
    local picker = require "obsidian.picker"
    picker.select(entries, {
      prompt = "Incoming links",
      format_item = function(entry) return entry.text end,
      preview_item = function(entry)
        local preview = picker.preview_path(entry.filename)
        preview.pos = { entry.lnum, entry.col - 1 }
        return preview
      end,
    }, function(choices)
      if choices and choices[1] then api.open_note(choices[1]) end
    end)
  end, { dir = root })
end

function M.outgoing()
  local buf = vim.api.nvim_get_current_buf()
  local document = require("obsidian.document").get(buf)
  local Document = require "obsidian.parse.document"
  local Range = require "obsidian.range"
  local refs = require "obsidian.parse.refs"
  local entries, seen = {}, {}
  -- The native links command reads disk; use its parser on the live snapshot instead.
  for row, line in ipairs(document.lines) do
    for _, ref in ipairs(refs.extract(line, { row = row - 1, lexical = true })) do
      local origin = Range.new(row - 1, ref.range.start_col, row - 1, ref.range.start_col + 1)
      local link = ref.embed and ref.raw:sub(2) or ref.raw
      if
        not document:intersects(origin, Document.INLINE_EXCLUSIONS)
        and not document:intersects(ref.range, Document.COMMENTS)
        and not seen[link]
      then
        entries[#entries + 1] = { link = link, line = row, col = ref.range.start_col }
        seen[link] = true
      end
    end
  end
  if #entries == 0 then
    vim.notify("No outgoing links in this note", vim.log.levels.INFO)
    return
  end
  require("obsidian.picker").select(entries, {
    prompt = "Outgoing links",
    format_item = function(entry) return entry.link end,
    preview_item = function(entry) return { buf = buf, pos = { entry.line, entry.col } } end,
  }, function(choices)
    if choices and choices[1] then require("obsidian.actions").follow_link(choices[1].link) end
  end)
end

function M.attach()
  for key, mapping in pairs {
    b = { "<Cmd>Obsidian bookmarks<CR>", "Search bookmarks" },
    d = { function() require("user.obsidian.periodic").search "daily" end, "Search daily notes" },
    w = { function() require("user.obsidian.periodic").search "weekly" end, "Search weekly notes" },
    e = { function() require("user.obsidian.periodic").search "monthly" end, "Search monthly notes" },
    u = { M.unreviewed, "Search unreviewed periodic notes" },
    t = { M.types, "Search by note type" },
    f = { M.names, "Search note names and aliases" },
    g = { M.grep, "Search vault text" },
    i = { M.incoming, "Search incoming links to this note" },
    o = { M.outgoing, "Show outgoing links" },
  } do
    vim.keymap.set("n", "<LocalLeader>." .. key, mapping[1], { buffer = true, desc = mapping[2] })
  end
end

return M
