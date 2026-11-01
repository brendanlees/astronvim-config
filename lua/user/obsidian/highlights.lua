local M = {}
M.style = { bg = "#806600", fg = "#ffffff" }

local function matches(line) return require("obsidian.search").find_highlight(line) end

local function line_start(line)
  local first = #(line:match "^%s*")
  -- Keep quote, heading, list and checkbox markers outside the highlighted text.
  while true do
    local quote = line:sub(first + 1):match "^>%s*"
    if not quote then break end
    first = first + #quote
  end
  local rest = line:sub(first + 1)
  local marker = rest:match "^#+%s+" or rest:match "^[-+*]%s+" or rest:match "^%d+[.)]%s+"
  if marker then
    first = first + #marker
    local checkbox = line:sub(first + 1):match "^%[[^%]]%]%s+"
    if checkbox then first = first + #checkbox end
  end
  return first
end

local function toggle(line, first, last)
  local selected = line:sub(first + 1, last)
  first = first + #(selected:match "^%s*")
  last = last - #(selected:match "%s*$")
  if first >= last then return line end
  local spans = matches(line)
  for _, span in ipairs(spans) do
    local left, right = span[1] - 1, span[2]
    if left <= first and last <= right then
      return line:sub(1, left) .. line:sub(left + 3, right - 2) .. line:sub(right + 1)
    end
    if left < last and right > first and not (first <= left and right <= last) then
      vim.notify("Select the entire highlighted passage to change it.", vim.log.levels.WARN)
      return line
    end
  end
  selected = line:sub(first + 1, last)
  -- Flatten existing highlights when extending highlighting across a whole line.
  for i = #spans, 1, -1 do
    local left, right = spans[i][1] - 1, spans[i][2]
    if first <= left and right <= last then
      local a, b = left - first, right - first
      selected = selected:sub(1, a) .. selected:sub(a + 3, b - 2) .. selected:sub(b + 1)
    end
  end
  return line:sub(1, first) .. "==" .. selected .. "==" .. line:sub(last + 1)
end

local function apply(ranges)
  if #ranges == 0 or vim.bo.filetype ~= "markdown" or not vim.bo.modifiable or vim.bo.readonly then return end
  local document = require("obsidian.document").get(0)
  local excluded = require("obsidian.parse.document").BODY_EXCLUSIONS
  local Range = require "obsidian.range"
  local first, last = ranges[1][1], ranges[#ranges][1]
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  local changed = false
  for _, range in ipairs(ranges) do
    local row, start, finish = unpack(range)
    if not document:intersects(Range.new(row - 1, start, row - 1, finish), excluded) then
      local i = row - first + 1
      local updated = toggle(lines[i], math.max(start, line_start(lines[i])), finish)
      if updated ~= lines[i] then
        lines[i] = updated
        changed = true
      end
    end
  end
  -- One edit keeps a multi-line toggle together in undo history.
  if changed then vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines) end
end

function M.line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  apply { { row, 0, #vim.api.nvim_get_current_line() } }
end

function M.word()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  for _, span in ipairs(matches(line)) do
    if span[1] - 1 <= col and col < span[2] then
      apply { { row, span[1] - 1, span[2] } }
      return
    end
  end
  local offset = 0
  while offset < #line do
    local word = vim.fn.matchstrpos(line, [[\k\+]], offset)
    if word[2] < 0 then return end
    if word[2] <= col and col < word[3] then
      apply { { row, word[2], word[3] } }
      return
    end
    offset = word[3]
  end
end

function M.selection()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" then
    vim.notify("Use a character or line selection to highlight text.", vim.log.levels.INFO)
    return
  end
  local regions = vim.fn.getregionpos(vim.fn.getpos "v", vim.fn.getpos ".", {
    type = mode,
    exclusive = vim.o.selection == "exclusive",
  })
  local ranges = {}
  for _, region in ipairs(regions) do
    local row, first, last = region[1][2], region[1][3], region[2][3]
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    if first > 0 then
      -- getregionpos ends at the first byte of the final character, inclusively.
      local finish = last - 1 + #vim.fn.strcharpart(line:sub(last), 0, 1)
      ranges[#ranges + 1] = { row, mode == "V" and 0 or first - 1, mode == "V" and #line or finish }
    end
  end
  vim.cmd.normal { args = { vim.api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true }
  apply(ranges)
end

function M.setup()
  local function style() vim.api.nvim_set_hl(0, "ObsidianHighlightText", M.style) end
  style()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("obsidian_highlight_style", { clear = true }),
    callback = style,
  })
end

function M.attach()
  vim.keymap.set("n", "<LocalLeader>h", M.word, { buffer = true, desc = "Toggle word or passage highlight" })
  vim.keymap.set("n", "<LocalLeader>hh", M.line, { buffer = true, desc = "Toggle line highlight" })
  vim.keymap.set("x", "<LocalLeader>h", M.selection, { buffer = true, desc = "Toggle selected text highlight" })
end

return M
