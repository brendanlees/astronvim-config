#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NVIM_TEST_ROOT="$repo_root"
export NVIM_TEST_PLUGINS=${NVIM_PLUGIN_ROOT:-"${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$tmpdir/data"
export XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache"

cat >"$tmpdir/check.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.NVIM_TEST_PLUGINS .. "/heirline.nvim")
vim.o.termguicolors = true
local heirline = require "heirline"
local spec = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/heirline.lua")
assert(spec[1] == "rebelot/heirline.nvim", "Heirline configuration is missing")

for _, colors in ipairs({
  { fg = "#c6c6c6", bg = "#080808" },
  { fg = "#202020", bg = "#ffffff" },
}) do
  heirline.clear_colors()
  local opts = spec.opts(nil, {
    opts = { colors = colors },
    winbar = { provider = "hidden" },
    statusline = {
      hl = { fg = "fg", bg = "bg" },
      { provider = "mode " },
      { provider = "branch " },
      { provider = "file" },
    },
  })
  assert(opts.winbar == nil, "Winbar should remain disabled")
  assert(#opts.statusline == 3, "Statusline should not contain the removed Grapple widget")
  heirline.setup(opts)
  vim.v.errmsg = ""
  local rendered = vim.api.nvim_eval_statusline(vim.o.statusline, { maxwidth = 160 })
  assert(rendered.str == "mode branch file", vim.inspect(rendered))
  -- Lua statusline failures can return "0" instead of throwing to this caller.
  assert(vim.v.errmsg == "", vim.v.errmsg)
  assert(vim.api.nvim_exec2("messages", { output = true }).output == "", "Statusline emitted an error")
end
assert(not package.loaded.grapple, "Statusline should not load Grapple")
print("PASS: statusline renders in dark and light colors without Grapple; winbar stays disabled")
LUA
export NVIM_TEST_FILE="$tmpdir/check.lua"
nvim --headless -u NONE -i NONE \
  '+lua local ok, err = xpcall(function() dofile(vim.env.NVIM_TEST_FILE) end, debug.traceback); if not ok then print(err); vim.cmd("cquit 1") end' \
  '+qa!'
