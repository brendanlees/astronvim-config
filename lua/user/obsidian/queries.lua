local M = {}
local source_ns = vim.api.nvim_create_namespace "obsidian_query_source"
local source_query

local function clear_source(ctx) vim.api.nvim_buf_clear_namespace(ctx.buf, source_ns, 0, -1) end

local function render_source(ctx)
  clear_source(ctx)
  local root = vim.treesitter.get_parser(ctx.buf, "markdown"):parse()[1]:root()
  source_query = source_query
    or vim.treesitter.query.parse(
      "markdown",
      [[
        (fenced_code_block
          (info_string (language) @language)
          (#any-of? @language "dataview" "dataviewjs")) @block
      ]]
    )
  local cursor = vim.api.nvim_get_current_buf() == ctx.buf and vim.api.nvim_win_get_cursor(ctx.win)[1] - 1
  for _, match in source_query:iter_matches(root, ctx.buf) do
    local block, language
    for id, nodes in pairs(match) do
      if source_query.captures[id] == "block" then
        block = nodes[1]
      else
        language = vim.treesitter.get_node_text(nodes[1], ctx.buf)
      end
    end
    local first, _, last, col = block:range()
    if col > 0 then last = last + 1 end
    if not cursor or cursor < first or cursor >= last then
      if language == "dataviewjs" then
        vim.api.nvim_buf_set_extmark(ctx.buf, source_ns, first, 0, {
          -- Whole-line concealment includes end_row; Tree-sitter ranges exclude it.
          end_row = last - 1,
          end_col = 0,
          conceal_lines = "",
        })
      else
        local closing = block:named_child(block:named_child_count() - 1)
        -- Leave incomplete queries visible while their closing fence is being written.
        if closing:type() == "fenced_code_block_delimiter" and closing:start() > first then
          vim.api.nvim_buf_set_extmark(ctx.buf, source_ns, first, 0, {
            end_row = last - 2,
            end_col = 0,
            conceal_lines = "",
          })
          local line = vim.api.nvim_buf_get_lines(ctx.buf, last - 1, last, false)[1]
          vim.api.nvim_buf_set_extmark(ctx.buf, source_ns, last - 1, 0, {
            end_row = last - 1,
            end_col = #line,
            conceal = "",
            virt_text = { { "Dataview (Enter: results)", "Comment" } },
            virt_text_pos = "overlay",
          })
        end
      end
    end
  end
end

function M.setup()
  -- Results above the visible closing/summary line survive adjacent hidden blocks and EOF.
  -- Using the plugin's helper also keeps its mouse hit-testing aligned with the display.
  require("obsidian-query.render").anchored_mark = function(block, _, lines)
    local _, _, last, col = block:range()
    return {
      conceal = false,
      start_row = col == 0 and last - 1 or last,
      start_col = 0,
      opts = { virt_lines = lines, virt_lines_above = true, virt_lines_overflow = "scroll" },
    }
  end
end

function M.render_options()
  return {
    -- Only query output is new; Obsidian and our existing helpers own note styling.
    custom_handlers = {
      markdown = { parse = require("obsidian-query").parse },
      markdown_inline = { parse = require("obsidian-query.inline").parse },
    },
    -- Run on cursor-only redraws too, so entering any part of a block reveals all its source.
    on = { render = render_source, clear = clear_source },
    html = { enabled = false },
    latex = { enabled = false },
    yaml = { enabled = false },
    nested = false,
    patterns = { markdown = { disable = false } },
    ignore = function(buf) return vim.bo[buf].buftype ~= "" or not require("obsidian-query").buf_root(buf) end,
    win_options = { conceallevel = { default = 2, rendered = 2 } },
  }
end

function M.attach()
  vim.keymap.set("n", "<CR>", function()
    local query = require "obsidian-query"
    if query.cursor_in_query() then
      query.open_picker()
    else
      require("user.markdown.folding").toggle_fold()
    end
  end, { buffer = true, desc = "Query results / toggle fold" })
end

return M
