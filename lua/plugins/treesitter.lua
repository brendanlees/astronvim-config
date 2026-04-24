-- Customize Treesitter

---@type LazySpec
return {
  "nvim-treesitter/nvim-treesitter",
  opts = {
    highlight = {
      disable = function()
        -- check if 'filetype' option includes 'chezmoitmpl'
        if string.find(vim.bo.filetype, "chezmoitmpl") then return true end
      end,
    },
    ensure_installed = {
      "lua",
      "vim",
      "gotmpl",
      "toml",
      "yaml",
      "blade",
      "css",
      "dockerfile",
      "gitignore",
      "git_config",
      "go",
      "graphql",
      "html",
      "http",
      "javascript",
      -- "jinja2", not available?
      "json",
      "nginx",
      "nix",
      "php",
      "python",
      "regex",
      "rust",
      "scss",
      "sql",
      "ssh_config",
      -- "ssh_client_config", not available?
      "terraform",
      "tmux",
      "twig",
      "typescript",
      "xml",
      "zig",
      -- "zsh", not available?
    },
  },
}
