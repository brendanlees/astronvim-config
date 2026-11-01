---@type LazySpec
return {
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
