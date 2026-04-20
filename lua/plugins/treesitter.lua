-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    auto_install = true,
    highlight = {
      disable = function()
        -- check if 'filetype' option includes 'chezmoitmpl'
        if string.find(vim.bo.filetype, "chezmoitmpl") then return true end
      end,
    },
  },
}
