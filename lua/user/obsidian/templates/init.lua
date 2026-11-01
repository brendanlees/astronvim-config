local M = {}
local recipes = require "user.obsidian.templates.recipes"

local function guard(callback)
  local ok, err = pcall(callback)
  if not ok then vim.notify("Could not create note: " .. tostring(err), vim.log.levels.ERROR) end
end

local function select(items, prompt, callback)
  require("obsidian.picker").select(items, { prompt = prompt }, function(choices)
    if choices and choices[1] then vim.schedule(function()
      guard(function() callback(choices[1]) end)
    end) end
  end)
end

local function filename(value)
  -- Keep the entered text in the note; only sanitize filesystem components.
  local name = vim.trim(value:gsub('[<>:"/\\|?*%c]', "-")):gsub("[%. ]+$", "")
  assert(name ~= "", "The title does not produce a valid filename")
  return name
end

local function create(recipe, answers, ctx)
  local result = recipe.build(answers, ctx)
  local path = vim.fs.joinpath(ctx.root, result.folder, filename(result.name) .. ".md")
  local api = require "obsidian.api"
  if vim.uv.fs_stat(path) then
    vim.notify("Note already exists; opening without changes", vim.log.levels.INFO)
    api.open_note(path)
    return
  end

  local data = vim.tbl_extend("force", {
    created = ctx.date "YYYY-MM-DD HH:mm",
    aliases = {},
    links = {},
    tags = {},
    subtype = "",
    status = "",
  }, answers, result.values or {})
  local values = {}
  for key, value in pairs(data) do
    if type(value) == "string" or type(value) == "number" then values[key] = tostring(value) end
    -- Block lists keep wiki links as list items in Obsidian.nvim's YAML parser.
    if type(value) == "table" and vim.islist(value) and #value > 0 then
      local items = vim.tbl_map(function(item) return vim.json.encode(item) end, value)
      values[key .. "_yaml"] = "\n  - " .. table.concat(items, "\n  - ")
    else
      values[key .. "_yaml"] = vim.json.encode(value)
    end
  end
  local lines = vim.fn.readfile(vim.fs.joinpath(ctx.template_dir, result.file or recipe.file))
  -- One pass keeps user-entered braces and percent signs literal.
  local content = (table.concat(lines, "\n") .. "\n"):gsub("{{([%w_]+)}}", function(key)
    assert(values[key] ~= nil, "Unknown template placeholder: " .. key)
    return values[key]
  end)

  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local fd, open_err, code = vim.uv.fs_open(path, "wx", 420)
  if not fd then
    if code == "EEXIST" then
      vim.notify("Note already exists; opening without changes", vim.log.levels.INFO)
      api.open_note(path)
      return
    end
    error(open_err)
  end
  local written, write_err = vim.uv.fs_write(fd, content, 0)
  local closed, close_err = vim.uv.fs_close(fd)
  if written ~= #content or not closed then
    vim.uv.fs_unlink(path)
    error(write_err or close_err or "Could not write the complete note")
  end
  require("obsidian.cache").notes.refresh(path)
  api.open_note(path)
end

function M.pick()
  -- Capture the workspace before picker and prompt buffers change the context.
  local api = require "obsidian.api"
  local root = tostring(api.resolve_workspace_dir())
  local template_dir = api.templates_dir()
  if not template_dir then
    vim.notify("The Obsidian templates folder does not exist", vim.log.levels.ERROR)
    return
  end
  local timestamp = os.time()
  local ctx = {
    root = root,
    template_dir = tostring(template_dir),
    safe = filename,
    date = function(format) return require("obsidian.date").format(timestamp, format, 1) end,
  }
  local labels = vim.tbl_keys(recipes)
  table.sort(labels)
  select(labels, "New note from template", function(label)
    local recipe = recipes[label]
    if recipe.periodic then
      require("user.obsidian.periodic").open_current(recipe.periodic)
      return
    end
    local answers = {}
    local function finish()
      guard(function() create(recipe, answers, ctx) end)
    end
    local function ask(index)
      local field = recipe.fields[index]
      if not field then
        if recipe.prepare then
          recipe.prepare(answers, ctx, finish)
        else
          finish()
        end
        return
      end
      if field.when and not field.when(answers) then
        ask(index + 1)
        return
      end
      local function accept(value)
        answers[field.key] = value
        vim.schedule(function()
          guard(function() ask(index + 1) end)
        end)
      end
      if field.choices then
        local choices = type(field.choices) == "function" and field.choices(answers, ctx) or field.choices
        select(choices, field.prompt, accept)
      else
        local default = field.default and field.default(answers, ctx) or nil
        vim.ui.input({ prompt = field.prompt, default = default }, function(value)
          if value == nil then return end
          value = vim.trim(value)
          if value == "" or value:find "%c" then
            vim.notify("Enter a non-empty, single-line " .. field.key, vim.log.levels.WARN)
            return
          end
          accept(value)
        end)
      end
    end
    ask(1)
  end)
end

function M.attach() vim.keymap.set("n", "<LocalLeader>t", M.pick, { buffer = true, desc = "New note from template" }) end

return M
