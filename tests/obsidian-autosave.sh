#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export NVIM_TEST_ROOT="$repo_root" NVIM_TEST_TMP="$tmpdir"
export HOME="$tmpdir/home with spaces"
export XDG_CONFIG_HOME="$tmpdir/config" XDG_DATA_HOME="$tmpdir/data"
export XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache"
mkdir -p "$HOME/Notes/Obsidian/PKM"

nvim --headless -u NONE -i NONE \
  '+lua local ok, err = xpcall(function() dofile(vim.env.NVIM_TEST_ROOT .. "/tests/obsidian-autosave.lua") end, debug.traceback); if not ok then print(err); vim.cmd("cquit 1") end' \
  '+qa!'
