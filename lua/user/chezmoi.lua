local M = {}

-- `chezmoi managed` takes most of a second, so file opens use the last saved
-- target-to-source map while a background job refreshes it once per session.
local cache_file = vim.fn.stdpath "cache" .. "/chezmoi-managed.json"
local sources = {}

-- The dotfiles repo keeps its source state in the subdirectory named by .chezmoiroot.
function M.source_dir()
  local dir = vim.env.HOME .. "/.local/share/chezmoi"
  local ok, root = pcall(vim.fn.readfile, dir .. "/.chezmoiroot")
  return ok and root[1] and dir .. "/" .. vim.trim(root[1]) or dir
end

local function load(text)
  local ok, managed = pcall(vim.json.decode, text)
  if not ok or type(managed) ~= "table" then return false end
  sources = {}
  for _, entry in pairs(managed) do
    -- create_ sources only seed a file the app then owns, and modify_ sources are
    -- scripts, so neither is an editable copy of the live file.
    local name = vim.fs.basename(entry.sourceAbsolute)
    if not (vim.startswith(name, "create_") or vim.startswith(name, "modify_")) then
      sources[entry.absolute] = entry.sourceAbsolute
    end
  end
  return true
end

local function refresh()
  vim.system(
    { "chezmoi", "managed", "--include=files", "--path-style=all", "--format=json" },
    { text = true },
    function(result)
      if result.code ~= 0 or not load(result.stdout) then return end
      local file = io.open(cache_file, "w")
      if file then
        file:write(result.stdout)
        file:close()
      end
    end
  )
end

-- Open the chezmoi source instead of the generated target file.
local function redirect(ev)
  if ev.file == "" then return end
  local source = sources[vim.fs.normalize(vim.fn.fnamemodify(ev.file, ":p"))]
  -- Externals (e.g. this Neovim config) have no source file on disk.
  if not source or vim.fn.filereadable(source) ~= 1 then return end
  vim.schedule(function()
    -- Leave background loads alone, such as picker previews or :badd.
    if vim.api.nvim_get_current_buf() ~= ev.buf then return end
    -- Open the source first so the window is never left empty, and keep the
    -- target buffer if it has unsaved changes.
    vim.cmd.edit(vim.fn.fnameescape(source))
    pcall(vim.api.nvim_buf_delete, ev.buf, {})
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("user_chezmoi", { clear = true })
  local source_dir = M.source_dir()

  -- AstroNvim re-runs Neovim's filetype detection after the first file opens,
  -- replacing chezmoi.vim's template filetype, so let chezmoi.vim detect again.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "template",
    callback = function(ev)
      local name = vim.api.nvim_buf_get_name(ev.buf)
      if not vim.startswith(name, source_dir .. "/") then return end
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].filetype ~= "template" then return end
        vim.b[ev.buf].chezmoi_handling = nil
        vim.api.nvim_buf_call(
          ev.buf,
          function() vim.cmd("doautocmd chezmoi_filetypedetect BufRead " .. vim.fn.fnameescape(name)) end
        )
      end)
    end,
  })

  -- Linters and language servers can't parse template syntax.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "chezmoitmpl", "*.chezmoitmpl" },
    callback = function(ev) vim.diagnostic.enable(false, { bufnr = ev.buf }) end,
  })

  if vim.fn.executable "chezmoi" ~= 1 then return end
  local file = io.open(cache_file)
  if file then
    load(file:read "*a")
    file:close()
  end
  refresh()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, { group = group, callback = redirect })
end

return M
