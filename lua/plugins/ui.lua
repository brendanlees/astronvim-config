---@type LazySpec
return {
  {
    "echasnovski/mini.animate",
    opts = {
      cursor = { enable = false },
      resize = { enable = false },
      open = { enable = false },
      close = { enable = false },
    },
  },

  {
    "folke/noice.nvim",
    opts = {
      messages = { enabled = false },
      notify = { enabled = false },
      popupmenu = { enabled = false },
      lsp = {
        progress = { enabled = false },
        hover = { enabled = false },
        signature = { enabled = false },
        message = { enabled = false },
      },
      presets = {
        command_palette = true,
        long_message_to_split = false,
        lsp_doc_border = false,
        inc_rename = false,
      },
    },
  },

  {
    "folke/snacks.nvim",
    opts = {
      picker = { enabled = false },
      dashboard = {
        enabled = false,
        preset = {
          header = table.concat({
            " █████  ███████ ████████ ██████   ██████ ",
            "██   ██ ██         ██    ██   ██ ██    ██",
            "███████ ███████    ██    ██████  ██    ██",
            "██   ██      ██    ██    ██   ██ ██    ██",
            "██   ██ ███████    ██    ██   ██  ██████ ",
            "",
            "███    ██ ██    ██ ██ ███    ███",
            "████   ██ ██    ██ ██ ████  ████",
            "██ ██  ██ ██    ██ ██ ██ ████ ██",
            "██  ██ ██  ██  ██  ██ ██  ██  ██",
            "██   ████   ████   ██ ██      ██",
          }, "\n"),
        },
      },
    },
  },

  { "folke/which-key.nvim", enabled = false },

  { "akinsho/toggleterm.nvim", enabled = false },

  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      opts.winbar = nil
      if type(opts.statusline) == "table" then
        table.insert(opts.statusline, 4, {
          condition = function()
            local ok, grapple = pcall(require, "grapple")
            return ok and grapple.exists()
          end,
          provider = function() return "  󰛢 " .. (require("grapple").name_or_index() or "") .. " " end,
        })
      end
      return opts
    end,
  },

  {
    "shortcuts/no-neck-pain.nvim",
    version = "*",
    cmd = { "NoNeckPain", "NoNeckPainToggleLeftSide", "NoNeckPainToggleRightSide" },
    keys = {
      { "<Leader>z", "<cmd>NoNeckPain<cr>", desc = "Toggle No Neck Pain" },
    },
  },
}
