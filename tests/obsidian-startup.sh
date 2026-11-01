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

vault="$HOME/Notes/Obsidian/Vaults/PKM Vault/PKM"
mkdir -p "$vault/system/templates/nvim"
printf '# Daily-note regression fixture\n' >"$vault/system/templates/nvim/daily.md"

cat >"$tmpdir/init.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_ROOT)
vim.opt.rtp:prepend(vim.env.OBSIDIAN_TEST_LAZY)
vim.opt.swapfile = false
local errors = {}
vim.notify = function(message, level)
  if level == vim.log.levels.ERROR then errors[#errors + 1] = tostring(message) end
end
local spec = dofile(vim.env.OBSIDIAN_TEST_ROOT .. "/lua/plugins/obsidian.lua")
spec.dir = vim.env.OBSIDIAN_TEST_PLUGIN
require("lazy").setup({ spec }, {
  root = vim.env.OBSIDIAN_TEST_TMP .. "/plugins",
  lockfile = vim.env.OBSIDIAN_TEST_TMP .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  performance = { rtp = { reset = false } },
})
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local ok, err = pcall(function()
        assert(Obsidian and Obsidian.opts, "Obsidian did not finish setup")
        local root = assert(vim.uv.fs_realpath(vim.env.HOME .. "/Notes/Obsidian/Vaults/PKM Vault/PKM"))
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

# Match ov's actual startup commands, then check command-triggered loading too.
nvim --headless -i NONE -u "$tmpdir/init.lua" "$vault" \
  -c 'Lazy load obsidian.nvim' -c 'Obsidian today'
note=$(find "$vault/__notes/daily" -name '*.md' -type f)
printf '\nExisting note must be preserved\n' >>"$note"
cp "$note" "$tmpdir/expected.md"
nvim --headless -i NONE -u "$tmpdir/init.lua" "$vault" -c 'Obsidian today'
cmp "$tmpdir/expected.md" "$note"
