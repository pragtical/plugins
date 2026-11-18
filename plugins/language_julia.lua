-- mod-version:3
-- Support for the Julia programming language:
-- Covers the most used keywords up to Julia version 1.6.4
local syntax = require "core.syntax"

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "#=", "=#" }, type = "comment", syntax = block_comment },
  { pattern = "[^#=]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

local expression = { patterns = {}, symbols = {} }
local interpolated_string = {
  patterns = {
    { pattern = "\\.", type = "character.special" },
    { pattern = { "%$%(", "%)" }, type = "keyword2", syntax = expression },
    { pattern = "%$[%a_][%w_]*", type = "keyword2" },
    { pattern = '[^"$\\]+', type = "string" },
    { pattern = ".", type = "string" },
  },
  symbols = {},
}

local julia = {
  name = "Julia",
  files = { "%.jl$" },
  comment = "#",
  patterns = {
    {pattern = {"#=", "=#"},            type = "comment", syntax = block_comment    },
    {pattern = "#.*$",                  type="comment"    },
    { pattern = { 'icxx"""', '"""' },     type = "string", syntax = ".cpp" },
    { pattern = { 'cxx"""', '"""' },     type = "string", syntax = ".cpp" },
    { pattern = { 'py"""', '"""' },     type = "string", syntax = ".py" },
    { pattern = { 'js"""', '"""' },     type = "string", syntax = ".js" },
    { pattern = { 'md"""', '"""' },     type = "string", syntax = ".md" },
    { pattern = "0[oO_][0-7]+",         type = "number"   },
    { pattern = "-?0x[%x_]+",           type = "number"   },
    { pattern = "-?0b[%x_]+",           type = "number"   },
    { pattern = "-?%d+_%d",             type = "number"   },
    { regex = "-?(?:\\d+\\.(?!\\.)\\d*|\\.\\d\\d*|\\d+)(?:[eE][+-]?\\d+)?f?",     type = "number"   },
    { pattern = "-?%.?%d+f?",           type = "number"   },
    { pattern = "[^%d%g]%:%a*",         type = "function" },
    { pattern = "[%+%-=/%*%^%%<>!~|&%:]",type = "operator"},
    { pattern = { '[%a_][%w_]*"""', '"""', '\\' }, type = "string" },
    { pattern = { '[%a_][%w_]*"', '"', '\\' }, type = "string" },
    { pattern = { '"""', '"""', '\\' }, type = "string", syntax = interpolated_string },
    { pattern = { '"', '"', '\\' }, type = "string", syntax = interpolated_string },
    { pattern = { "%(", "%)" }, type = "normal", syntax = expression },
    { pattern = "'\\.*'",   type = "string" },
    { pattern = "'.'",      type = "string" },
    { pattern = "[%a_][%w_]*%f[(]",       type = "function" },
    { pattern = "%g*!",                    type="function"},
    { pattern = "[%a_][%w_]*",            type = "symbol"   },
  },
  symbols = {
    -- keywords
    ["baremodule"]        = "keyword",
    ["begin"]             = "keyword",
    ["break"]             = "keyword",
    ["catch"]             = "keyword",
    ["const"]             = "keyword",
    ["continue"]          = "keyword",
    ["do"]                = "keyword",
    ["Dict"]              = "keyword",
    ["Set"]               = "keyword",
    ["Union"]             = "keyword",
    ["else"]              = "keyword",
    ["elseif"]            = "keyword",
    ["end"]               = "keyword",
    ["export"]            = "keyword",
    ["finally"]           = "keyword",
    ["for"]               = "keyword",
    ["function"]          = "keyword",
    ["global"]            = "keyword",
    ["if"]                = "keyword",
    ["in"]                = "keyword",
    ["import"]            = "keyword",
    ["let"]               = "keyword",
    ["local"]             = "keyword",
    ["macro"]             = "keyword",
    ["type"]              = "keyword",
    ["module"]            = "keyword",
    ["mutable"]           = "keyword",
    ["quote"]             = "keyword",
    ["return"]            = "keyword",
    ["try"]               = "keyword",
    ["typeof"]            = "keyword",
    ["using"]             = "keyword",
    ["while"]             = "keyword",
    ["where"]             = "keyword",

    -- types
    ["struct"]            = "keyword2",
    ["abstract"]          = "keyword2",
    ["primitive"]         = "keyword2",
    ["mutable"]           = "keyword2",
    ["Char"]              = "keyword2",
    ["Bool"]              = "keyword2",
    ["Int"]               = "keyword2",
    ["Integer"]           = "keyword2",
    ["Int8"]              = "keyword2",
    ["UInt8"]             = "keyword2",
    ["Int16"]             = "keyword2",
    ["UInt16"]            = "keyword2",
    ["Int32"]             = "keyword2",
    ["UInt32"]            = "keyword2",
    ["Int64"]             = "keyword2",
    ["UInt64"]            = "keyword2",
    ["Int128"]            = "keyword2",
    ["UInt128"]           = "keyword2",
    ["Float16"]           = "keyword2",
    ["Float32"]           = "keyword2",
    ["Float64"]           = "keyword2",
    ["Vector"]            = "keyword2",
    ["Matrix"]            = "keyword2",
    ["Ref"]               = "keyword2",
    ["String"]            = "keyword2",
    ["Function"]          = "keyword2",
    ["Number"]            = "keyword2",

    -- literals
    ["missing"]          = "literal",
    ["true"]             = "literal",
    ["false"]            = "literal",
    ["nothing"]          = "literal",
    ["Inf"]              = "literal",
    ["NaN"]              = "literal",
  }
}

expression.patterns, expression.symbols = julia.patterns, julia.symbols

syntax.add(julia)
