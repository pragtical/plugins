-- mod-version:3
local syntax = require "core.syntax"

local expression = { patterns = {}, symbols = {} }
local function string_contents(quote, escape)
  return {
    patterns = {
      { pattern = escape, type = "character.special" },
      { pattern = { "%${", "}" }, type = "keyword2", syntax = expression },
      { pattern = "%$[%a_][%w_]*[%.%w_]*", type = "keyword2" },
      { pattern = "[^$\\" .. quote .. "]+", type = "string" },
      { pattern = ".", type = "string" },
    },
    symbols = {},
  }
end

local groovy = {
  name = "Groovy",
  files = { "%.groovy$", PATHSEP .. "Jenkinsfile$" },
  comment = "//",
  block_comment = { "/*", "*/" },
  patterns = {
    { pattern = { '"""', '"""', '\\' }, type = "string", syntax = string_contents('"', "\\.") },
    { pattern = { "'''", "'''", '\\' }, type = "string" },
    { pattern = "//.*",                          type = "comment"  }, -- Single-line comment
    { pattern = { "/%*", "%*/" },                type = "comment"  }, -- Multi-line comment
    { pattern = { '"', '"', '\\' }, type = "string", syntax = string_contents('"', "\\.") },
    { pattern = { "'", "'", '\\' },              type = "string"   }, -- String, apices
    { pattern = { "%$%/", "%/%$", "$" }, type = "string", syntax = string_contents("/", "%$[$/]") },
    { regex = { [[/(?![/*])(?=(?:[^/\\\r\n]|\\.)+/\s*(?:[,;)}\].]|$))]], "/", "\\" }, type = "string", syntax = string_contents("/", "\\/") },
    { pattern = { "{", "}" }, type = "operator", syntax = expression },
    { pattern = "'\\x%x?%x?%x?%x'",              type = "string"   }, -- character hexadecimal escape sequence
    { pattern = "'\\u%x%x%x%x'",                 type = "string"   }, -- character unicode escape sequence
    { pattern = "'\\?.'",                        type = "string"   }, -- character literal
    { pattern = "-?0x%x+",                       type = "number"   }, -- ?
    { regex = "-?(?:\\d[\\d_]*\\.(?!\\.)[\\d_]*|\\.\\d[\\d_]*|\\d[\\d_]*)(?:[eE][+-]?\\d[\\d_]*)?[fFdDgGlLiI]?",
      type = "number"
    }, -- ?
    { pattern = "-?%.?%d+",                      type = "number"   }, -- ?
    { pattern = "-?[%d_+]+[a-zA-Z]?",            type = "number"   }, -- ?
    { pattern = "[%+%-=/%*%^%%<>!~|&]",          type = "operator" }, -- Operators
    { pattern = "[%a_][%w_]*%f[(]",              type = "function" }, -- Function/Class/Method/...
    { pattern = "[%a_][%w_]*%f[%[]",             type = "function" }, -- Custom Type
    { regex   = "[A-Z]+_?[A-Z]+",                type = "keyword2" }, -- Constants
    { pattern = "import()%s+()[%w_.]+",          type = { "keyword", "normal", "normal" } },
    { pattern = "[%a_][%w_]*",                   type = "symbol"   }, -- ?
    { pattern = "[a-zA-Z]+%.+",                  type = "function" }, -- Lib path
    -- TODO: .class.
  },
  symbols = {
    -- Reserved keywords
    ["abstract"]           = "keyword",
    ["assert"]             = "keyword",
    ["break"]              = "keyword",
    ["case"]               = "keyword",
    ["catch"]              = "keyword",
    ["class"]              = "keyword",
    ["const"]              = "keyword",
    ["continue"]           = "keyword",
    ["def"]                = "keyword",
    ["default"]            = "keyword",
    ["do"]                 = "keyword",
    ["else"]               = "keyword",
    ["enum"]               = "keyword",
    ["extends"]            = "keyword",
    ["final"]              = "keyword",
    ["finally"]            = "keyword",
    ["for"]                = "keyword",
    ["goto"]               = "keyword",
    ["if"]                 = "keyword",
    ["implements"]         = "keyword",
    ["import"]             = "keyword",
    ["instanceof"]         = "keyword",
    ["interface"]          = "keyword",
    ["native"]             = "keyword",
    ["new"]                = "keyword",
    ["non-sealed"]         = "keyword",
    ["package"]            = "keyword",
    ["public"]             = "keyword",
    ["protected"]          = "keyword",
    ["private"]            = "keyword",
    ["return"]             = "keyword",
    ["static"]             = "keyword",
    ["strictfp"]           = "keyword",
    ["super"]              = "keyword",
    ["switch"]             = "keyword",
    ["synchronized"]       = "keyword",
    ["this"]               = "keyword",
    ["threadsafe"]         = "keyword",
    ["throw"]              = "keyword",
    ["throws"]             = "keyword",
    ["transient"]          = "keyword",
    ["try"]                = "keyword",
    ["while"]              = "keyword",

    -- Contextual keywords
    ["as"]                 = "keyword",
    ["in"]                 = "keyword",
    ["permits"]            = "keyword",
    ["record"]             = "keyword",
    ["sealed"]             = "keyword",
    ["trait"]              = "keyword",
    ["var"]                = "keyword",
    ["yields"]             = "keyword",

    -- ?
    ["true"]               = "literal",
    ["false"]              = "literal",
    ["null"]               = "literal",
    ["boolean"]            = "literal",

    -- Types
    ["char"]               = "keyword",
    ["byte"]               = "keyword",
    ["short"]              = "keyword",
    ["int"]                = "keyword",
    ["long"]               = "keyword",
    ["float"]              = "keyword",
    ["double"]             = "keyword",

    ["Integer"]            = "keyword",
    ["BigInteger"]         = "keyword",
    ["Long"]               = "keyword",
    ["Float"]              = "keyword",
    ["BigDecimal"]         = "keyword",
    ["Double"]             = "keyword",
    ["String"]             = "keyword",
  },
}

expression.patterns, expression.symbols = groovy.patterns, groovy.symbols

syntax.add(groovy)
