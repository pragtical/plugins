-- mod-version:3
local syntax = require "core.syntax"

local expression = { patterns = {}, symbols = {} }
local array_index = { patterns = {}, symbols = {} }
local substitutions = {
  { pattern = "\\.", type = "character.special" },
  { pattern = { "%[", "%]" }, type = "operator", syntax = expression },
  { pattern = "%${[^}]+}", type = "literal" },
  { pattern = { "%$[%w_:]*%(", "%)" }, type = "literal", syntax = array_index },
  { pattern = "%$[%w_:]+", type = "literal" },
}
for _, rule in ipairs(substitutions) do array_index.patterns[#array_index.patterns + 1] = rule end
array_index.patterns[#array_index.patterns + 1] = { pattern = { "%(", "%)" }, type = "literal", syntax = array_index }
array_index.patterns[#array_index.patterns + 1] = { pattern = "[^()$%[\\]+", type = "literal" }
array_index.patterns[#array_index.patterns + 1] = { pattern = ".", type = "literal" }
local quoted = { patterns = {}, symbols = {} }
for _, rule in ipairs(substitutions) do quoted.patterns[#quoted.patterns + 1] = rule end
quoted.patterns[#quoted.patterns + 1] = { pattern = '[^"$%[\\]+', type = "string" }
quoted.patterns[#quoted.patterns + 1] = { pattern = ".", type = "string" }

local tcl = {
  name = "Tcl",
  files = { "%.tcl$" },
  comment = "#",
  patterns = {
    { pattern = "#.*",                 type = "comment" },
    { pattern = { '"', '"', '\\' }, type = "string", syntax = quoted },
    { pattern = "0x%x+",                 type = "number"  },
    { regex = "(?:\\d+\\.(?!\\.)\\d*|\\.\\d\\d*|\\d+)(?:[eE][+-]?\\d+)?f?",        type = "number"  },
    { pattern = "%.?%d+f?",              type = "number"  },
    { pattern = "[%+%-=/%*%^%%<>!~|&]",  type = "operator" },
    { pattern = "::[%a_][%w_]*",         type = "function" },
    { pattern = "[%a_][%w_]*%f[:]",      type = "function" },
    { pattern = "[%a_][%w_]*",           type = "symbol" },
  },
  symbols = {
    ["set"]       = "keyword",
    ["unset"]       = "keyword",
    ["rename"]       = "keyword",
    ["upvar"]     = "keyword",
    ["incr"]      = "keyword",
    ["source"]     = "keyword",
    ["expr"]     = "keyword",
    ["gets"]     = "keyword",
    ["puts"]     = "keyword",
    ["package"]   = "keyword",
    ["list"]   = "keyword",
    ["dict"]   = "keyword",
    ["split"]    = "keyword",
    ["join"]     = "keyword",
    ["lappend"]   = "keyword",
    ["lset"]   = "keyword",
    ["lassign"]   = "keyword",
    ["lindex"]   = "keyword",
    ["llength"]  = "keyword",
    ["lsearch"]   = "keyword",
    ["lrange"]   = "keyword",
    ["linsert"] = "keyword",
    ["lreplace"] = "keyword",
    ["lrepeat"] = "keyword",
    ["lsort"]   = "keyword",
    ["lreverse"]   = "keyword",
    ["array"]   = "keyword",
    ["concat"]   = "keyword",
    ["regexp"]   = "keyword",
    ["for"]       = "keyword",
    ["foreach"]       = "keyword",
    ["while"]     = "keyword",
    ["case"]     = "keyword",
    ["proc"]     = "keyword",
    ["if"]    = "keyword",
    ["else"]      = "keyword",
    ["elseif"]      = "keyword",
    ["break"]    = "keyword",
    ["continue"] = "keyword",
    ["return"]   = "keyword",
    ["eval"]   = "keyword",
    ["try"]      = "keyword2",
    ["on"]      = "keyword2",
    ["finally"]      = "keyword2",
    ["throw"]    = "keyword2",
    ["error"]    = "keyword2",
  },
}
for i = #substitutions, 1, -1 do table.insert(tcl.patterns, 1, substitutions[i]) end

expression.patterns, expression.symbols = tcl.patterns, tcl.symbols

syntax.add(tcl)
