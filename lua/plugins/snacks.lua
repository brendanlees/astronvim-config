---@type LazySpec
return {
  "folke/snacks.nvim",
  keys = {
    { "gb", function() require("snacks").picker.buffers() end, desc = "Manage buffers" },
    { "<Leader>gg", function() require("snacks").lazygit() end, desc = "LazyGit" },
  },
  opts = {
    picker = {
      enabled = true,
      layout = { preset = "ivy" },
      sources = {
        buffers = {
          focus = "list",
          actions = {
            buffer_visit = {
              action = require("user.snacks").visit_buffer,
              desc = "Show buffer without closing picker",
            },
          },
          win = {
            input = {
              keys = {
                ["d"] = "bufdelete",
                ["g"] = "buffer_visit",
                ["gg"] = false,
              },
            },
            list = {
              keys = {
                ["d"] = "bufdelete",
                ["dd"] = false,
                ["g"] = "buffer_visit",
                ["gg"] = false,
              },
            },
          },
        },
      },
      win = {
        input = {
          keys = {
            ["<c-;>"] = { "preview_scroll_up", mode = { "i", "n" } },
            ["<c-l>"] = { "preview_scroll_down", mode = { "i", "n" } },
          },
        },
        list = {
          keys = {
            ["<c-l>"] = "preview_scroll_up",
            ["<c-;>"] = "preview_scroll_down",
          },
        },
      },
    },
    scroll = { enabled = false },
    image = {
      enabled = true,
      doc = { enabled = true, inline = false, float = true },
      math = { enabled = false },
    },
    lazygit = {
      win = { position = "float" },
    },
    dashboard = require("user.dashboard").options(),
  },
}
