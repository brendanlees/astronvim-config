vim.opt.rtp:prepend(vim.env.NVIM_TEST_ROOT)
vim.go.loadplugins = true
vim.opt.rtp:prepend(vim.env.NVIM_TEST_PLUGINS .. "/lazy.nvim")
vim.opt.rtp:append(vim.env.NVIM_TEST_SITE)
vim.g.mapleader = " "
vim.o.swapfile = false
vim.o.hidden = true
vim.o.columns = 160
vim.o.lines = 50
local function spec(file, name)
  local plugin = dofile(vim.env.NVIM_TEST_ROOT .. "/lua/plugins/" .. file .. ".lua")
  assert(plugin[1] == name, "Missing plugin: " .. name)
  return plugin
end
require("lazy").setup({
  spec("snacks", "folke/snacks.nvim"),
}, {
  root = vim.env.NVIM_TEST_PLUGINS,
  lockfile = vim.env.NVIM_TEST_TMP .. "/lazy-lock.json",
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
})
local snacks = require "snacks"
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false) end
local opts = snacks.config
assert(
  opts.scroll.enabled and opts.scroll.animate.duration.total == 120,
  "Smooth scrolling should use short animations"
)
assert(opts.scroll.animate_repeat.duration.total == 40, "Repeated scrolling should be faster")
assert(
  opts.image.enabled and opts.image.doc.enabled and opts.image.doc.float and not opts.image.doc.inline,
  "Document images should use cursor-line floats, not inline rendering"
)
assert(not opts.image.math.enabled, "Image support should not add automatic math rendering")
assert(opts.dashboard.enabled and opts.lazygit.win.position == "float")

local lines = {}
for i = 1, 300 do
  lines[i] = "-- line " .. i
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_buf_set_name(0, vim.env.NVIM_TEST_TMP .. "/scroll.lua")
vim.bo.modified = false
assert(opts.scroll.filter(0), "File buffers should animate")
vim.bo.buftype = "nofile"
assert(not opts.scroll.filter(0), "Picker and other special buffers should not animate")
vim.bo.buftype = ""
vim.g.snacks_scroll = false
assert(not opts.scroll.filter(0), "Global scroll opt-out must work")
vim.g.snacks_scroll = nil
local function reset()
  vim.cmd "normal! ggzt"
  vim.cmd.redraw()
end
snacks.scroll.disable()
reset()
feed "<C-d>"
local expected = vim.fn.winsaveview()
reset()
snacks.scroll.enable()
assert(snacks.scroll.enabled, "Smooth scrolling did not enable")
feed "<C-d>"
vim.cmd.redraw()
assert(
  vim.wait(1500, function()
    local view = vim.fn.winsaveview()
    return view.topline == expected.topline and view.lnum == expected.lnum
  end, 10),
  "Smooth scrolling did not finish at the normal scroll target"
)
snacks.scroll.disable()

local project = vim.env.NVIM_TEST_TMP .. "/project"
vim.fn.mkdir(project, "p")
vim.fn.system { "git", "init", "--quiet", project }
assert(vim.v.shell_error == 0, "Could not create a test repository")
vim.fn.system { "magick", "-size", "8x8", "xc:red", project .. "/preview.jpg" }
assert(vim.v.shell_error == 0, "ImageMagick could not create the image fixture")
local converted = snacks.image.convert.convert { src = project .. "/preview.jpg" }
converted:run()
assert(vim.wait(5000, function() return converted:done() end, 10), "Image conversion timed out")
assert(converted:ready(), converted:error())
assert(vim.fn.filereadable(converted.file) == 1 and converted.file:match "%.png$", "Snacks did not convert JPEG to PNG")
assert(
  converted.meta.info.size.width == 8 and converted.meta.info.size.height == 8,
  "Image metadata was not read correctly"
)

vim.cmd.enew()
local markdown = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_name(markdown, project .. "/example.md")
vim.api.nvim_buf_set_lines(markdown, 0, -1, false, { "![Example](preview.jpg)", "", "Plain text" })
vim.bo.filetype = "markdown"
vim.treesitter.start(markdown, "markdown")
vim.treesitter.get_parser(markdown):parse(true)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
local resolved
snacks.image.doc.at_cursor(function(src) resolved = src end)
assert(vim.wait(2000, function() return resolved ~= nil end, 10), "Image link under the cursor was not detected")
assert(
  resolved == vim.uv.fs_realpath(project .. "/preview.jpg"),
  "Relative image link was not resolved: " .. tostring(resolved)
)
-- Verify automatic hover events without sending graphics to the headless terminal.
local hover, hovers = snacks.image.doc.hover, 0
snacks.image.doc.hover = function() hovers = hovers + 1 end
snacks.image.doc._attach(markdown)
assert(vim.wait(1000, function() return hovers > 0 end, 10), "Image hover did not attach")
local before = hovers
vim.api.nvim_win_set_cursor(0, { 3, 0 })
vim.api.nvim_exec_autocmds("CursorMoved", { buffer = markdown })
assert(vim.wait(1000, function() return hovers > before end, 10), "Cursor movement did not update image hover")
snacks.image.doc.hover = hover
vim.bo.modified = false
vim.cmd.enew()

local make_animation = opts.dashboard.sections[1]
assert(type(make_animation) == "function", "Dashboard palette should be resolved when it opens")
local saved_highlights = {}
for group, fg in pairs { Function = 0x112233, Type = 0x445566, Special = 0x778899 } do
  saved_highlights[group] = vim.api.nvim_get_hl(0, { name = group })
  vim.api.nvim_set_hl(0, group, { fg = fg })
end
local animation = make_animation()
for _, option in ipairs { "--rain-colors", "--final-gradient-stops" } do
  assert(
    animation.cmd:find(option .. " 112233 445566 778899", 1, true),
    "Rain and final logo must use the theme's Function, Type, and Special colours"
  )
end
vim.api.nvim_set_hl(0, "Function", { fg = 0xabcdef })
assert(
  make_animation().cmd:find("--rain-colors abcdef 445566 778899", 1, true),
  "Reopening the dashboard must pick up changed theme colours"
)
for group, hl in pairs(saved_highlights) do
  vim.api.nvim_set_hl(0, group, hl)
end
assert(animation.cmd:find("--frame-rate 375", 1, true), "Rain should run at the faster 375 fps rate")
assert(animation.section == "terminal" and animation.cmd:find("rain", 1, true), "Dashboard must use rain")
assert(animation.ttl == 0 and animation.height == 9, "Banner needs eight rows plus terminal setup space")
assert(not animation.cmd:find("--no-color", 1, true), "Rain should have colour enabled")
local effect_cmd = animation.cmd:gsub(" && read %-r _$", "")
assert(effect_cmd ~= animation.cmd, "Successful playback must wait quietly instead of printing an exit message")
local raw_frames = vim.fn.system(effect_cmd:gsub("%-%-frame%-rate %d+", "--frame-rate 0"))
assert(vim.v.shell_error == 0, "Rain command failed")
assert(raw_frames:find("\27[38;2;", 1, true), "Rain animation must emit colour codes")
local function animation_buffer(dashboard)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local conf = vim.api.nvim_win_get_config(win)
    local buf = vim.api.nvim_win_get_buf(win)
    if conf.relative == "win" and conf.win == dashboard.win and vim.bo[buf].buftype == "terminal" then return buf end
  end
end
local dashboard = snacks.dashboard()
local first_animation = assert(animation_buffer(dashboard), "Dashboard animation did not start")
local first_job = vim.b[first_animation].terminal_job_id
assert(first_job and vim.fn.jobwait({ first_job }, 0)[1] == -1, "Rain animation did not run")
local rendered = table.concat(vim.api.nvim_buf_get_lines(dashboard.buf, 0, -1, false), "\n")
for _, label in ipairs { "Neovim", "Find files", "Buffers", "Keymaps", "LazyGit", "Plugins" } do
  assert(rendered:find(label, 1, true), "Dashboard is missing " .. label)
end
assert(not rendered:find("Session", 1, true), "Dashboard should not advertise disabled session management")
feed "b"
assert(vim.wait(2000, function() return #snacks.picker.get() > 0 end, 10), "Dashboard buffer action did not work")
local picker = snacks.picker.get()[1]
assert(picker.opts.source == "buffers")
picker:close()
if dashboard.win and vim.api.nvim_win_is_valid(dashboard.win) then vim.api.nvim_win_close(dashboard.win, true) end
assert(
  vim.wait(1000, function() return vim.fn.jobwait({ first_job }, 0)[1] ~= -1 end, 10),
  "Closing the dashboard did not stop its animation"
)

dashboard = snacks.dashboard()
local animated_buf = assert(animation_buffer(dashboard), "Rain did not replay")
local animated_job = vim.b[animated_buf].terminal_job_id
local shell_pid = vim.fn.jobpid(animated_job)
assert(
  vim.wait(2000, function() return #vim.api.nvim_get_proc_children(shell_pid) > 0 end, 20),
  "Rain subprocess did not start"
)
assert(
  vim.wait(15000, function() return #vim.api.nvim_get_proc_children(shell_pid) == 0 end, 50),
  "Rain did not finish"
)
assert(vim.fn.jobwait({ animated_job }, 0)[1] == -1, "Terminal must wait quietly after successful playback")
local banner = vim.fn.system(effect_cmd:gsub(" | ttfx.*$", ""))
local expected_lines = vim.split(banner, "\n")
assert(
  #expected_lines == 8 and not banner:match "%]$",
  "Banner should preserve the supplied art without the paste artifact"
)
assert(
  vim.wait(1000, function()
    local win = vim.fn.win_findbuf(animated_buf)[1]
    local top = vim.api.nvim_win_call(win, vim.fn.winsaveview).topline
    local frame = vim.api.nvim_buf_get_lines(animated_buf, top - 1, top - 1 + vim.api.nvim_win_get_height(win), false)
    for start = 1, #frame - #expected_lines + 1 do
      local matches = true
      for i, line in ipairs(expected_lines) do
        if frame[start + i - 1]:gsub("%s+$", "") ~= line:gsub("%s+$", "") then
          matches = false
          break
        end
      end
      if matches then return true end
    end
    return false
  end, 10),
  "Rain final frame is clipped in the visible terminal window"
)
local completed_frame = table.concat(vim.api.nvim_buf_get_lines(animated_buf, 0, -1, false), "\n")
assert(not completed_frame:find("Process exited", 1, true), "Completed logo must not show process-exit text")
vim.api.nvim_win_close(dashboard.win, true)
assert(
  vim.wait(1000, function() return vim.fn.jobwait({ animated_job }, 0)[1] ~= -1 end, 10),
  "Closing the dashboard did not stop its waiting terminal"
)

local executable = vim.fn.executable
vim.fn.executable = function(name) return name == "ttfx" and 0 or executable(name) end
assert(not animation.enabled(), "Missing ttfx should use the static header")
local fallback = snacks.dashboard()
assert(not animation_buffer(fallback), "Static fallback should not launch a terminal")
vim.api.nvim_win_close(fallback.win, true)
vim.fn.executable = executable
local columns = vim.o.columns
vim.o.columns = opts.dashboard.width - 1
assert(not animation.enabled(), "Narrow terminals should use the compact header")
vim.o.columns = columns

vim.cmd.cd(project)
feed " gg"
local terminal = snacks.terminal.list()[1]
assert(terminal and terminal:valid(), "LazyGit shortcut did not open a terminal")
assert(vim.api.nvim_win_get_config(terminal.win).relative == "editor", "LazyGit must open in a float")
local job = vim.b[terminal.buf].terminal_job_id
assert(job and vim.fn.jobwait({ job }, 100)[1] == -1, "LazyGit exited instead of opening")
vim.api.nvim_chan_send(job, "q")
assert(vim.wait(3000, function() return vim.fn.jobwait({ job }, 0)[1] ~= -1 end, 10), "LazyGit did not quit")
print "PASS: scrolling, faster theme-coloured rain/final frame/replay/quiet completion/cleanup/fallbacks, buffers, images, and LazyGit"
