local M = {}
local adjusted = setmetatable({}, { __mode = "k" })

local function reveal_fences()
  local query = vim.treesitter.query.get("markdown", "highlights")
  if not query or adjusted[query] then return end
  -- Discover the installed query's fence patterns instead of hard-coding their IDs
  -- or copying upstream queries. Leave other Markdown concealment untouched.
  local source = "```lua\nprint('example')\n```\n"
  local root = vim.treesitter.get_string_parser(source, "markdown"):parse()[1]:root()
  local patterns = {}
  for pattern, match, metadata in query:iter_matches(root, source, 0, -1) do
    for capture, nodes in pairs(match) do
      local attributes = metadata[capture] or {}
      if
        metadata.conceal ~= nil
        or metadata.conceal_lines ~= nil
        or attributes.conceal ~= nil
        or attributes.conceal_lines ~= nil
      then
        for _, node in ipairs(nodes) do
          if node:type() == "fenced_code_block_delimiter" or node:type() == "language" then patterns[pattern] = true end
        end
      end
    end
  end
  for pattern in pairs(patterns) do
    query.query:disable_pattern(pattern)
  end
  adjusted[query] = true
end

function M.highlights()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local ok, theme = pcall(dofile, vim.fn.expand "~/.config/chezmoi-theme/active.lua")
  local bg
  if ok and type(theme) == "table" and theme.colorscheme == vim.g.colors_name and theme.palette then
    bg = theme.palette.surface_alt or theme.palette.surface
  end
  if not bg or vim.api.nvim_get_color_by_name(bg) == normal.bg then
    local base = normal.bg or (vim.o.background == "light" and 0xffffff or 0)
    local target = vim.o.background == "light" and 0 or 255
    local channels = {}
    for _, shift in ipairs { 16, 8, 0 } do
      local value = bit.band(bit.rshift(base, shift), 255)
      channels[#channels + 1] = math.floor(value * 0.88 + target * 0.12 + 0.5)
    end
    bg = string.format("#%02x%02x%02x", unpack(channels))
  end
  -- Background only: injected language captures retain their syntax colors.
  vim.api.nvim_set_hl(0, "@markup.raw.block.markdown", { bg = bg })
end

function M.attach(buf)
  if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return end
  reveal_fences()
  -- Restart the highlighter to clear any already-rendered concealed-line marks.
  vim.treesitter.stop(buf)
  vim.treesitter.start(buf, "markdown")
end

function M.setup()
  M.highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("markdown_code_appearance", { clear = true }),
    callback = M.highlights,
  })
end

return M
