local M = {}

M.config = {
  -- Use Oxide for this Obsidian vault, not every Markdown project.
  root_dir = function(bufnr, on_dir)
    local vault = vim.env.HOME .. "/Notes/Obsidian/PKM"
    vault = vim.uv.fs_realpath(vault) or vim.fs.normalize(vault)
    if vim.startswith(vim.api.nvim_buf_get_name(bufnr), vault .. "/") then on_dir(vault) end
  end,
  capabilities = {
    workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
  },
  on_init = function(client)
    -- Obsidian still owns navigation, refactoring and note UI.
    local keep = {
      completionProvider = true,
      textDocumentSync = true,
      positionEncoding = true,
      workspace = true,
      executeCommandProvider = true,
    }
    for key in pairs(client.server_capabilities) do
      if not keep[key] then client.server_capabilities[key] = nil end
    end
  end,
  -- Do not install lspconfig's alternate daily-note commands.
  on_attach = function() end,
  handlers = { ["textDocument/publishDiagnostics"] = function() end },
}

return M
