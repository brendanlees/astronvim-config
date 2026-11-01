local M = {}

function M.copy()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.bo.buftype ~= "" or path:match "^%a[%w+.-]*://" then
    vim.notify("Open a file before copying its link.", vim.log.levels.WARN)
    return
  end
  local label = vim.fs.basename(path):gsub("%.[mM][dD]$", "")
  label = label:gsub("[\r\n]", " "):gsub("([\\%[%]`*_<>!&])", "\\%1")
  -- Parentheses are valid URI characters but delimit Markdown link destinations.
  local uri = vim.uri_from_fname(path):gsub("%(", "%%28"):gsub("%)", "%%29")
  local link = "[" .. label .. "](" .. uri .. ")"
  if vim.fn.setreg("+", link, "v") == 0 then
    vim.notify("Copied Markdown file link")
  end
end

return M
