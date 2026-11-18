-- mod-version:3
local syntax = require "core.syntax"

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "/%*", "%*/" }, type = "comment", syntax = block_comment },
  { pattern = "[^/%*]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

local expression = { patterns = {}, symbols = {} }
local function string_contents(quote, raw)
  local patterns = {}
  if not raw then
    patterns = {
      { pattern = { "%${", "}" }, type = "keyword2", syntax = expression },
      { pattern = "%$[%a_][%w_]*", type = "keyword2" },
      { pattern = "\\.", type = "character.special" },
    }
  end
  patterns[#patterns + 1] = {
    pattern = "[^" .. quote .. (raw and "" or "$\\") .. "]+",
    type = "string"
  }
  patterns[#patterns + 1] = { pattern = ".", type = "string" }
  return { patterns = patterns, symbols = {} }
end

local dart = {
  name = "Dart",
  files = { "%.dart$" },
  comment = "//",
  patterns = {
    { pattern = "//.*",                     type = "comment"  },
    { pattern = { "/%*", "%*/" },           type = "comment", syntax = block_comment  },
    { pattern = { 'r"""', '"""' },
      type = "string",
      syntax = string_contents('"', true)
    },
    { pattern = { "r'''", "'''" },
      type = "string",
      syntax = string_contents("'", true)
    },
    { pattern = { 'r"', '"' },
      type = "string",
      syntax = string_contents('"', true)
    },
    { pattern = { "r'", "'" },
      type = "string",
      syntax = string_contents("'", true)
    },
    { pattern = { '"""', '"""', '\\' },
      type = "string",
      syntax = string_contents('"')
    },
    { pattern = { "'''", "'''", '\\' },
      type = "string",
      syntax = string_contents("'")
    },
    { pattern = { '"', '"', '\\' },
      type = "string",
      syntax = string_contents('"')
    },
    { pattern = { "'", "'", '\\' },
      type = "string",
      syntax = string_contents("'")
    },
    { pattern = { "{", "}" }, type = "normal", syntax = expression },
    { pattern = "-?0x%x+",                  type = "number"   },
    { regex = "-?(?:\\d+\\.(?!\\.)\\d*|\\.\\d+|\\d+)(?:[eE][+-]?\\d+)?",
      type = "number"
    },
    { pattern = "[%+%-=/%*%^%%<>!~|&]",     type = "operator" },
    { pattern = "%?%?",                     type = "operator" },
    { pattern = "%?%.",                     type = "operator" },
    { pattern = "[%a_][%w_]*%f[(]",         type = "function" },
    { pattern = "[%a_][%w_]*",              type = "symbol"   },
  },
  symbols = {
    ["abstract"] = "keyword",
    ["as"] = "keyword",
    ["assert"] = "keyword",
    ["async"] = "keyword",
    ["extends"] = "keyword",
    ["extension"] = "keyword",
    ["external"] = "keyword",
    ["implements"] = "keyword",
    ["import"] = "keyword",
    ["is"] = "keyword",
    ["late"] = "keyword",
    ["mixin"] = "keyword",
    ["on"] = "keyword",
    ["required"] = "keyword",
    ["rethrow"] = "keyword",
    ["super"] = "keyword",
    ["var"] = "keyword",
    ["with"] = "keyword",
    ["yield"] = "keyword",
    ["await"]    = "keyword",
    ["bool"]     = "keyword2",
    ["break"]    = "keyword",
    ["case"]     = "keyword",
    ["class"]    = "keyword",
    ["const"]    = "keyword",
    ["continue"] = "keyword",
    ["default"]  = "keyword",
    ["do"]       = "keyword",
    ["double"]   = "keyword2",
    ["dynamic"]  = "keyword2",
    ["else"]     = "keyword",
    ["enum"]     = "keyword",
    ["false"]    = "literal",
    ["final"]    = "keyword",
    ["finally"]  = "keyword",
    ["for"]      = "keyword",
    ["Function"] = "keyword2",
    ["if"]       = "keyword",
    ["in"]       = "keyword",
    ["int"]      = "keyword2",
    ["List"]     = "keyword2",
    ["Map"]      = "keyword2",
    ["new"]      = "keyword",
    ["null"]     = "literal",
    ["part of"]  = "keyword",
    ["print"]    = "keyword",
    ["return"]   = "keyword",
    ["static"]   = "keyword",
    ["String"]   = "keyword2",
    ["switch"]   = "keyword",
    ["then"]     = "keyword",
    ["this"]     = "keyword2",
    ["true"]     = "literal",
    ["void"]     = "keyword",
    ["while"]    = "keyword",
  },
}

expression.patterns, expression.symbols = dart.patterns, dart.symbols

syntax.add(dart)
