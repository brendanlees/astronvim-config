---@type LazySpec
return {
  "pablopunk/pi.nvim",
  cmd = { "PiAsk", "PiAskSelection", "PiCancel", "PiLog", "PiToggleSession" },
  keys = {
    { "<Leader>aa", "<Cmd>PiAsk<CR>", desc = "Ask pi about buffer" },
    { "<Leader>aa", ":PiAskSelection<CR>", mode = "x", silent = true, desc = "Ask pi about selection" },
    { "<Leader>ac", "<Cmd>PiCancel<CR>", desc = "Cancel pi request" },
    { "<Leader>al", "<Cmd>PiLog<CR>", desc = "Show pi log" },
  },
  opts = {
    -- Requests run headless, so nothing can answer pi's question dialogs and a call would hang.
    -- The vault's Qwen loadout re-enables ask_user_question before each run, overriding `tools`;
    -- only --exclude-tools survives that.
    binary = { "pi", "--exclude-tools", "ask_user_question" },
  },
}
