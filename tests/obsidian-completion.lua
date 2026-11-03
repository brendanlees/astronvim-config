local plugin_root = vim.fs.dirname(vim.env.OBSIDIAN_TEST_PLUGIN)
local Plugin = require "lazy.core.plugin"
local specs = Plugin.Spec.new({
  dofile(plugin_root .. "/AstroNvim/lua/astronvim/plugins/mason-tool-installer.lua"),
  dofile(plugin_root .. "/AstroNvim/lua/astronvim/plugins/_astrolsp.lua"),
  dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/mason.lua"),
  dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/markdown-oxide.lua"),
}, { pkg = false })
assert(specs:report() == 0, "Oxide plugin specs did not merge")
local mason = Plugin.values(specs.plugins["mason-tool-installer.nvim"], "opts", false)
for _, package in ipairs { "markdown-oxide", "systemd-lsp", "astro-language-server", "stylua" } do
  assert(vim.tbl_contains(mason.ensure_installed, package), "Mason lost package " .. package)
end
local lsp = Plugin.values(specs.plugins.astrolsp, "opts", false)
assert(vim.tbl_contains(lsp.servers, "markdown_oxide"), "AstroLSP did not enable Oxide")
assert(lsp.config.markdown_oxide.capabilities.workspace.didChangeWatchedFiles.dynamicRegistration)

local root = tostring(require("obsidian.api").resolve_workspace_dir())
vim.cmd.edit(vim.fn.fnameescape(root .. "/completion probe.md"))
local buf = vim.api.nvim_get_current_buf()
local oxide, obsidian
assert(
  vim.wait(10000, function()
    oxide = vim.lsp.get_clients({ bufnr = buf, name = "markdown_oxide" })[1]
    obsidian = vim.lsp.get_clients({ bufnr = buf, name = "obsidian-ls" })[1]
    return oxide and oxide.initialized and obsidian and obsidian.initialized
  end),
  "Both note language servers must attach"
)

local function active(name)
  local clients = vim.lsp.get_clients { bufnr = buf, method = "textDocument/completion" }
  assert(#clients == 1 and clients[1].name == name, "Expected one completion provider: " .. name)
end
active "markdown_oxide"
assert(obsidian.server_capabilities.definitionProvider, "Obsidian navigation was disabled")
assert(not oxide.server_capabilities.definitionProvider, "Oxide should not duplicate navigation")
assert(not oxide.server_capabilities.codeLensProvider, "Oxide should not duplicate note UI")
assert(vim.fn.exists ":LspToday" == 0, "Oxide installed conflicting daily-note commands")
assert(vim.fn.maparg(",.u", "n") ~= "" and vim.fn.maparg(",w", "n") ~= "", "Note helpers disappeared")

local function complete(client, text)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { text })
  vim.api.nvim_win_set_cursor(0, { 1, #text - 1 })
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(buf) },
    position = { line = 0, character = #text },
    context = { triggerKind = 1 },
  }
  local start = vim.uv.hrtime()
  local response, err = client:request_sync("textDocument/completion", params, 5000, buf)
  assert(response and not response.err, vim.inspect(response or err))
  local items = response.result and (response.result.items or response.result) or {}
  return items, (vim.uv.hrtime() - start) / 1e6
end
local function find(items, needle)
  for _, item in ipairs(items) do
    local text = item.textEdit and item.textEdit.newText or item.insertText or item.label
    if text:find(needle, 1, true) then return text end
  end
  error("Missing completion " .. needle .. ": " .. vim.inspect(items))
end
local items, oxide_ms = complete(oxide, "[[Fri")
local alias_link = find(items, "Friendly title")
assert(alias_link:find("Canonical note", 1, true), "Alias link did not target the canonical note")
find(complete(oxide, "[[Sec"), "Second alias")
find(complete(oxide, "[[Can"), "Canonical note")
find(complete(oxide, "[[Canonical note#"), "Topic")
find(complete(oxide, "[[Canonical note#^"), "sampleblock")
find(complete(oxide, "#oxide"), "oxide-test-tag")
find(complete(oxide, "> [!no"), "note")
local excluded = complete(oxide, "[[ExcludedCandidate")
for _, item in ipairs(excluded) do
  assert(not item.label:find("ExcludedCandidate", 1, true), "Excluded directory leaked into completion")
end

local diagnostics, refreshes = 0, 0
oxide.handlers["textDocument/publishDiagnostics"] = function() diagnostics = diagnostics + 1 end
oxide.handlers["workspace/semanticTokens/refresh"] = function() refreshes = refreshes + 1 end
complete(oxide, "[[MissingOptimizationFixture]]")
vim.wait(800, function() return false end)
assert(diagnostics == 0, "Oxide still publishes unused unresolved-link diagnostics")
assert(refreshes == 0, "Oxide still requests unused semantic-token refreshes")
print "PASS: template/asset/hidden-folder exclusions, block/tag/callout completion, and disabled background diagnostics"

local daily_format = Obsidian.opts.daily_notes.date_format
for _, case in ipairs { { "today", 0 }, { "tomorrow", 1 }, { "yesterday", -1 } } do
  local date = os.date "*t"
  date.day, date.hour, date.min, date.sec, date.isdst = date.day + case[2], 12, 0, 0, nil
  local relative = Obsidian.opts.daily_notes.folder
    .. "/"
    .. require("obsidian.date").format(os.time(date), daily_format, 1)
  local link = find(complete(oxide, "[[" .. case[1]), relative)
  assert(link:sub(1, #relative) == relative, "Daily completion has the wrong path: " .. link)
end

-- Ask the real server to open a fixed single-digit date, without opening a UI.
-- This also checks that the daily folder is not prefixed twice.
local shown
oxide.handlers["window/showDocument"] = function(_, params)
  shown = vim.uri_to_fname(params.uri)
  return { success = true }
end
local response, err = oxide:request_sync("workspace/executeCommand", {
  command = "jump",
  arguments = { "2025-01-09" },
}, 5000, buf)
assert(response and not response.err, vim.inspect(response or err))
local daily_target = root .. "/__notes/daily/2025/01/2025-01-9 -- Thu 9 January.md"
assert(shown == daily_target, "Daily command targeted " .. tostring(shown))
assert(vim.fn.filereadable(daily_target) == 1, "Daily command did not create its temporary fixture")
assert(vim.fn.isdirectory(root .. "/__notes/_periodic") == 0, "Oxide used stale core daily-note settings")
print "PASS: Oxide daily links and command match the active folder, date format, and unpadded days"

vim.cmd "NoteCompletion obsidian"
active "obsidian-ls"
assert(vim.wait(3000, require("obsidian.cache").is_ready), "Obsidian cache did not become ready")
local obsidian_items, obsidian_ms = complete(obsidian, "[[Fri")
find(obsidian_items, "Friendly title")
vim.cmd "NoteCompletion oxide"
active "markdown_oxide"
vim.cmd "NoteCompletion invalid"
active "markdown_oxide"

-- A reattached Obsidian client must honor the current selection too.
vim.lsp.buf_detach_client(buf, obsidian.id)
vim.lsp.buf_attach_client(buf, obsidian.id)
active "markdown_oxide"

-- Losing Oxide restores Obsidian rather than leaving link completion unavailable.
vim.lsp.enable("markdown_oxide", false)
assert(
  vim.wait(5000, function() return obsidian.server_capabilities.completionProvider ~= nil end),
  "Obsidian completion was not restored after Oxide detached"
)
active "obsidian-ls"

-- Oxide must not start in Markdown projects outside the configured vault.
local outside = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(outside, vim.env.HOME .. "/outside.md")
local root_dir
local config = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/markdown-oxide.lua")[2].opts.config.markdown_oxide
config.root_dir(outside, function(dir) root_dir = dir end)
assert(root_dir == nil, "Oxide escaped the vault")
vim.bo[buf].modified = false
print(
  ("PASS: real Oxide alias/name/heading completions, provider switching, fallback, vault scope, and Obsidian helpers (fixture requests: Oxide %.1f ms, Obsidian %.1f ms)"):format(
    oxide_ms,
    obsidian_ms
  )
)
