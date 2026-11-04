local M = {}

function M.init()
  require("user.markdown.appearance").setup()
  require("user.markdown.folding").setup()
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
end

function M.setup(opts)
  require("otter").setup(opts)
  -- Re-run after adding a new code-block language to an already-open note.
  vim.api.nvim_create_user_command("OtterActivate", function() require("otter").activate() end, {
    desc = "Activate language support for this note's code blocks",
  })
end

return M
