local M = {}
local provider = "oxide"
local original = {}

local function update()
  local clients = vim.lsp.get_clients()
  local oxide_roots = {}
  for _, client in ipairs(clients) do
    if client.name == "markdown_oxide" or client.name == "obsidian-ls" then
      original[client.id] = original[client.id] or client.server_capabilities.completionProvider
      if
        client.name == "markdown_oxide"
        and original[client.id]
        and not client:is_stopped()
        and next(client.attached_buffers)
      then
        oxide_roots[client.config.root_dir] = true
      end
    end
  end
  for _, client in ipairs(clients) do
    if original[client.id] then
      local use_oxide = provider == "oxide" and oxide_roots[client.config.root_dir]
      local enabled = (client.name == "markdown_oxide" and use_oxide)
        or (client.name == "obsidian-ls" and not use_oxide)
      client.server_capabilities.completionProvider = enabled and original[client.id] or nil
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("note_completion_provider", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", { group = group, callback = update })
  vim.api.nvim_create_autocmd("LspDetach", {
    group = group,
    -- LspDetach runs before attached_buffers is updated.
    callback = function() vim.schedule(update) end,
  })
  vim.api.nvim_create_user_command("NoteCompletion", function(args)
    if args.args ~= "" then
      if args.args ~= "oxide" and args.args ~= "obsidian" then
        vim.notify("Use :NoteCompletion oxide or :NoteCompletion obsidian", vim.log.levels.WARN)
        return
      end
      provider = args.args
      update()
    end
    vim.notify("Note completion: " .. provider .. (provider == "oxide" and " (Obsidian fallback if unavailable)" or ""))
  end, {
    nargs = "?",
    complete = function() return { "oxide", "obsidian" } end,
    desc = "Choose the note completion provider for this session",
  })
end

return M
