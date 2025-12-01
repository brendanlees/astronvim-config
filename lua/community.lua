-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- packs
  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.bash" },
  { import = "astrocommunity.pack.blade" },
  { import = "astrocommunity.pack.chezmoi" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.html-css" },
  { import = "astrocommunity.pack.laravel" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.markdown" },
  { import = "astrocommunity.pack.php" },
  { import = "astrocommunity.pack.prettier" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.yaml" },
  -- extensions
  { import = "astrocommunity.split-and-window.colorful-winsep-nvim" },
  { import = "astrocommunity.docker.lazydocker" },
  { import = "astrocommunity.ai.opencode-nvim" },
  --- tmux
  { import = "astrocommunity.terminal-integration.vim-tmux-navigator" },
  { import = "astrocommunity.terminal-integration.vim-tmux-yank" },
  -- theme
  { import = "astrocommunity.colorscheme.tokyonight-nvim" },
  { import = "astrocommunity.recipes.cache-colorscheme" },
  { import = "astrocommunity.recipes.heirline-nvchad-statusline" },
  { import = "astrocommunity.recipes.vscode-icons" },
  { import = "astrocommunity.recipes.disable-borders" },
  { import = "astrocommunity.indent.indent-rainbowline" },
  { import = "astrocommunity.indent.indent-rainbowline" },
  { import = "astrocommunity.color.nvim-highlight-colors" },
  -- motion
  { import = "astrocommunity.scrolling.mini-animate" },
}
