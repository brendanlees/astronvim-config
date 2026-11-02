#!/usr/bin/env bash
set -euo pipefail

# Uses existing plugin checkouts; never installs plugins or touches the real vault.
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
plugin_root=${NVIM_PLUGIN_ROOT:-"${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export OBSIDIAN_TEST_ROOT="$repo_root" OBSIDIAN_TEST_TMP="$tmpdir"
export OBSIDIAN_TEST_LAZY="$plugin_root/lazy.nvim"
export OBSIDIAN_TEST_PLUGIN="$plugin_root/obsidian.nvim"
export OBSIDIAN_TEST_LSPCONFIG="$plugin_root/nvim-lspconfig"
export OBSIDIAN_TEST_SITE="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site"
export OBSIDIAN_TEST_OXIDE_BIN=${MARKDOWN_OXIDE_BIN:-"${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/markdown-oxide"}
export HOME="$tmpdir/home with spaces"
export XDG_CONFIG_HOME="$tmpdir/config" XDG_DATA_HOME="$tmpdir/data"
export XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache"

vault="$HOME/Notes/Obsidian/PKM"
mkdir -p "$vault/system/templates/nvim"
printf '# Daily-note regression fixture\n' >"$vault/system/templates/nvim/daily.md"

cat >"$tmpdir/init.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_ROOT)
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_LAZY)
vim.opt.rtp:append(vim.env.OBSIDIAN_TEST_SITE)
vim.opt.swapfile = false
vim.g.maplocalleader = ","
require("user.markdown.folding").setup()
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then
    errors[#errors + 1] = tostring(message)
    io.stderr:write(tostring(message) .. "\n")
  end
end
local trial = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/markdown-oxide.lua")[2]
trial.init()
if vim.env.OBSIDIAN_TEST_COMPLETION == "1" then
  vim.opt.rtp:append(vim.env.OBSIDIAN_TEST_LSPCONFIG)
  local config = vim.deepcopy(trial.opts.config.markdown_oxide)
  config.cmd = { vim.env.OBSIDIAN_TEST_OXIDE_BIN }
  vim.lsp.config("markdown_oxide", config)
  vim.lsp.enable("markdown_oxide")
end
local spec = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/obsidian.lua")
spec.dir = vim.env.OBSIDIAN_TEST_PLUGIN
local plugins = vim.fs.dirname(vim.env.OBSIDIAN_TEST_PLUGIN)
local queries = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/obsidian-query.lua")
queries.dir = plugins .. "/obsidian-query.nvim"
queries.dependencies[1].dir = plugins .. "/render-markdown.nvim"
local render_options = queries.dependencies[1].opts
queries.dependencies[1].opts = function()
  local opts = render_options()
  -- Tests send consecutive synthetic events faster than an interactive session.
  opts.debounce = 0
  return opts
end
-- Interactive startup defers :Lazy until VeryLazy; headless startup does not.
-- Exercise that registration path without requiring a display server.
require("lazy.core.config").headless = function() return false end
require("lazy").setup({ spec, queries }, {
  root = vim.env.OBSIDIAN_TEST_TMP .. "/plugins",
  lockfile = vim.env.OBSIDIAN_TEST_TMP .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  performance = { rtp = { reset = false } },
})
assert(vim.fn.exists(":Lazy") == 0, ":Lazy must not be available before startup")
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = pcall(function()
        local messages = vim.api.nvim_exec2("messages", { output = true }).output
        assert(not messages:find("E492:", 1, true), messages)
        assert(Obsidian and Obsidian.opts, "Obsidian did not finish setup")
        local root = assert(vim.uv.fs_realpath(vim.env.HOME .. "/Notes/Obsidian/PKM"))
        local relative = require("obsidian.date").format(os.time(), Obsidian.opts.daily_notes.date_format, 1)
        local expected = root .. "/__notes/daily/" .. relative .. ".md"
        assert(vim.wait(3000, function() return vim.api.nvim_buf_get_name(0) == expected end),
          "today's note was not opened: " .. vim.api.nvim_buf_get_name(0) .. "\n"
            .. table.concat(errors, "\n"))
        assert(vim.fn.filereadable(expected) == 1, "daily note was not created")
        assert(vim.tbl_contains(vim.fn.readfile(expected), "# Daily-note regression fixture"),
          "daily template was not used")
        assert(vim.fn.maparg("<LocalLeader>d", "n") ~= "", "periodic mappings missing")
        assert(vim.fn.maparg("<LocalLeader>t", "n") ~= "", "template mappings missing")
        assert(vim.fn.maparg("<LocalLeader>.f", "n") ~= "", "search mappings missing")
        assert(vim.fn.maparg(",b", "n") ~= "", "bookmark toggle mapping missing")
        assert(vim.fn.maparg(",.b", "n") == "<Cmd>Obsidian bookmarks<CR>", "bookmark search mapping missing")
        assert(vim.fn.maparg(",/", "n") ~= "", "word highlight mapping missing")
        assert(vim.fn.maparg(",/", "x") ~= "", "selection highlight mapping missing")
        assert(vim.fn.maparg(",//", "n") ~= "", "line highlight mapping missing")
        assert(vim.fn.maparg(",h", "n", false, true).desc == "Previous periodic note", "previous note mapping overwritten")
        assert(vim.fn.maparg(",l", "n", false, true).desc == "Next periodic note", "next note mapping overwritten")
        assert(vim.fn.maparg(",hh", "n") == "", "old line highlight mapping remains")
        assert(vim.fn.maparg(",h", "x") == "", "old selection highlight mapping remains")
        local hl = vim.api.nvim_get_hl(0, { name = "ObsidianHighlightText", link = false })
        assert(hl.fg == 0xffffff and hl.bg == 0x806600, "highlight colours were not applied")
        if vim.env.OBSIDIAN_TEST_HIGHLIGHTS == "1" then
          vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Highlight integration check" })
          vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(0), 0 })
          vim.fn.maparg(",//", "n", false, true).callback()
          assert(vim.api.nvim_get_current_line() == "==Highlight integration check==")
          vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
          assert(vim.wait(2000, function()
            local ns = vim.api.nvim_get_namespaces().ObsidianUI
            if not ns then return false end
            for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
              if mark[4].hl_group == "ObsidianHighlightText" then return true end
            end
            return false
          end), "Obsidian did not automatically render the highlighted passage")
          vim.cmd.colorscheme "habamax"
          hl = vim.api.nvim_get_hl(0, { name = "ObsidianHighlightText", link = false })
          assert(hl.fg == 0xffffff and hl.bg == 0x806600, "theme change replaced highlight colours")
        end
        for _, key in ipairs { "d", "w", "e" } do
          assert(vim.fn.maparg(",." .. key, "n") ~= "", "periodic search mapping missing: " .. key)
        end
        if vim.env.OBSIDIAN_TEST_METADATA == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-metadata.lua")
        end
        if vim.env.OBSIDIAN_TEST_FOLDING == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-folding.lua")
        end
        if vim.env.OBSIDIAN_TEST_QUERY == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-query.lua")
        end
        if vim.env.OBSIDIAN_TEST_COMPLETION == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-completion.lua")
        end
        if vim.env.OBSIDIAN_TEST_PERIODIC_SEARCH == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-periodic-search.lua")
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-periodic-creation.lua")
        end
        if vim.env.OBSIDIAN_TEST_BOOKMARKS == "1" then
          dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/tests/obsidian-bookmarks.lua")
        end
        if vim.env.OBSIDIAN_TEST_AUTOSAVE == "1" then
          local writes = 0
          vim.api.nvim_create_autocmd("User", {
            pattern = "ObsidianNoteWritePost",
            callback = function() writes = writes + 1 end,
          })
          local marker = "Autosaved through Obsidian write hooks"
          vim.api.nvim_buf_set_lines(0, -1, -1, false, { marker })
          vim.api.nvim_exec_autocmds("TextChangedI", { buffer = 0 })
          assert(not vim.wait(2000, function()
            return vim.tbl_contains(vim.fn.readfile(expected), marker)
          end), "idle autosave still uses the old short delay")
          assert(vim.wait(10000, function()
            return vim.tbl_contains(vim.fn.readfile(expected), marker)
          end), "idle autosave did not reach disk after ten seconds")
          assert(writes == 1 and not vim.bo.modified, "Obsidian write hooks did not complete")
          vim.api.nvim_buf_set_lines(0, -1, -1, false, { "Saved on leaving the note" })
          vim.api.nvim_exec_autocmds("FocusLost", { buffer = 0 })
          assert(vim.tbl_contains(vim.fn.readfile(expected), "Saved on leaving the note"))
          assert(writes == 2, "FocusLost skipped the Obsidian write hook")
        end
        assert(#errors == 0, table.concat(errors, "\n"))
      end)
      if not ok then
        io.stderr:write(tostring(err) .. "\n")
        vim.cmd "cquit"
      else
        print("Obsidian startup and daily note passed")
        vim.cmd "qa!"
      end
    end)
  end,
})
LUA

# Match ov: the Obsidian command itself must load the plugin before :Lazy exists.
nvim --headless -i NONE -u "$tmpdir/init.lua" "$vault" -c 'Obsidian today'
note=$(find "$vault/__notes/daily" -name '*.md' -type f)
printf '\nExisting note must be preserved\n' >>"$note"
cp "$note" "$tmpdir/expected.md"
nvim --headless -i NONE -u "$tmpdir/init.lua" "$vault" -c 'Obsidian today'
cmp "$tmpdir/expected.md" "$note"

# Direct file opens must load Obsidian and its note mappings without a command.
nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
cmp "$tmpdir/expected.md" "$note"

OBSIDIAN_TEST_METADATA=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_AUTOSAVE=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_BOOKMARKS=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_HIGHLIGHTS=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_PERIODIC_SEARCH=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_FOLDING=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_QUERY=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"

if [[ -x "$OBSIDIAN_TEST_OXIDE_BIN" ]]; then
  # Include stale core settings to ensure the vault override takes precedence.
  mkdir -p "$vault/.obsidian"
  printf '%s\n' '{"folder":"__notes/_periodic/daily","format":"YYYY-MM-DD"}' >"$vault/.obsidian/daily-notes.json"
  printf '%s\n' 'daily_notes_folder = ""' \
    'dailynote = "__notes/daily/%Y/%m/%Y-%m-%-d -- %a %-d %B"' \
    'excluded_folders = ["templates", "assets"]' \
    'unresolved_diagnostics = false' 'semantic_tokens = false' \
    'hover = false' 'inlay_hints = false' 'block_transclusion = false' >"$vault/.moxide.toml"
  for folder in system/templates archive/templates system/assets .trash .obsidian; do
    mkdir -p "$vault/$folder"
    printf '%s\n' '# Excluded candidate' >"$vault/$folder/ExcludedCandidate.md"
  done
  mkdir -p "$vault/completion fixtures"
  printf '%s\n' '---' 'aliases: ["Friendly title", "Second alias"]' '---' '# Topic' \
    'A paragraph ^sampleblock' '#oxide-test-tag' >"$vault/completion fixtures/Canonical note.md"
  printf '%s\n' '[[Fri' >"$vault/completion probe.md"
  OBSIDIAN_TEST_COMPLETION=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
else
  printf '\nSKIP: markdown-oxide completion test (binary not installed)\n'
fi
