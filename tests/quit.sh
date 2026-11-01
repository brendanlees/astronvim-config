#!/usr/bin/env bash
set -euo pipefail

export NVIM_TEST_ROOT
NVIM_TEST_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

nvim --headless -u NONE -i NONE \
  '+lua local ok, err = xpcall(function()
    local spec = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/astrocore.lua")
    local mapping = spec.opts.mappings.n["<C-Q>"]
    assert(mapping and mapping[1] == "<Cmd>confirm q<CR>", "Ctrl-Q must confirm rather than force quit")
    vim.keymap.set("n", "<C-Q>", "<Cmd>q!<CR>")
    vim.keymap.set("n", "<C-Q>", mapping[1], { desc = mapping.desc })
    assert(vim.fn.maparg("<C-Q>", "n") == "<Cmd>confirm q<CR>")
    print("PASS: Ctrl-Q overrides force quit with save confirmation")
  end, debug.traceback); if not ok then print(err); vim.cmd("cquit 1") end' \
  '+qa!'
