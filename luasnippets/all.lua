local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node

return {
  -- Example: type 'date' then Tab to insert today's date
  s("date", f(function() return os.date("%Y-%m-%d") end)),
}
