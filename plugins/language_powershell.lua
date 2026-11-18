-- mod-version:3
local syntax = require "core.syntax"

local expression = { patterns = {}, symbols = {} }
local string_contents = {
  patterns = {
    { pattern = "`.", type = "character.special" },
    { pattern = { "%$%(", "%)" }, type = "keyword2", syntax = expression },
    { pattern = "%${[^}\n]+}", type = "keyword2" },
    { pattern = "%$[%a_][%w_:]*", type = "keyword2" },
    { pattern = "%$[?%^$]", type = "keyword2" },
    { pattern = '[^"$`]+', type = "string" },
    { pattern = ".", type = "string" },
  },
  symbols = {},
}

local powershell = {
  name = "PowerShell",
  files = {
    "%.ps1$", "%.psm1$", "%.psd1$", "%.ps1xml$",
    "%.pssc$", "%.psrc$", "%.cdxml$"
  },
  comment = "#",
  patterns = {
    { pattern = { "<#", "#>" }, type = "comment" },
    {pattern = "#.*", type = "comment"},
    { pattern = { '@"[ \t]*\n', '^"@' }, type = "string", syntax = string_contents },
    { pattern = { "@'[ \t]*\n", "^'@" }, type = "string" },
    { pattern = { '"', '"', '`' }, type = "string", syntax = string_contents },
    {pattern = {"'", "'"}, type = "string"},
    { pattern = { "%(", "%)" }, type = "normal", syntax = expression },
    { regex = [[\$(?i:true|false|null)\b]], type = "literal" },
    { pattern = "`.", type = "character.special" },
    { pattern = "0[xX]%x+", type = "number" },
    { regex = [[(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?]], type = "number" },
    {pattern = "%f[%w_][%d%.]+%f[^%w_]", type = "number"},
    {pattern = "[%+=/%*%^%%<>!~|&,:]+", type = "operator"},
    {pattern = "%f[%S]%-[%w%-_]+", type = "function"},
    {pattern = "[%u][%a]+[%-][%u][%a]+", type = "function"},
    {pattern = "${.*}", type = "symbol"},
    {pattern = "$[%a_@*][%w_]*", type = "keyword2"},
    {pattern = "$[%$][%a]+", type = "keyword2"},
    {pattern = "[%a_][%w_]*", type = "symbol"}
  },
  symbols = {
    ["if"] = "keyword",
    ["else"] = "keyword",
    ["elseif"] = "keyword",
    ["switch"] = "keyword",
    ["default"] = "keyword",
    ["function"] = "keyword",
    ["filter"] = "keyword",
    ["workflow"] = "keyword",
    ["configuration"] = "keyword",
    ["class"] = "keyword",
    ["enum"] = "keyword",
    ["Parameter"] = "keyword",
    ["ValidateScript"] = "keyword",
    ["CmdletBinding"] = "keyword",
    ["try"] = "keyword",
    ["catch"] = "keyword",
    ["finally"] = "keyword",
    ["throw"] = "keyword",
    ["while"] = "keyword",
    ["for"] = "keyword",
    ["do"] = "keyword",
    ["until"] = "keyword",
    ["break"] = "keyword",
    ["continue"] = "keyword",
    ["foreach"] = "keyword",
    ["in"] = "keyword",
    ["return"] = "keyword",
    ["where"] = "function",
    ["select"] = "function",
    ["filter"] = "keyword",
    ["in"] = "keyword",
    ["trap"] = "keyword",
    ["param"] = "keyword",
    ["data"] = "keyword",
    ["dynamicparam"] = "keyword",
    ["begin"] = "function",
    ["process"] = "function",
    ["end"] = "function",
    ["exit"] = "function",
    ["inlinescript"] = "function",
    ["parallel"] = "function",
    ["sequence"] = "function",
    ["true"] = "literal",
    ["false"] = "literal",
    ["TODO"] = "comment",
    ["FIXME"] = "comment",
    ["XXX"] = "comment",
    ["TBD"] = "comment",
    ["HACK"] = "comment",
    ["NOTE"] = "comment"
  }
}

expression.patterns, expression.symbols = powershell.patterns, powershell.symbols

syntax.add(powershell)
