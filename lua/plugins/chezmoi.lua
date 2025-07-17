return {
  {
    "alker0/chezmoi.vim",
    lazy = false,
    init = function()
      -- This option is required.
      vim.g["chezmoi#use_tmp_buffer"] = true
      -- vim.g["chezmoi#use_external"] = 1
    end,
  },
}
