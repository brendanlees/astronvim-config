local M = {}

local function input(key, prompt) return { key = key, prompt = prompt } end
local function choice(key, prompt, choices) return { key = key, prompt = prompt, choices = choices } end
local title = input("title", "Title: ")
local source_types = { "book", "podcast", "video", "essay", "lesson", "course", "article" }
local areas = {
  "Drumming",
  "Music Production",
  "Music Composition",
  "Transcription",
  "Creativity",
  "Content Creation",
  "Piano",
  "Jazz",
  "Guitar",
}
local focus = choice("focus_area", "Area of focus", areas)
local duration = choice("focus_duration", "Amount of focus", { "short", "long", "someday" })
local focus_type = choice("focus_type", "Type of focus", { "refinement", "unfamiliar", "exploration", "application" })
local goal = choice("goal_answer", "Related to periodic goals?", { "yes", "no" })
local goal_type = choice("goal_type", "Which period?", { "weekly", "monthly" })
goal_type.when = function(v) return v.goal_answer == "yes" end
local project = choice("project_answer", "Related to a musical project?", { "yes", "no" })
local project_type =
  choice("project_type", "Which project?", { "no.known", "rhythms & systems", "Untitled Metal Project" })
project_type.when = function(v) return v.project_answer == "yes" end

local function simple(file, folder, kind, prefix)
  return {
    file = file,
    fields = { title },
    build = function(v)
      return {
        folder = folder,
        name = v.title,
        values = {
          type = kind,
          aliases = prefix and { prefix .. v.title } or {},
          alias = (prefix or "") .. v.title,
          tags = kind == "documentation" and { "documentation" } or {},
        },
      }
    end,
  }
end

M.Fleeting = simple("fleeting.md", "__notes/fleeting", "fleeting", "fn- ")
M.Permanent = simple("permanent.md", "__notes/permanent", "permanent")
M.Documentation = simple("documentation.md", "_resources/documentation", "documentation", "dc- ")
M.List = simple("list.md", "__notes/lists", "list", "lst- ")
M["Map of content"] = simple("moc.md", "__notes/moc", "moc", "MOC - ")
local moc_build = M["Map of content"].build
M["Map of content"].build = function(v)
  local result = moc_build(v)
  result.values.aliases = { "MOC - " .. v.title, v.title }
  return result
end
M.Default = {
  file = "default.md",
  fields = { title, input("type", "Type: ") },
  build = function(v) return { folder = "", name = v.title } end,
}
M.Source = {
  file = "source.md",
  fields = { choice("source_type", "Source type", source_types), input("creator", "Creator: "), title },
  build = function(v, ctx)
    return {
      folder = "__notes/sources",
      name = "S_" .. v.source_type:sub(1, 1) .. " - " .. ctx.date "YYYY" .. " - " .. v.creator .. " - " .. v.title,
      values = { type = "source, " .. v.source_type, tag = " #source/" .. v.source_type .. " " },
    }
  end,
}

local function music_values(v)
  local links = { "[[" .. v.focus_area .. "]]" }
  if v.project_type then links[#links + 1] = "[[" .. v.project_type .. "]]" end
  return {
    subtype = v.focus_area:lower(),
    links = links,
    area_link = "[[" .. v.focus_area .. "]]",
    goal_tag = v.goal_type and ("#goal/music/" .. v.goal_type) or "",
    focus_tag = v.focus_duration and ("#focus/music/" .. v.focus_duration .. "/" .. v.focus_type) or "",
    goal_line = v.goal_type and ("**Item-Goal**:: #goal/music/" .. v.goal_type) or "",
  }
end

M["Music idea"] = {
  file = "music - idea.md",
  fields = {
    input("description", "Describe the idea: "),
    focus,
    duration,
    focus_type,
    goal,
    goal_type,
    project,
    project_type,
  },
  build = function(v, ctx)
    local values = music_values(v)
    values.type, values.status, values.title = "music idea", "backlog", v.description
    values.aliases, values.tags = { "mi- " .. v.description }, { "#ideas/music", "#_unreviewed" }
    values.links = v.project_type and { "[[" .. v.project_type .. "]]" } or {}
    return {
      folder = "_areas/music/ideas/" .. ctx.safe(v.focus_area:lower()) .. "/" .. ctx.date "YYYY/MM",
      name = v.description,
      values = values,
    }
  end,
}

local function journal(period)
  local fields = { input("description", "What are you working on? "), focus, duration, focus_type }
  if not period then
    fields[#fields + 1], fields[#fields + 2] = goal, goal_type
  end
  fields[#fields + 1], fields[#fields + 2] = project, project_type
  return {
    file = "music - journal" .. (period and (" - " .. period) or "") .. ".md",
    fields = fields,
    build = function(v, ctx)
      local values = music_values(v)
      values.type = "music journal" .. (period and (" - " .. period) or "")
      values.status, values.title = "in progress", v.description .. " (" .. ctx.date "YYYY-MM-D" .. ")"
      values.aliases, values.tags = { "mj- " .. v.description }, { "#journal/music", "#_unreviewed" }
      values.daily_link = "[[" .. ctx.date "YYYY-MM-D -- ddd D MMMM" .. "]]"
      if period then values.goal_tag = "#goal/music/" .. period end
      local name
      if period == "monthly" then
        name = ctx.date "YYYY-MM --- MMMM YYYY ---"
          .. "  ( "
          .. v.focus_area:lower()
          .. " )  - "
          .. v.description
          .. " ---"
      elseif period == "weekly" then
        name = ctx.date "YYYY-MM-D - [Week] ww -"
          .. "  ( "
          .. v.focus_area:lower()
          .. " )  - "
          .. v.description
          .. " ---"
      else
        name = ctx.date "YYYY-MM-D" .. " --  ( " .. v.focus_area:lower() .. " ) -- " .. v.description
      end
      return { folder = "_areas/music/journal/" .. ctx.date "YYYY/MM", name = name, values = values }
    end,
  }
end
M["Music journal"] = journal()
M["Music journal - weekly"] = journal "weekly"
M["Music journal - monthly"] = journal "monthly"

M["Music resource"] = {
  file = "music - resource.md",
  fields = {
    choice("resource_type", "Type of resource", { "book", "course", "phrase", "beat", "progression", "melodic line" }),
    title,
    input("creator", "Creator: "),
    focus,
    goal,
    goal_type,
  },
  build = function(v, ctx)
    local values = music_values(v)
    values.type, values.status, values.links = "music resource", "archived", {}
    values.aliases, values.tags = { "mr- " .. v.title, v.title }, { "#source/music" }
    values.creator_link = "[[" .. v.creator .. "]]"
    return {
      folder = "_areas/music/resources/" .. ctx.safe(v.resource_type .. "s"),
      name = v.title .. " - " .. v.creator,
      values = values,
    }
  end,
}

M["Music song"] = {
  file = "music - song.md",
  fields = { input("artist", "Artist: "), title, focus, duration, focus_type, goal, goal_type, project, project_type },
  build = function(v)
    local values = music_values(v)
    values.type, values.subtype, values.status = "music journal", "song", "backlog"
    values.title = v.artist .. " - " .. v.title
    values.aliases, values.tags = { "ms- " .. values.title }, { "#source/music/song/", "#_unreviewed" }
    values.links = v.project_type and { "[[" .. v.project_type .. "]]" } or {}
    values.artist_link = "[[" .. v.artist .. "]]"
    return { folder = "_areas/music/songs", name = values.title, values = values }
  end,
}

M["Music teaching resource"] = {
  file = "music - teaching resource.md",
  fields = {
    choice(
      "teaching_type",
      "Primary teaching focus",
      { "mindset", "musicianship", "technique", "time", "musicality", "sound", "creativity" }
    ),
    input("subcategory", "Specific focus (subcategory): "),
    title,
    focus,
    goal,
    goal_type,
  },
  build = function(v, ctx)
    local values = music_values(v)
    values.type, values.status = "teaching resource", "backlog"
    values.aliases, values.tags = { "tr- " .. v.title, v.title }, { "#_unreviewed" }
    values.links = { "[[rhythms & systems]]" }
    values.sequence = v.teaching_type:lower() .. "-000-000"
    return {
      folder = "_areas/music/teaching/"
        .. ctx.safe(v.focus_area:lower())
        .. "/"
        .. ctx.safe(v.teaching_type)
        .. "/"
        .. ctx.safe(v.subcategory),
      name = v.title,
      values = values,
    }
  end,
}

M.Course = require "obsidian_templates.study"
M["YouTube video"] = require "obsidian_templates.youtube"
M.Daily = { periodic = "daily" }
M.Weekly = { periodic = "weekly" }
M.Monthly = { periodic = "monthly" }

return M
