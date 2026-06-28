---@type LazySpec
return {
  {
    "dmtrKovalenko/fff.nvim",
    build = function()
      -- Downloads a prebuilt binary or falls back to cargo build.
      -- Source: https://github.com/dmtrKovalenko/fff#lazy.nvim
      require("fff.download").download_or_build_binary()
    end,
    lazy = false, -- fff lazy-initializes itself
    opts = {
      lazy_sync = true,
      layout = {
        height = 0.8,
        width = 0.8,
        preview_position = "right",
      },
    },
    keys = {
      { "<Leader>ff", function() require("fff").find_files() end, desc = "Find files" },
      { "<Leader>fF", function() require("fff").find_files() end, desc = "Find all files" },
      { "<Leader>fa", function() require("fff").find_files_in_dir(vim.fn.stdpath "config") end, desc = "Find AstroNvim config files" },
      { "<Leader>fg", function() require("fff").find_files() end, desc = "Find git files" },
      { "<Leader>fw", function() require("fff").live_grep() end, desc = "Find words" },
      { "<Leader>fW", function() require("fff").live_grep() end, desc = "Find words in all files" },
      { "<Leader>fc", function() require("fff").live_grep { query = vim.fn.expand "<cword>" } end, desc = "Find word under cursor" },
      { "<Leader>fR", function() require("fff").scan_files() end, desc = "Rescan files" },
    },
  },
}
