local M = {}

local function current_file()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.bo.buftype ~= "" or path:match "^%a[%w+.-]*://" then
    vim.notify("Open a file before copying its link.", vim.log.levels.WARN)
    return
  end
  return path
end

local function copy(text, notice)
  if vim.fn.setreg("+", text, "v") == 0 then vim.notify(notice) end
end

function M.copy()
  local path = current_file()
  if not path then return end
  local label = vim.fs.basename(path):gsub("%.[mM][dD]$", "")
  label = label:gsub("[\r\n]", " "):gsub("([\\%[%]`*_<>!&])", "\\%1")
  -- Parentheses are valid URI characters but delimit Markdown link destinations.
  local uri = vim.uri_from_fname(path):gsub("%(", "%%28"):gsub("%)", "%%29")
  copy("[" .. label .. "](" .. uri .. ")", "Copied Markdown file link")
end

--- Copies an `@path` reference for pasting into a pi prompt, with `#L` lines for a range.
--- @param opts? { range: integer, line1: integer, line2: integer } User command range.
function M.copy_pi_ref(opts)
  local path = current_file()
  if not path then return end
  -- pi resolves @paths from its own cwd, which normally matches Neovim's project root.
  path = vim.fs.relpath(vim.fn.getcwd(), path) or path
  -- Same quoting pi's @ autocomplete uses for names with spaces.
  local ref = path:find "%s" and '@"' .. path .. '"' or "@" .. path
  if opts and opts.range > 0 then
    ref = ref .. "#L" .. opts.line1 .. (opts.line2 ~= opts.line1 and "-" .. opts.line2 or "")
  end
  copy(ref, "Copied " .. ref)
end

return M
