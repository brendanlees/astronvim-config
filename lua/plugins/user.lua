---@type LazySpec
return {

  -- Keep mini.animate for smooth scrolling only; disable cursor/resize/window animations
  {
    "echasnovski/mini.animate",
    opts = {
      cursor = { enable = false },
      resize = { enable = false },
      open = { enable = false },
      close = { enable = false },
    },
  },

  -- Enable blink.cmp cmdline auto-show so completions appear without pressing Tab
  {
    "saghen/blink.cmp",
    opts = {
      cmdline = {
        completion = { menu = { auto_show = false } },
      },
    },
  },

  -- Slim noice down to just the floating cmdline; disable message/LSP/notify reskins
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

  -- == neo-tree ==
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        window = {
          position = "right",
        },
        filtered_items = {
          visible = true, -- This is what you want: If you set this to `true`, all "hide" just mean "dimmed out"
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
  -- customize dashboard options
  {
    "folke/snacks.nvim",
    opts = {
      picker = { enabled = false },
      dashboard = {
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

  -- You can disable default plugins as follows:
  { "max397574/better-escape.nvim", enabled = true },
  { "folke/which-key.nvim", enabled = false },

  -- You can also easily customize additional setup of plugins that is outside of the plugin's setup call
  {
    "L3MON4D3/LuaSnip",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.luasnip"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom luasnip configuration such as filetype extend or custom snippets
      local luasnip = require "luasnip"
      luasnip.filetype_extend("javascript", { "javascriptreact" })
    end,
  },

  {
    "windwp/nvim-autopairs",
    config = function(plugin, opts)
      require "astronvim.plugins.configs.nvim-autopairs"(plugin, opts) -- include the default astronvim config that calls the setup call
      -- add more custom autopairs configuration such as custom rules
      local npairs = require "nvim-autopairs"
      local Rule = require "nvim-autopairs.rule"
      local cond = require "nvim-autopairs.conds"
      npairs.add_rules(
        {
          Rule("$", "$", { "tex", "latex" })
            -- don't add a pair if the next character is %
            :with_pair(cond.not_after_regex "%%")
            -- don't add a pair if  the previous character is xxx
            :with_pair(
              cond.not_before_regex("xxx", 3)
            )
            -- don't move right when repeat character
            :with_move(cond.none())
            -- don't delete if the next character is xx
            :with_del(cond.not_after_regex "xx")
            -- disable adding a newline when you press <cr>
            :with_cr(cond.none()),
        },
        -- disable for .vim files, but it work for another filetypes
        Rule("a", "a", "-vim")
      )
    end,
  },
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
          hl = { fg = "nav_icon_bg" },
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

  {
    "cbochs/grapple.nvim",
    dependencies = { { "nvim-tree/nvim-web-devicons", lazy = true } },
    event = { "BufReadPost", "BufNewFile" },
    cmd = "Grapple",
    opts = {
      scope = "git", -- tags follow the git repo; swap to "git_branch" for per-branch
    },
    keys = {
      { "<Leader>m", "<cmd>Grapple toggle<cr>", desc = "Grapple: toggle tag" },
      { "<Leader>M", "<cmd>Grapple toggle_tags<cr>", desc = "Grapple: tags window" },
      { "<Leader>j", "<cmd>Grapple cycle_tags next<cr>", desc = "Grapple: next tag" },
      { "<Leader>k", "<cmd>Grapple cycle_tags prev<cr>", desc = "Grapple: prev tag" },
      { "<Leader>1", "<cmd>Grapple select index=1<cr>", desc = "Grapple: tag 1" },
      { "<Leader>2", "<cmd>Grapple select index=2<cr>", desc = "Grapple: tag 2" },
      { "<Leader>3", "<cmd>Grapple select index=3<cr>", desc = "Grapple: tag 3" },
      { "<Leader>4", "<cmd>Grapple select index=4<cr>", desc = "Grapple: tag 4" },
    },
  },
}
