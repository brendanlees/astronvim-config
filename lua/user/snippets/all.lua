local ls = require "luasnip"
local s = ls.snippet
local f = ls.function_node

return {
  -- Example: type 'date' then Tab to insert today's date
  s("date", f(function() return os.date "%Y-%m-%d" end)),
}
