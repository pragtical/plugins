-- mod-version:3
local syntax = require "core.syntax"
local expression = { patterns = {}, symbols = {} }
local function interpolated_string(escaped)
  local patterns = {
    { pattern = "%$%$", type = "string" },
    { pattern = { "%${", "}" }, type = "keyword2", syntax = expression },
    { pattern = "%$[%a_][%w_]*", type = "keyword2" },
    { pattern = escaped and '[^"$\\]+' or '[^"$]+', type = "string" },
    { pattern = ".", type = "string" },
  }
  if escaped then table.insert(patterns, 1, { pattern = "\\.", type = "character.special" }) end
  return { patterns = patterns, symbols = {} }
end

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "/%*", "%*/" }, type = "comment", syntax = block_comment },
  { pattern = "[^/%*]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

local scala = {
  name = "Scala",
  files = { "%.sc$", "%.scala$" },
  comment = "//",
  patterns = {
    { pattern = "//.*",                      type = "comment"  },
    { pattern = { "/%*", "%*/" },              type = "comment", syntax = block_comment  },
    { pattern = { '[%a_][%w_]*"""', '"""' }, type = "string", syntax = interpolated_string(false) },
    { pattern = { 'raw"', '"', '\\' }, type = "string", syntax = interpolated_string(false) },
    { pattern = { '[%a_][%w_]*"', '"', '\\' }, type = "string", syntax = interpolated_string(true) },
    { pattern = { '"""', '"""' },            type = "string"   },
    { pattern = { '"', '"', '\\' },          type = "string"   },
    { pattern = { "[ruU]?'", "'", '\\' },      type = "string"   },
    { pattern = { "{", "}" }, type = "normal", syntax = expression },
    { pattern = "0x[%da-fA-F]+",               type = "number"   },
    { regex = "-?(?:\\d+\\.(?!\\.)\\d*|\\.\\d\\d*|\\d+)(?:[eE][+-]?\\d+)?",              type = "number"   },
    { pattern = "-?%.?%d+",                    type = "number"   },
    { pattern = "[%+%-=/%*%^%%<>!~|&]",        type = "operator" },
    { pattern = "[%a_][%w_]*%f[(]",              type = "function" },
    { pattern = "[%a_][%w_]*",                   type = "symbol"   },
  },
  symbols = {
    ["abstract"] = "keyword",
    ["case"]     = "keyword",
    ["catch"]    = "keyword",
    ["class"]    = "keyword",
    ["finally"]  = "keyword",
    ["final"]    = "keyword",
    ["do"]       = "keyword",
    ["extends"]  = "keyword",
    ["forSome"]  = "keyword",
    ["implicit"] = "keyword",
    ["lazy"]     = "keyword",
    ["match"]    = "keyword",
    ["new"]      = "keyword",
    ["override"] = "keyword",
    ["package"]  = "keyword",
    ["throw"]    = "keyword",
    ["trait"]    = "keyword",
    ["type"]     = "keyword",
    ["var"]      = "keyword",
    ["val"]      = "keyword",
    ["println"]  = "keyword",
    ["return"]   = "keyword",
    ["for"]      = "keyword",
    ["Try"]      = "keyword",
    ["def"]      = "keyword",
    ["while"]    = "keyword",
    ["with"]     = "keyword",
    ["if"]       = "keyword",
    ["else"]     = "keyword",
    ["import"]   = "keyword",
    ["object"]   = "keyword",
    ["yield"]    = "keyword",

    ["private"]   = "keyword2",
    ["protected"] = "keyword2",
    ["sealed"]    = "keyword2",
    ["super"]     = "keyword2",
    ["this"]      = "keyword2",
    ["Byte"]      = "keyword2",
    ["Short"]     = "keyword2",
    ["Int"]       = "keyword2",
    ["Long"]      = "keyword2",
    ["Float"]     = "keyword2",
    ["Double"]    = "keyword2",
    ["Char"]      = "keyword2",
    ["String"]    = "keyword2",
    ["List"]      = "keyword2",
    ["Array"]     = "keyword2",
    ["Boolean"]   = "keyword2",

    ["Null"]     = "literal",
    ["Any"]      = "literal",
    ["AnyRef"]   = "literal",
    ["Nothing"]  = "literal",
    ["Unit"]     = "literal",
    ["true"]     = "literal",
    ["false"]    = "literal",
  }
}

expression.patterns, expression.symbols = scala.patterns, scala.symbols

syntax.add(scala)
