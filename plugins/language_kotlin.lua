-- mod-version:3
local syntax = require "core.syntax"

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "/%*", "%*/" }, type = "comment", syntax = block_comment },
  { pattern = "[^/%*]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

local expression = { patterns = {}, symbols = {} }
local function string_contents(escaped)
  local patterns = {
    { pattern = { "%${", "}" }, type = "keyword2", syntax = expression },
    { pattern = "%$[%a_][%w_]*", type = "keyword2" },
  }
  if escaped then
    patterns[#patterns + 1] = { pattern = "\\.", type = "character.special" }
  end
  patterns[#patterns + 1] = { pattern = escaped and '[^"$\\]+' or '[^"$]+', type = "string" }
  patterns[#patterns + 1] = { pattern = ".", type = "string" }
  return { patterns = patterns, symbols = {} }
end

local kotlin = {
  name = "Kotlin",
  files = { "%.kt$", "%.kts$" },
  comment = "//",
  block_comment = { "/*", "*/" },
  patterns = {
    { pattern = "//.*",                              type = "comment"  }, -- Comment, single-line
    { pattern = { "/%*", "%*/" },                    type = "comment", syntax = block_comment  }, -- Comment, multi-line
    { pattern = { '"""', '"""' }, type = "string", syntax = string_contents(false) },
    { pattern = { '"', '"', '\\' }, type = "string", syntax = string_contents(true) },
    { pattern = { "{", "}" }, type = "normal", syntax = expression },
    { pattern = { "'", "'", '\\' },                  type = "string"   }, -- String, apices
    { pattern = "'\\x%x?%x?%x?%x'",                  type = "string"   }, -- Character hexadecimal escape sequence
    { pattern = "'\\u%x%x%x%x'",                     type = "string"   }, -- Character unicode escape sequence
    { pattern = "'\\?.'",                            type = "string"   }, -- Character literal
    { pattern = "-?0x%x+",                           type = "number"   }, -- ?
    { regex = "-?(?:\\d+\\.(?!\\.)\\d*|\\.\\d\\d*|\\d+)(?:[eE][+-]?\\d+)?f?",                    type = "number"   }, -- ?
    { pattern = "-?%.?%d+f?",                        type = "number"   }, -- ?
    { regex   = [[\-\>(?=\s)]],                      type = "operator" }, -- Lambda
    { regex   = [[\.{2}\<?\s?(?=[\\-]?[a-z0-9])]],   type = "operator" }, -- Range operators
    { pattern = "[%+%-=/%*%^%%<>!~|&]",              type = "operator" }, -- Operators
    { regex   = [[\?(?=\.)]],                        type = "operator" }, -- ?. operator
    { pattern = "[%a_][%w_]*%f[(]",                  type = "function" }, -- Function/Method/Class
    { regex   = "`[\\w_\\s]+`(?=\\s*\\()",           type = "function" }, -- Test Method
    { regex   = [[let(?=\s\{)]],                     type = "function" }, -- ? operator
    { regex   = [[\?\:(?=\s?)]],                     type = "operator" }, -- elvis operator
    { regex   = [[this(?=\.?\@?)]],                  type = "keyword"  }, -- this keyword
    { regex   = "\\@\\w+",                           type = "keyword2" }, -- Annotations
    { regex   = [[[a-zA-Z]+\@(?=\s?[a-zA-Z])]],      type = "keyword2" }, -- Annotations (this pattern is lower priority than the `this keyword` pattern)
    { regex   = "[A-Z][A-Z_]+",                      type = "keyword2" }, -- Constants, FULL UPPERCASE
    { pattern = "import()%s+()[%w_.]+",              type = { "keyword", "normal", "normal" } },
    { pattern = "[%a_][%w_]*",                       type = "symbol"   }, -- ?
  },
  symbols = {
    -- Hard keywords
    ["as"]           = "keyword",
    ["break"]        = "keyword",
    ["class"]        = "keyword",
    ["continue"]     = "keyword",
    ["do"]           = "keyword",
    ["else"]         = "keyword",
    ["for"]          = "keyword",
    ["fun"]          = "keyword",
    ["if"]           = "keyword",
    ["in"]           = "keyword",
    ["!in"]          = "keyword",
    ["interface"]    = "keyword",
    ["is"]           = "keyword",
    ["!is"]          = "keyword",
    ["object"]       = "keyword",
    ["package"]      = "keyword",
    ["return"]       = "keyword",
    ["super"]        = "keyword",
    ["this"]         = "keyword",
    ["throw"]        = "keyword",
    ["try"]          = "keyword",
    ["typealias"]    = "keyword",
    ["typeof"]       = "keyword",
    ["val"]          = "keyword",
    ["var"]          = "keyword",
    ["when"]         = "keyword",
    ["while"]        = "keyword",

    -- Soft keywords
    ["by"]           = "keyword",
    ["catch"]        = "keyword",
    ["constructor"]  = "keyword",
    ["delegate"]     = "keyword",
    ["dynamic"]      = "keyword",
    ["field"]        = "keyword",
    ["file"]         = "keyword",
    ["finally"]      = "keyword",
    ["get"]          = "keyword",
    ["import"]       = "keyword",
    ["init"]         = "keyword",
    ["param"]        = "keyword",
    ["property"]     = "keyword",
    ["receiver"]     = "keyword",
    ["set"]          = "keyword",
    ["setparam"]     = "keyword",
    ["value"]        = "keyword",
    ["where"]        = "keyword",

    -- Modifier keywords
    ["abstract"]     = "keyword",
    ["actual"]       = "keyword",
    ["annotation"]   = "keyword",
    ["companion"]    = "keyword",
    ["const"]        = "keyword",
    ["crossinline"]  = "keyword",
    ["data"]         = "keyword",
    ["enum"]         = "keyword",
    ["expect"]       = "keyword",
    ["external"]     = "keyword",
    ["final"]        = "keyword",
    ["inline"]       = "keyword",
    ["inner"]        = "keyword",
    ["infix"]        = "keyword",
    ["internal"]     = "keyword",
    ["lateinit"]     = "keyword",
    ["noinline"]     = "keyword",
    ["open"]         = "keyword",
    ["operator"]     = "keyword",
    ["out"]          = "keyword",
    ["override"]     = "keyword",
    ["private"]      = "keyword",
    ["protected"]    = "keyword",
    ["public"]       = "keyword",
    ["reified"]      = "keyword",
    ["sealed"]       = "keyword",
    ["suspend"]      = "keyword",
    ["tailrec"]      = "keyword",
    ["vararg"]       = "keyword",

    -- Special identifiers
    ["it"]           = "keyword",

    -- Boolean
    ["true"]         = "literal",
    ["false"]        = "literal",
    ["null"]         = "literal",
  },
}

expression.patterns, expression.symbols = kotlin.patterns, kotlin.symbols

syntax.add(kotlin)
