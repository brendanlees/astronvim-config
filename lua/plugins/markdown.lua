-- Keep list editing out of code fences and YAML frontmatter.
local function markdown_text()
  if vim.bo.filetype ~= "markdown" or vim.bo.buftype ~= "" then return false end
  local parser = vim.treesitter.get_parser(0, "markdown", { error = false })
  if not parser then return false end
  parser:parse()
  local node = vim.treesitter.get_node { ignore_injections = true }
  while node do
    local kind = node:type()
    if
      kind == "fenced_code_block"
      or kind == "indented_code_block"
      or kind == "minus_metadata"
      or kind == "plus_metadata"
    then
      return false
    end
    node = node:parent()
  end
  return true
end

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
    opts = {
      keymap = {
        ["<CR>"] = {
          "accept",
          function()
            if markdown_text() then
              return vim.api.nvim_replace_termcodes("<Cmd>InsertNewBullet<CR>", true, false, true)
            end
          end,
          "fallback",
        },
      },
    },
  },
}
