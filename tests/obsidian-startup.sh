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
export HOME="$tmpdir/home with spaces"
export XDG_CONFIG_HOME="$tmpdir/config" XDG_DATA_HOME="$tmpdir/data"
export XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache"

vault="$HOME/Notes/Obsidian/PKM"
mkdir -p "$vault/system/templates/nvim"
printf '# Daily-note regression fixture\n' >"$vault/system/templates/nvim/daily.md"

cat >"$tmpdir/init.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_ROOT)
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_LAZY)
vim.opt.swapfile = false
vim.g.maplocalleader = ","
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = tostring(message) end
end
local spec = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/obsidian.lua")
spec.dir = vim.env.OBSIDIAN_TEST_PLUGIN
-- Interactive startup defers :Lazy until VeryLazy; headless startup does not.
-- Exercise that registration path without requiring a display server.
require("lazy.core.config").headless = function() return false end
require("lazy").setup({ spec }, {
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
          assert(vim.wait(3000, function()
            return vim.tbl_contains(vim.fn.readfile(expected), marker)
          end), "idle autosave did not reach disk")
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

OBSIDIAN_TEST_AUTOSAVE=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
OBSIDIAN_TEST_BOOKMARKS=1 nvim --headless -i NONE -u "$tmpdir/init.lua" "$note"
