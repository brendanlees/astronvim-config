local function markdown_text() return require("user.markdown.editing").is_text() end

---@type LazySpec
return {
  {
    "jmbuhr/otter.nvim",
    ft = "markdown",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      buffers = { write_to_disk = false },
    },
    init = function()
      require("user.markdown.appearance").setup()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("markdown_otter", { clear = true }),
        pattern = "markdown",
        callback = function(ev)
          vim.schedule(function()
            if
              vim.api.nvim_buf_is_valid(ev.buf)
              and vim.bo[ev.buf].filetype == "markdown"
              and vim.bo[ev.buf].buftype == ""
            then
              require("user.markdown.appearance").attach(ev.buf)
              vim.api.nvim_buf_call(ev.buf, function() require("otter").activate() end)
            end
          end)
        end,
      })
    end,
    config = function(_, opts)
      require("otter").setup(opts)
      -- Re-run after adding a new code-block language to an already-open note.
      vim.api.nvim_create_user_command("OtterActivate", function() require("otter").activate() end, {
        desc = "Activate language support for this note's code blocks",
      })
    end,
  },
  {
    "bullets-vim/bullets.nvim",
    ft = "markdown",
    opts = {
      enabled_file_types = { "markdown" },
      set_mappings = false,
      nested_checkboxes = false,
      checkbox_markers = " ~!>x",
      custom_mappings = {
        { "i", "<C-CR>", "<CR>" },
        { "n", "gN", "<Plug>(bullets-renumber)" },
        { "x", "gN", "<Plug>(bullets-renumber)" },
      },
    },
    config = function(_, opts)
      require("bullets").setup(opts)
      local function attach(buf)
        vim.keymap.set(
          { "n", "x" },
          "<LocalLeader>L",
          function() require("user.markdown.editing").menu() end,
          { buffer = buf, desc = "Change Markdown list type" }
        )
        vim.keymap.set(
          "n",
          "o",
          function() return markdown_text() and "<Cmd>InsertNewBullet<CR>" or "o" end,
          { buffer = buf, expr = true, desc = "Open line and continue Markdown list" }
        )
      end
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("markdown_bullets", { clear = true }),
        pattern = "markdown",
        callback = function(ev) attach(ev.buf) end,
      })
      if vim.bo.filetype == "markdown" then attach(0) end
    end,
  },
  {
    "saghen/blink.cmp",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.keymap["<Tab>"], 1, function() return require("user.markdown.editing").tab(1) end)
      table.insert(opts.keymap["<S-Tab>"], 1, function() return require("user.markdown.editing").tab(-1) end)
      opts.keymap["<CR>"] = {
        "accept",
        function()
          if markdown_text() then
            return vim.api.nvim_replace_termcodes("<Cmd>InsertNewBullet<CR>", true, false, true)
          end
        end,
        "fallback",
      }
    end,
  },
}
