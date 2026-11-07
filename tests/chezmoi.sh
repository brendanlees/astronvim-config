#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
export NVIM_TEST_ROOT="$repo_root"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export HOME="$tmpdir/home"
export XDG_CONFIG_HOME="$tmpdir/config" XDG_DATA_HOME="$tmpdir/data"
export XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache"
# A failing chezmoi keeps the background refresh from replacing the test's managed list.
mkdir -p "$tmpdir/bin"
printf '#!/bin/sh\nexit 1\n' >"$tmpdir/bin/chezmoi"
chmod +x "$tmpdir/bin/chezmoi"
export PATH="$tmpdir/bin:$PATH"

nvim --headless -u NONE -i NONE \
  '+lua local ok, err = xpcall(function() dofile(vim.env.NVIM_TEST_ROOT .. "/tests/chezmoi.lua") end, debug.traceback); if not ok then print(err); vim.cmd("cquit 1") end' \
  '+qa!'
