local vault = vim.env.HOME .. "/Notes/Obsidian/PKM"
local markdown = vault .. "/*.md"

---@type LazySpec
return {
  "obsidian-nvim/obsidian.nvim",
  -- Keep the custom note helpers on the plugin API they were tested with.
  commit = "15af492b64f4677959fe95008f1d5b782fe1f86a",
  cmd = "Obsidian",
  dependencies = { "dpezto/obsidian-query.nvim" },
  event = { "BufReadPre " .. markdown, "BufNewFile " .. markdown },

  init = function()
    require("user.obsidian.autosave").setup(vault)
    require("user.obsidian.highlights").setup()
    -- Register before lazy loading so Obsidian's first BufEnter check sees this.
    vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile", "BufEnter" }, {
      group = vim.api.nvim_create_augroup("obsidian_conceal", { clear = true }),
      pattern = markdown,
      callback = function() vim.opt_local.conceallevel = 2 end,
    })
  end,

  opts = function(_, opts)
    opts.workspaces = {
      {
        path = vault,
      },
    }
    opts.ui = opts.ui or {}
    opts.ui.hl_groups = opts.ui.hl_groups or {}
    opts.ui.hl_groups.ObsidianHighlightText = require("user.obsidian.highlights").style
    opts.legacy_commands = false
    opts.cache = { enabled = true, backend = "json" }
    local metadata = require "user.obsidian.metadata"
    opts.frontmatter = { enabled = metadata.enabled, func = metadata.frontmatter, sort = metadata.order }
    opts.callbacks = opts.callbacks or {}
    opts.callbacks.post_set_workspace = function(workspace)
      -- Obsidian skips its UI when render-markdown is installed; we still need its inline styling.
      require("obsidian.ui").setup(workspace, Obsidian.opts.ui)
    end
    opts.callbacks.enter_note = function()
      require("user.obsidian.periodic").attach()
      require("user.obsidian.templates").attach()
      require("user.obsidian.search").attach()
      require("user.obsidian.bookmarks").attach()
      require("user.obsidian.highlights").attach()
      require("user.obsidian.queries").attach()
    end
    opts.callbacks.create_note = function(note)
      note.template = note.template or require("user.obsidian.periodic").template_for_note(note)
    end
    opts.daily_notes = {
      template = "daily.md",
      folder = "__notes/daily",
      date_format = "YYYY/MM/YYYY-MM-D -- ddd D MMMM",
    }

    -- This spec owns its defaults; no AstroCommunity Obsidian import is required.
    opts.templates = {
      folder = "system/templates/nvim",
      substitutions = {
        period = function(ctx, format) return require("user.obsidian.periodic").template_date(ctx, format) end,
      },
    }

    return opts
  end,
}
