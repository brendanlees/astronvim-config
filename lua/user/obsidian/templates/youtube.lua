local function video_id(url)
  local host, path = url:match "^https?://([^/]+)/(.+)$"
  if not host then return end
  host = host:lower()
  local id
  if host == "youtu.be" or host == "www.youtu.be" then
    id = path:match "^([%w_-]+)"
  elseif
    host == "youtube.com"
    or host == "www.youtube.com"
    or host == "m.youtube.com"
    or host == "music.youtube.com"
  then
    if path:match "^watch%?" then
      id = path:match "[?&]v=([%w_-]+)"
    else
      id = path:match "^shorts/([%w_-]+)" or path:match "^live/([%w_-]+)" or path:match "^embed/([%w_-]+)"
    end
  end
  return id and #id == 11 and id or nil
end

return {
  file = "source - yt video.md",
  fields = {
    {
      key = "url",
      prompt = "YouTube URL: ",
      default = function()
        local ok, text = pcall(vim.fn.getreg, "+")
        return ok and video_id(vim.trim(text)) and vim.trim(text) or ""
      end,
    },
  },
  prepare = function(v, _, done)
    local id = video_id(v.url)
    if not id then
      vim.notify("Enter a YouTube video URL", vim.log.levels.WARN)
      return
    end
    if vim.fn.executable "yt-dlp" == 0 then
      vim.notify("YouTube templates require yt-dlp", vim.log.levels.ERROR)
      return
    end
    v.media_link = "https://www.youtube.com/watch?v=" .. id
    vim.notify("Fetching YouTube title and creator…", vim.log.levels.INFO)
    vim.system({
      "yt-dlp",
      "--ignore-config",
      "--no-playlist",
      "--simulate",
      "--dump-single-json",
      "--no-warnings",
      "--socket-timeout",
      "15",
      "--",
      v.media_link,
    }, { text = true, timeout = 30000 }, function(result)
      vim.schedule(function()
        if result.code ~= 0 then
          vim.notify("Could not fetch YouTube metadata: " .. vim.trim(result.stderr or ""), vim.log.levels.ERROR)
          return
        end
        local ok, data = pcall(vim.json.decode, result.stdout or "")
        if
          not ok
          or type(data) ~= "table"
          or type(data.title) ~= "string"
          or type(data.channel or data.uploader) ~= "string"
        then
          vim.notify("YouTube returned incomplete metadata; no note created", vim.log.levels.ERROR)
          return
        end
        v.title, v.creator = data.title:gsub("[\r\n]", " "), (data.channel or data.uploader):gsub("[\r\n]", " ")
        v.year_released = type(data.upload_date) == "string" and data.upload_date:sub(1, 4) or ""
        done()
      end)
    end)
  end,
  build = function(v, ctx)
    return {
      folder = "__notes/sources",
      name = "S_v - " .. ctx.date "YYYY" .. " - " .. v.creator .. " - " .. v.title,
      values = { type = "source, video", aliases = { v.title }, tags = { " #source/video" } },
    }
  end,
}
