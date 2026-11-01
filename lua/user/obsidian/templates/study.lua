local NEW = "+ New"
local function folders(path)
  local result = { NEW }
  if vim.fn.isdirectory(path) == 1 then
    for name, kind in vim.fs.dir(path) do
      if kind == "directory" then result[#result + 1] = name end
    end
  end
  table.sort(result)
  return result
end
local function creator(v) return v.creator_choice == NEW and v.creator or v.creator_choice end
local function course(v) return v.course_choice and v.course_choice ~= NEW and v.course_choice or v.course_title end
local function module(v) return v.study_type == "Course Module" end
local function base(v) return v.study_type == "Tutorial" and "_areas/study/tutorials" or "_areas/study/courses" end

local function overview_link(folder, title)
  if vim.fn.isdirectory(folder) == 0 then return end
  local paths = vim.fs.find(
    function(name) return name:sub(-3) == ".md" end,
    { path = folder, type = "file", limit = math.huge }
  )
  table.sort(paths)
  for _, path in ipairs(paths) do
    local name = vim.fs.basename(path):sub(1, -4)
    if vim.startswith(name, "0 - Course Overview") then return "[[" .. name .. "]]" end
  end
  for _, path in ipairs(paths) do
    local name = vim.fs.basename(path):sub(1, -4)
    if name:find(title, 1, true) then
      local ok, note = pcall(require("obsidian.note").from_file, path)
      if ok and note.metadata and note.metadata.subtype == "overview" then return "[[" .. name .. "]]" end
    end
  end
end

return {
  file = "course.md",
  fields = {
    {
      key = "focus_area",
      prompt = "Area of focus",
      choices = {
        "DevOps",
        "PHP",
        "Javascript",
        "React",
        "CSS",
        "Web Development",
        "Back-end Development",
        "Python",
        "Laravel",
        "Git",
        "Ansible",
        "Wordpress",
        "Astro",
        "Webflow",
        "Kubernetes",
        "Linux",
        "Other",
      },
    },
    { key = "custom_area", prompt = "What area? ", when = function(v) return v.focus_area == "Other" end },
    { key = "study_type", prompt = "Type of study note", choices = { "Course", "Course Module", "Tutorial" } },
    {
      key = "creator_choice",
      prompt = "Educator / platform / creator",
      choices = function(v, ctx) return folders(ctx.root .. "/" .. base(v)) end,
    },
    {
      key = "creator",
      prompt = "New educator / platform / creator: ",
      when = function(v) return v.creator_choice == NEW end,
    },
    {
      key = "course_choice",
      prompt = "Course",
      when = module,
      choices = function(v, ctx) return folders(ctx.root .. "/" .. base(v) .. "/" .. ctx.safe(creator(v))) end,
    },
    {
      key = "course_title",
      prompt = "Course / tutorial title: ",
      when = function(v) return not module(v) or v.course_choice == NEW end,
    },
    { key = "module_title", prompt = "Module title (include an ordering prefix if needed): ", when = module },
  },
  build = function(v, ctx)
    local author, title = creator(v), course(v)
    local area = v.focus_area == "Other" and v.custom_area or v.focus_area
    local folder = base(v) .. "/" .. ctx.safe(author) .. "/" .. ctx.safe(title)
    local values = {
      type = "study note - " .. v.study_type:lower(),
      subtype = v.study_type == "Course" and "overview" or "",
      links = { "[[" .. area .. "]]" },
      tags = {},
      status = "in progress",
      today = ctx.date "YYYY-MM-DD",
    }
    local name, file
    if module(v) then
      name, file = v.module_title, "course - module.md"
      values.title = v.module_title .. " | " .. title .. " - (" .. author .. ")"
      values.aliases = { "cm- " .. values.title }
      local link = overview_link(ctx.root .. "/" .. folder, title)
      if link then values.links[#values.links + 1] = link end
    elseif v.study_type == "Tutorial" then
      name, file = title, "course - tutorial.md"
      values.title = title .. " - (" .. author .. ")"
      values.aliases = { "tn- " .. values.title }
    else
      name, file = "0 - Course Overview - " .. title, "course.md"
      values.title = title .. " - (" .. author .. ")"
      values.aliases = { "cn- " .. values.title }
    end
    return { file = file, folder = folder, name = name, values = values }
  end,
}
