-- AstroCommunity: import any community modules here
--
-- 
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- packs
  { import = "astrocommunity.pack.ansible" },
  { import = "astrocommunity.pack.bash" },
  -- { import = "astrocommunity.pack.blade" },
  { import = "astrocommunity.pack.chezmoi" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.html-css" },
  -- { import = "astrocommunity.pack.laravel" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.markdown" },
  -- { import = "astrocommunity.markdown-and-latex.render-markdown-nvim" },
  { import = "astrocommunity.pack.php" },
  { import = "astrocommunity.pack.prettier" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.toml" },
  { import = "astrocommunity.pack.yaml" },
  -- extensions
  { import = "astrocommunity.split-and-window.colorful-winsep-nvim" },
  -- { import = "astrocommunity.docker.lazydocker" },
  --- tmux
  { import = "astrocommunity.terminal-integration.vim-tmux-navigator" },
  -- theme — colorscheme is selected dynamically in plugins/astroui.lua from
  -- ~/.config/chezmoi-theme/active.lua, so install every plugin our chezmoi
  -- theme registry can reference. cache-colorscheme is intentionally omitted
  -- because it would persist a stale colorscheme across `theme` switches.
  { import = "astrocommunity.colorscheme.tokyonight-nvim" },
  { import = "astrocommunity.colorscheme.kanagawa-nvim" },
  { import = "astrocommunity.colorscheme.monokai-pro-nvim" },
  { import = "astrocommunity.colorscheme.rose-pine" },
  { "vossenwout/guts.nvim", lazy = true },
  { import = "astrocommunity.recipes.heirline-nvchad-statusline" },
  -- { import = "astrocommunity.recipes.picker-nvchad-theme" },
  -- { import = "astrocommunity.recipes.neo-tree-dark" },
  -- { import = "astrocommunity.recipes.telescope-nvchad-theme" },
  -- { import = "astrocommunity.recipes.telescope-nvim-snacks" },
  { import = "astrocommunity.recipes.vscode-icons" },
  { import = "astrocommunity.recipes.disable-borders" },
  { import = "astrocommunity.indent.indent-rainbowline" },
  { import = "astrocommunity.color.nvim-highlight-colors" },
  -- utility
  { import = "astrocommunity.utility.noice-nvim" },
  -- motion
  { import = "astrocommunity.scrolling.mini-animate" },

  -----------------------------------------------------------------------------
  -- Available packs (uncomment to enable). After uncommenting run :Lazy sync
  -- to install; after re-commenting run :Lazy clean to remove from disk.
  -----------------------------------------------------------------------------
  -- Languages
  -- { import = "astrocommunity.pack.rust" },
  -- { import = "astrocommunity.pack.go" },
  -- { import = "astrocommunity.pack.typescript" },
  -- { import = "astrocommunity.pack.typescript-deno" },
  -- { import = "astrocommunity.pack.ruby" },
  -- { import = "astrocommunity.pack.elixir" },
  -- { import = "astrocommunity.pack.kotlin" },
  -- { import = "astrocommunity.pack.java" },
  -- { import = "astrocommunity.pack.swift" },
  -- { import = "astrocommunity.pack.zig" },
  -- { import = "astrocommunity.pack.cpp" },
  -- { import = "astrocommunity.pack.cs" },
  -- { import = "astrocommunity.pack.haskell" },
  -- { import = "astrocommunity.pack.dart" },
  -- { import = "astrocommunity.pack.julia" },

  -- DevOps / Infra
  -- { import = "astrocommunity.pack.terraform" },
  -- { import = "astrocommunity.pack.nix" },
  -- { import = "astrocommunity.pack.cmake" },
  -- { import = "astrocommunity.pack.helm" },
  -- { import = "astrocommunity.pack.kubernetes" },

  -- Editor extras
  -- { import = "astrocommunity.completion.copilot-lua" },
  -- { import = "astrocommunity.editing-support.todo-comments-nvim" },
  -- { import = "astrocommunity.git.diffview-nvim" },
  -- { import = "astrocommunity.fuzzy-finder.telescope-nvim" },
  -- { import = "astrocommunity.test.neotest" },
  -- { import = "astrocommunity.debugging.nvim-dap" },
}
