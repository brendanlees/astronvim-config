# Neovim configuration

Personal AstroNvim configuration. This repository owns the editor configuration;
[dotfiles](https://github.com/brendanlees/dotfiles) owns its chezmoi deployment
and the shared theme bridge.

## Editing

Use `~/.config/nvim` as a Git checkout of this repository, on a feature branch.
Chezmoi's external definition should use `git-repo`, not an archive. Updates must
be fast-forward-only; resolve a dirty or diverged checkout in Git rather than
forcing a chezmoi apply. On another machine with an older archive installation,
back up and reconcile that directory with upstream before applying this change;
chezmoi will not replace a non-Git directory automatically.

Keep plugin declarations in `lua/plugins/` and custom behavior in `lua/user/`.
The shared theme comes from `~/.config/chezmoi-theme/active.lua`; change it in
dotfiles rather than editing that generated file.

Vault contents and templates stay in the vault, outside this repository.
`lazy-lock.json` remains local and ignored, matching the existing policy.

## Checks

With Neovim, the configured plugins, and Markdown/Lua Treesitter parsers installed:

```sh
bash tests/obsidian-startup.sh
bash tests/markdown.sh
bash tests/statusline.sh
git diff --check
```

These checks use temporary files and do not modify the real vault.
Set `NVIM_PLUGIN_ROOT` if plugin checkouts are not in the usual
`~/.local/share/nvim/lazy` directory.
