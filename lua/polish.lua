-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- Fall back to OSC 52 clipboard for the + and * registers when no functional
-- native clipboard tool is found. Requires Neovim 0.10+ and a terminal that
-- supports OSC 52 (WezTerm, iTerm2, Kitty, Ghostty, etc.).
-- We check not only whether clipboard tools are installed, but also whether
-- their display server is available ($DISPLAY for X11, $WAYLAND_DISPLAY for
-- Wayland). This ensures that tools like xclip or wl-copy on a headless server
-- or in an SSH session without display forwarding correctly fall through to
-- OSC 52. Fixes clipboard issues when running Neovim on a remote server from a
-- local tmux session.
local has_osc52, osc52 = pcall(require, 'vim.ui.clipboard.osc52')
local has_native_clipboard = (vim.fn.executable('pbcopy') == 1)
    or (vim.fn.executable('xclip') == 1 and vim.env.DISPLAY)
    or (vim.fn.executable('xsel') == 1 and vim.env.DISPLAY)
    or (vim.fn.executable('wl-copy') == 1 and vim.env.WAYLAND_DISPLAY)
if has_osc52 and not has_native_clipboard then
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = osc52.copy('+'),
      ['*'] = osc52.copy('*'),
    },
    paste = {
      ['+'] = osc52.paste('+'),
      ['*'] = osc52.paste('*'),
    },
  }
end
