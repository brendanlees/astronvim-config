local dashboard_banner = [[
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣀⣀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠿⠿⠇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⢠⡀⢀⣠⣤⣤⣀⠀⠀⠀⠀⢀⣠⣤⣤⣀⠀⠀⠀⠀⢀⣠⣤⣤⣄⡀⠀⢲⣶⣦⠀⠀⠀⠀⢠⣶⣶⠂⣤⣤⡄⠀⣤⣤⢀⣤⣶⣶⣄⠀⣠⣴⣶⣦⣄⠀
⢸⡷⠋⠀⠀⠀⠙⣧⠀⠀⣴⠋⠀⠀⠀⠈⢳⡄⠀⣴⠏⠁⠀⠀⠈⠹⣦⠈⢿⣿⣇⠀⠀⠀⣾⣿⠇⠀⣿⣿⡇⠀⣿⣿⡟⠋⠉⢻⣿⣾⡟⠉⠙⢻⣿⣧
⢸⡇⠀⠀⠀⠀⠀⣿⠀⢸⣧⣤⣤⣤⣤⣤⣤⡇⢰⡏⠀⠀⠀⠀⠀⠀⢹⡇⠘⣿⣿⡄⠀⣼⣿⡟⠀⠀⣿⣿⡇⠀⣿⣿⡇⠀⠀⢸⣿⣿⠀⠀⠀⢸⣿⣿
⢸⡇⠀⠀⠀⠀⠀⣿⠀⢸⡇⠀⠀⠀⠀⠀⠀⠀⢸⡇⠀⠀⠀⠀⠀⠀⢸⡇⠀⠸⣿⣷⢰⣿⡿⠀⠀⠀⣿⣿⡇⠀⣿⣿⡇⠀⠀⢸⣿⣿⠀⠀⠀⢸⣿⣿
⢸⡇⠀⠀⠀⠀⠀⣿⠀⠈⢷⡀⠀⠀⠀⠀⢀⡀⠀⢿⡀⠀⠀⠀⠀⢠⡿⠁⠀⠀⢻⣿⣿⣿⠃⠀⠀⠀⣿⣿⡇⠀⣿⣿⡇⠀⠀⢸⣿⣿⠀⠀⠀⢸⣿⣿
⠸⠇⠀⠀⠀⠀⠀⠿⠀⠀⠀⠙⠳⠶⠶⠞⠋⠁⠀⠀⠙⠲⠶⠶⠞⠋⠀⠀⠀⠀⠀⠛⠛⠃⠀⠀⠀⠀⠛⠛⠃⠀⠛⠛⠃⠀⠀⠘⠛⠛⠀⠀⠀⠘⠛⠛]]
local dashboard_lines = vim.split(dashboard_banner, "\n")
local dashboard_width = math.max(unpack(vim.tbl_map(vim.fn.strdisplaywidth, dashboard_lines)))
local function animate_dashboard() return vim.fn.executable "ttfx" == 1 and vim.o.columns >= dashboard_width end

local M = {}

function M.options()
  return {
    enabled = true,
    width = dashboard_width,
    preset = {
      header = "Neovim",
      keys = {
        { key = "f", action = "<Leader>ff", desc = "Find files" },
        { key = "w", action = "<Leader>fw", desc = "Search text" },
        { key = "b", action = "gb", desc = "Buffers" },
        { key = "r", action = "<Leader>fo", desc = "Recent files" },
        { key = "k", action = "<Leader>fk", desc = "Keymaps" },
        { key = "g", action = "<Leader>gg", desc = "LazyGit" },
        { key = "n", action = "<Leader>n", desc = "New file" },
        { key = "c", action = "<Leader>fa", desc = "Configuration" },
        { key = "L", action = ":Lazy", desc = "Plugins" },
        { key = "q", action = ":qa", desc = "Quit" },
      },
    },
    sections = {
      function()
        -- Resolve the palette when the dashboard opens, after the active theme has loaded.
        local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg
          or (vim.o.background == "light" and 0x000000 or 0xffffff)
        local colors = {}
        for _, group in ipairs { "Function", "Type", "Special" } do
          local fg = vim.api.nvim_get_hl(0, { name = group, link = false }).fg or normal
          colors[#colors + 1] = ("%06x"):format(fg)
        end
        local palette = table.concat(colors, " ")
        return {
          section = "terminal",
          -- Wait quietly after successful playback so Neovim does not append a process-exit message.
          cmd = ("printf '%%s' %s | ttfx --frame-rate 375 --canvas-width 0 --canvas-height %d --no-eol --no-restore-cursor rain --rain-colors %s --final-gradient-stops %s && read -r _"):format(
            vim.fn.shellescape(dashboard_banner),
            #dashboard_lines,
            palette,
            palette
          ),
          width = dashboard_width,
          height = #dashboard_lines + 1, -- Leave room for ttfx canvas setup without scrolling the logo.
          ttl = 0, -- Replay on each dashboard open instead of caching the final frame.
          padding = 1,
          enabled = animate_dashboard,
        }
      end,
      { section = "header", padding = 1, enabled = function() return not animate_dashboard() end },
      { section = "keys", padding = 1 },
      { section = "startup" },
    },
  }
end

return M
