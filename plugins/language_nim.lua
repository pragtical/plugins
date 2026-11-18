-- mod-version:3
local syntax = require "core.syntax"

local expression = { patterns = {}, symbols = {} }

local patterns = {}

local symbols = {
  ["nil"] = "literal",
  ["true"] = "literal",
  ["false"] = "literal",
}

local number_patterns = {
  "0[bB][01][01_]*",
  "0o[0-7][0-7_]*",
  "0[xX]%x[%x_]*",
  "%d[%d_]*%.%d[%d_]*[eE][-+]?%d[%d_]*",
  "%d[%d_]*%.%d[%d_]*",
  "%d[%d_]*",
}

local type_suffix_patterns = {}

for _, size in ipairs({"64", "32", "16", "8", ""}) do
  table.insert(type_suffix_patterns, "'?[fuiFUI]"..size)
end

for _, pattern in ipairs(number_patterns) do
  for _, suffix in ipairs(type_suffix_patterns) do
    table.insert(patterns, { pattern = pattern..suffix, type = "literal" })
  end
  table.insert(patterns, { pattern = pattern, type = "literal" })
end

local keywords = {
  "addr", "and", "as", "asm",
  "bind", "block", "break",
  "case", "cast", "concept", "const", "continue", "converter",
  "defer", "discard", "distinct", "div", "do",
  "elif", "else", "end", "enum", "except", "export",
  "finally", "for", "from", "func",
  "if", "import", "in", "include", "interface", "is", "isnot", "iterator",
  "let",
  "macro", "method", "mixin", "mod",
  "not", "notin",
  "object", "of", "or", "out",
  "proc", "ptr",
  "raise", "ref", "return",
  "shl", "shr", "static",
  "template", "try", "tuple", "type",
  "using",
  "var",
  "when", "while",
  "xor",
  "yield",
}

for _, keyword in ipairs(keywords) do
  symbols[keyword] = "keyword"
end

local standard_types = {
  "bool", "byte",
  "int", "int8", "int16", "int32", "int64",
  "uint", "uint8", "uint16", "uint32", "uint64",
  "float", "float32", "float64",
  "char", "string", "cstring",
  "pointer",
  "typedesc",
  "void", "auto", "any",
  "untyped", "typed",
  "clong", "culong", "cchar", "cschar", "cshort", "cint", "csize", "csize_t",
  "clonglong", "cfloat", "cdouble", "clongdouble", "cuchar", "cushort",
  "cuint", "culonglong", "cstringArray",
}

for _, type in ipairs(standard_types) do
  symbols[type] = "keyword2"
end

local standard_generic_types = {
  "range",
  "array", "open[aA]rray", "varargs", "seq", "set",
  "sink", "lent", "owned",
}

for _, type in ipairs(standard_generic_types) do
  table.insert(patterns, { pattern = type.."%f[%[]", type = "keyword2" })
  table.insert(patterns, { pattern = type.." +%f[%w]", type = "keyword2" })
end

local function string_pattern(start, stop, syntax, raw)
  return {
    pattern = { start, stop, not raw and '\\' or nil },
    type    = "string",
    syntax  = syntax and {
      patterns = syntax,
      symbols  = {},
    } or nil
  }
end

local function interpolation_syntax(escaped)
  local contents = {
  { pattern = "{{", type = "string" },
  { pattern = "}}", type = "string" },
  { pattern = { '{', '}' }, type = "keyword2", syntax = expression },
  { pattern = '[^{}"\\]+', type = "string" },
  { pattern = ".", type = "string" },
  }
  if escaped then table.insert(contents, 1, { pattern = "\\.", type = "character.special" }) end
  return contents
end

local block_comment = { patterns = {}, symbols = {} }
local doc_comment = { patterns = {}, symbols = {} }
local comment_patterns = {
  { pattern = { "##%[", "%]##" }, type = "comment", syntax = doc_comment },
  { pattern = { "#%[", "%]#" }, type = "comment", syntax = block_comment },
  { pattern = "[^#%[%]]+", type = "comment" },
  { pattern = ".", type = "comment" },
}
block_comment.patterns, doc_comment.patterns = comment_patterns, comment_patterns

local user_patterns = {
  -- comments
  comment_patterns[1],
  comment_patterns[2],
  { pattern = "##?.*",                      type = "comment" },
  -- strings and chars
  { pattern = "\\[{}]", type = "character.special" },
  { pattern = { "{", "}" }, type = "operator", syntax = expression },
  { pattern = { "'", "'", '\\' },             type = "literal" },
  { pattern = { '[rR]"', '"' }, type = "string" },
  string_pattern('"""', '"""%f[^"]', nil, true),
  string_pattern('"'  , '"'        ),
  string_pattern('\\"', '\\"'      ), -- For highlighting strings inside iterpolated blocks
  -- string interpolation
  string_pattern('%&"""' , '"""%f[^"]', interpolation_syntax(false), true),
  string_pattern('fmt"""', '"""%f[^"]', interpolation_syntax(false), true),
  string_pattern('%&"'   , '"'        , interpolation_syntax(true)),
  string_pattern('fmt"'  , '"'        , interpolation_syntax(false), true),
  -- function calls
  { pattern = "[a-zA-Z][a-zA-Z0-9_]*%f[(]",   type = "function" },
  -- identifiers
  { pattern = "[A-Z][a-zA-Z0-9_]*",           type = "keyword2" },
  { pattern = "[a-zA-Z][a-zA-Z0-9_]*",        type = "symbol" },
  -- operators
  { pattern = "%.%f[^.]",                     type = "normal" },
  { pattern = ":%f[ ]",                       type = "normal" },
  { pattern = "[=+%-*/<>@$~&%%|!?%^&.:\\]+",  type = "operator" },
}

for _, pattern in ipairs(user_patterns) do
  table.insert(patterns, pattern)
end

expression.patterns, expression.symbols = patterns, symbols

syntax.add {
  name = "Nim",
  files = { "%.nim$", "%.nims$", "%.nimble$" },
  comment = "#",
  patterns = patterns,
  symbols = symbols,
}
