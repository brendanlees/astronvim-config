local M = {}
local groups

local function highlights()
  local rainbow = require "indent-rainbowline"
  groups = {}
  for _, kind in ipairs { "indent", "whitespace", "scope" } do
    groups[kind] = rainbow.make_hl_groups {
      hl = { "@markup.raw.block.markdown", kind == "scope" and "IblScope" or "IblIndent", "Normal" },
      prefix = "MarkdownRainbow" .. kind,
      -- The default 7% tint disappears against the lighter fenced-block surface.
      color_transparency = 0.20,
    }
  end
end

function M.setup()
  local hooks = require "ibl.hooks"
  highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("markdown_rainbow_indents", { clear = true }),
    callback = highlights,
  })
  hooks.register(hooks.type.VIRTUAL_TEXT, function(_, buf, row, chunks)
    if vim.bo[buf].filetype ~= "markdown" or vim.bo[buf].buftype ~= "" then return chunks end
    local ns = vim.api.nvim_get_namespaces().markdown_code_background
    if not ns then return chunks end
    -- Reuse the shaded fence ranges, including blank lines, rather than parse every indent.
    local blocks = vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, 0 }, {
      overlap = true,
      details = true,
    })
    local inside = false
    for _, block in ipairs(blocks) do
      if block[2] <= row and row < block[4].end_row then inside = true end
    end
    if not inside then return chunks end
    local source = require "ibl.highlights"
    local replacements = {}
    for kind, names in pairs(groups) do
      for i, hl in ipairs(source[kind]) do
        replacements[hl.char] = names[(i - 1) % #names + 1]
      end
    end
    for _, chunk in ipairs(chunks) do
      if type(chunk[2]) == "table" then
        for i, name in ipairs(chunk[2]) do
          chunk[2][i] = replacements[name] or name
        end
      else
        chunk[2] = replacements[chunk[2]] or chunk[2]
      end
    end
    return chunks
  end)
end

return M
