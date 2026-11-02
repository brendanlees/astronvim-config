local M = {}

local function headings()
  local result = {}
  local tree = vim.treesitter.get_parser(0, "markdown"):parse()[1]
  local function visit(node)
    for child in node:iter_children() do
      local kind = child:type()
      if kind == "section" then
        visit(child)
      elseif kind == "atx_heading" then
        local level = child:named_child(0):type():match "^atx_h(%d)_marker$"
        result[#result + 1] = { line = child:start() + 1, level = tonumber(level) }
      end
    end
  end
  -- Only document sections: hashes inside code, YAML, lists, or quotes are not note headings.
  visit(tree:root())
  return result
end

local function close_heading(line)
  if vim.fn.foldclosed(line) ~= -1 or vim.fn.foldlevel(line) == 0 then return end
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  vim.cmd "normal! zc"
  local start = vim.fn.foldclosed(line)
  -- Empty sections may have no fold; zc would close an ancestor instead.
  if start ~= -1 and start < line then
    vim.cmd "normal! zo"
    vim.api.nvim_win_set_cursor(0, { line, 0 })
  end
end

function M.fold_headings(level)
  local view = vim.fn.winsaveview()
  vim.cmd "normal! zR"
  -- Native fold depth need not equal heading level (e.g. a note starting with ##).
  for _, heading in ipairs(headings()) do
    if heading.level >= level then close_heading(heading.line) end
  end
  vim.fn.winrestview(view)
  vim.cmd "normal! zz"
end

function M.toggle_all()
  for line = 1, vim.api.nvim_buf_line_count(0) do
    if vim.fn.foldclosed(line) ~= -1 then
      vim.cmd "normal! zR"
      vim.cmd "normal! zz"
      return
    end
  end
  vim.cmd "normal! zM"
  vim.cmd "normal! zz"
end

function M.toggle_fold()
  if vim.fn.foldlevel "." == 0 then return end
  vim.wo.foldenable = true
  vim.cmd "normal! za"
  vim.cmd "normal! zz"
end

function M.toggle_section()
  local current
  for _, heading in ipairs(headings()) do
    if heading.line > vim.fn.line "." then break end
    current = heading
  end
  if current then
    vim.api.nvim_win_set_cursor(0, { current.line, 0 })
    if vim.fn.foldclosed(current.line) == current.line then
      vim.cmd "normal! zo"
    else
      close_heading(current.line)
    end
    vim.cmd "normal! zz"
  end
end

function M.attach(buf)
  if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return end
  for level, key in ipairs { "zj", "zk", "zl", "z;" } do
    vim.keymap.set("n", key, function() M.fold_headings(level) end, {
      buffer = buf,
      desc = ("Fold Markdown headings level %d and deeper"):format(level),
    })
  end
  for key, mapping in pairs {
    zu = { M.toggle_all, "Toggle all Markdown folds" },
    zi = { M.toggle_section, "Toggle current Markdown section" },
    ["<CR>"] = { M.toggle_fold, "Toggle fold under cursor" },
  } do
    vim.keymap.set("n", key, mapping[1], { buffer = buf, desc = mapping[2] })
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("markdown_folding", { clear = true }),
    pattern = "markdown",
    callback = function(ev) M.attach(ev.buf) end,
  })
end

return M
