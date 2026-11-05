local M = {}

function M.visit_buffer(picker, item)
  -- Show the highlighted buffer without leaving the buffer manager.
  if item then vim.api.nvim_win_set_buf(picker.main, item.buf) end
end

return M
