local M = {}
local adjusted = setmetatable({}, { __mode = "k" })
local background_ns = vim.api.nvim_create_namespace "markdown_code_background"
local block_query

local function shade_blocks(buf)
  vim.api.nvim_buf_clear_namespace(buf, background_ns, 0, -1)
  if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return end
  local tree = vim.treesitter.get_parser(buf, "markdown"):parse()[1]
  block_query = block_query or vim.treesitter.query.parse("markdown", "(fenced_code_block) @block")
  for _, node in block_query:iter_captures(tree:root(), buf, 0, -1) do
    local first, _, last, col = node:range()
    if col > 0 then last = last + 1 end
    -- Cover complete rows, including empty lines and the space after the text.
    vim.api.nvim_buf_set_extmark(buf, background_ns, first, 0, {
      end_row = last,
      end_col = 0,
      hl_group = "@markup.raw.block.markdown",
      hl_eol = true,
      priority = 90,
    })
  end
end

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
  if buf == 0 then buf = vim.api.nvim_get_current_buf() end
  if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return end
  reveal_fences()
  -- Restart the highlighter to clear any already-rendered concealed-line marks.
  vim.treesitter.stop(buf)
  vim.treesitter.start(buf, "markdown")
  local group = vim.api.nvim_create_augroup("markdown_code_background", { clear = false })
  vim.api.nvim_clear_autocmds { group = group, buffer = buf }
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "BufReadPost", "FileType" }, {
    group = group,
    buffer = buf,
    callback = function() shade_blocks(buf) end,
  })
  shade_blocks(buf)
end

function M.setup()
  M.highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("markdown_code_appearance", { clear = true }),
    callback = M.highlights,
  })
end

return M
