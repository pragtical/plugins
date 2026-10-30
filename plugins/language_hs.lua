-- mod-version:3
local syntax = require "core.syntax"

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "{%-", "%-}" }, type = "comment", syntax = block_comment },
  { pattern = "[^{}%-]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

syntax.add {
  name = "Haskell",
  files = { "%.hs$" },
  comment = "--",
  block_comment = {"{-", "-}"},
  patterns = {
    { pattern = "%-%-.*",               type = "comment"  },
    { pattern = { "{%-", "%-}" },       type = "comment", syntax = block_comment  },
    { pattern = { '"', '"', '\\' },     type = "string"   },
    { pattern = "'\\.'",                type = "string"   },
    { pattern = "'\\[^'\n]+'",          type = "string"   },
    { pattern = "'[^'\\\n]'",           type = "string"   },
    { pattern = "-?0x%x+",              type = "number"   },
    { regex = "-?(?:\\d+\\.(?!\\.)\\d*|\\.\\d\\d*|\\d+)(?:[eE][+-]?\\d+)?f?",
      type = "number"
    },
    { pattern = "-?%.?%d+f?",           type = "number"   },
    { pattern = "[!%#%$%%&*+./%<=>%?@\\%^|%-~:]", type = "operator" },
    { pattern = "[%a_'][%w_']*",        type = "symbol"   },
  },
  symbols = {
    ["as"] = "keyword",
    ["case"] = "keyword",
    ["of"] = "keyword",
    ["class"] = "keyword",
    ["data"] = "keyword",
    ["default"] = "keyword",
    ["deriving"] = "keyword",
    ["do"] = "keyword",
    ["forall"] = "keyword",
    ["foreign"] = "keyword",
    ["hiding"] = "keyword",
    ["if"] = "keyword",
    ["then"] = "keyword",
    ["else"] = "keyword",
    ["import"] = "keyword",
    ["infix"] = "keyword",
    ["infixl"] = "keyword",
    ["infixr"] = "keyword",
    ["let"] = "keyword",
    ["in"] = "keyword",
    ["mdo"] = "keyword",
    ["module"] = "keyword",
    ["newtype"] = "keyword",
    ["qualified"] = "keyword",
    ["type"] = "keyword",
    ["where"] = "keyword",
  },
}
