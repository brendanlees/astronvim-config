local M = {}

function M.is_text(buf, row)
  buf = buf or vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return false end
  local parser = vim.treesitter.get_parser(buf, "markdown", { error = false })
  if not parser then return false end
  parser:parse()
  local node = vim.treesitter.get_node {
    bufnr = buf,
    pos = row and { row - 1, 0 } or nil,
    ignore_injections = true,
  }
  while node do
    local kind = node:type()
    if
      kind == "fenced_code_block"
      or kind == "indented_code_block"
      or kind == "minus_metadata"
      or kind == "plus_metadata"
    then
      return false
    end
    node = node:parent()
  end
  return true
end

local function item(line)
  local indent, marker, body = line:match "^(%s*)([-+*])%s+(.*)$"
  if not marker then
    indent, marker, body = line:match "^(%s*)(%d+[.)])%s+(.*)$"
  end
  if not marker then return end
  local state, text = body:match "^%[([^%]])%]%s*(.*)$"
  return { indent = indent, text = text or body, state = state }
end

function M.cycle_checkbox()
  if not M.is_text() then return false end
  local line = vim.api.nvim_get_current_line()
  local bullet = item(line)
  if not bullet or not bullet.state then return false end
  local states = vim.split(require("bullets.config").options.checkbox_markers, "")
  local index = vim.fn.index(states, bullet.state)
  local next_state = states[(index + 1) % #states + 1]
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local start = line:find("[", 1, true)
  vim.api.nvim_buf_set_text(0, row - 1, start, row - 1, start + #bullet.state, { next_state })
  return true
end

function M.enter()
  if M.cycle_checkbox() then return end
  local folding = require "user.markdown.folding"
  if folding.is_heading(vim.api.nvim_win_get_cursor(0)[1]) then folding.toggle_fold() end
end

-- Four-space levels also nest correctly under numbered markers. Do not change
-- shiftwidth: the note can contain code blocks with their own indentation needs.
function M.indent(direction)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local indent = vim.api.nvim_get_current_line():match "^(%s*)"
  local width = vim.fn.indent(row)
  local next_width = direction > 0 and width + 4 or math.max(0, width - 4)
  vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, #indent, { string.rep(" ", next_width) })
  vim.api.nvim_win_set_cursor(0, { row, math.max(0, col + next_width - #indent) })
  if vim.api.nvim_get_current_line():match "^%s*%d+[.)]" then
    require("bullets.actions").renumber_list()
    vim.api.nvim_win_set_cursor(0, { row, #vim.api.nvim_get_current_line() })
  end
end

-- Return a command rather than editing here: Blink evaluates this under textlock.
function M.tab(direction, allow_text)
  if not M.is_text() then return end
  local bullet = item(vim.api.nvim_get_current_line())
  if bullet and (allow_text or bullet.text:match "^%s*$") then
    return vim.api.nvim_replace_termcodes(
      "<Cmd>lua require('user.markdown.editing').indent(" .. direction .. ")<CR>",
      true,
      false,
      true
    )
  end
end

function M.convert(buf, first, last, kind)
  local lines = vim.api.nvim_buf_get_lines(buf, first - 1, last, false)
  local numbers = {}
  for i, line in ipairs(lines) do
    if line:match "%S" and M.is_text(buf, first + i - 1) then
      local bullet = item(line)
      local indent, text = line:match "^(%s*)(.*)$"
      if bullet then
        indent, text = bullet.indent, bullet.text
      end
      local marker = "- "
      if kind == "number" then
        local depth = vim.fn.strdisplaywidth(indent)
        for level in pairs(numbers) do
          if level > depth then numbers[level] = nil end
        end
        numbers[depth] = (numbers[depth] or 0) + 1
        marker = numbers[depth] .. ". "
      elseif kind == "checkbox" then
        marker = "- [" .. (bullet and bullet.state or " ") .. "] "
      end
      lines[i] = indent .. marker .. text
    end
  end
  vim.api.nvim_buf_set_lines(buf, first - 1, last, false, lines)
end

function M.menu()
  local buf = vim.api.nvim_get_current_buf()
  local first = vim.api.nvim_win_get_cursor(0)[1]
  local last = first
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    first, last = math.min(first, vim.fn.line "v"), math.max(first, vim.fn.line "v")
    vim.cmd.normal { args = { vim.api.nvim_replace_termcodes("<Esc>", true, false, true) }, bang = true }
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  vim.ui.select({
    { kind = "bullet", label = "Bulleted list  - item" },
    { kind = "number", label = "Numbered list  1. item" },
    { kind = "checkbox", label = "Checkbox list  - [ ] item" },
  }, {
    prompt = "List type",
    format_item = function(choice) return choice.label end,
  }, function(choice)
    if not choice or not vim.api.nvim_buf_is_valid(buf) then return end
    if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
      vim.notify("The text changed while choosing a list type; try again", vim.log.levels.WARN)
      return
    end
    M.convert(buf, first, last, choice.kind)
  end)
end

function M.setup_bullets(opts)
  require("bullets").setup(opts)
  local function attach(buf)
    vim.keymap.set(
      { "n", "x" },
      "<LocalLeader>L",
      function() require("user.markdown.editing").menu() end,
      { buffer = buf, desc = "Change Markdown list type" }
    )
    for key, direction in pairs { ["<Tab>"] = 1, ["<S-Tab>"] = -1 } do
      vim.keymap.set(
        "n",
        key,
        function()
          return require("user.markdown.editing").tab(direction, true)
            or vim.api.nvim_replace_termcodes(key, true, false, true)
        end,
        {
          buffer = buf,
          expr = true,
          replace_keycodes = false,
          desc = direction > 0 and "Indent Markdown list item" or "Outdent Markdown list item",
        }
      )
    end
    vim.keymap.set(
      "n",
      "o",
      function() return M.is_text() and "<Cmd>InsertNewBullet<CR>" or "o" end,
      { buffer = buf, expr = true, desc = "Open line and continue Markdown list" }
    )
  end
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("markdown_bullets", { clear = true }),
    pattern = "markdown",
    callback = function(ev) attach(ev.buf) end,
  })
  if vim.bo.filetype == "markdown" then attach(0) end
end

function M.completion_options(opts)
  table.insert(opts.keymap["<Tab>"], 1, function() return require("user.markdown.editing").tab(1) end)
  table.insert(opts.keymap["<S-Tab>"], 1, function() return require("user.markdown.editing").tab(-1) end)
  opts.keymap["<CR>"] = {
    function()
      if M.is_text() then return vim.api.nvim_replace_termcodes("<Cmd>InsertNewBullet<CR>", true, false, true) end
    end,
    "fallback",
  }
end

return M
