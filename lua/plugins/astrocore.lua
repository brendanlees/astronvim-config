-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      notifications = false, -- enable notifications at start
    },
    treesitter = {
      -- chezmoi.vim's template syntax only works with Vim regex highlighting.
      highlight = function(_, bufnr) return not vim.bo[bufnr].filetype:find "chezmoitmpl" end,
      ensure_installed = {
        "lua",
        "vim",
        "gotmpl",
        "markdown",
        "markdown_inline",
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
        "terraform",
        "twig",
        "typescript",
        "xml",
        "zig",
        "zsh",
      },
    },
    options = {
      opt = { -- vim.opt.<key>
        wrap = true, -- visually wrap long lines to the current window width
        showtabline = 0, -- disable the bufferline
      },
    },
    commands = {
      CopyMarkdownLink = {
        function() require("user.file_link").copy() end,
        desc = "Copy current file as a Markdown link",
      },
    },
    mappings = {
      n = {
        ["<C-Q>"] = { "<Cmd>confirm q<CR>", desc = "Quit window (confirm unsaved changes)" },
        ["<D-C-M-c>"] = { "<Cmd>CopyMarkdownLink<CR>", desc = "Copy current file as a Markdown link" },
      },
    },
  },
}
