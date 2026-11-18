-- mod-version:3.1
local syntax = require "core.syntax"

local hex = { pattern = "\\[xX][%da-fA-F][%da-fA-F]", type = "character.special" }
local backslash_escape = { pattern = "\\.", type = "character.special" }
local unicode = {
  pattern = "\\[uU][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F]",
  type = "character.special",
}

local string_interpolation_syntax = { patterns = {}, symbols = {} }
local parameter_syntax = { patterns = {}, symbols = {} }
local arithmetic_syntax = { patterns = {}, symbols = {} }
local expansions = {}

local sh_syntax = {
  name = "Shell script",
  files = {
    "%.sh$", "%.bash$",
    PATHSEP .. "%.bashrc$", PATHSEP .. "%.bash_profile$", PATHSEP .. "%.profile$",
    "%.zsh$", "%.fish$",
    PATHSEP .. "APKBUILD$",
  },
  headers = "^#!.*bin.*sh%s*.*$",
  comment = "#",
  patterns = {
    backslash_escape,
    -- Comments
    { pattern = "#.*", type = "comment" },
    -- Strings
    {
      pattern = { "\"", "\"", "\\" },
      type = "string",
      syntax = string_interpolation_syntax,
    },
    {
      pattern = { "$'", "'", "\\" },
      type = "string",
      syntax = {
        patterns = {
          unicode,
          hex,
          backslash_escape,
          { pattern = "[^'\\]+", type = "string" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
    },
    { pattern = { "'", "'" }, type = "string" },
    { pattern = { "`", "`", "\\" }, type = "keyword2", syntax = ".sh" },
    { pattern = { "[<>]%(", "%)" }, type = "keyword2", syntax = ".sh" },
    { pattern = { "%(", "%)" }, type = "operator", syntax = ".sh" },
    -- Ignore numbers that start with dots or slashes
    { pattern = "%f[%w_%.%/]%d[%d%.]*%f[^%w_%.]", type = "number" },
    -- Operators
    { pattern = "[!<>|&%[%]:=*]", type = "operator" },
    { pattern = "+=", type = "operator" },
    -- Match parameters
    { pattern = "%f[%S][%+%-][%w%-_:]+", type = "function" },
    { pattern = "%f[%S][%+%-][%w%-_]+%f[=]", type = "function" },
    -- Prevent parameters with assignments from been matched as variables
    { pattern = "%s%-%a[%w_%-]*%s+()%d[%d%.]+", type = { "function", "number" } },
    { pattern = "%s%-%a[%w_%-]*%s+()%a[%a%-_:=]+", type = { "function", "symbol" } },
    -- Match variable assignments
    { pattern = "[_%a][%w_]*%f[%+=]", type = "keyword2" },
    -- Functions
    { pattern = "[%a_%-][%w_%-]*[%s]*%f[(]", type = "function" },
    -- Everything else
    { pattern = "[%a_][%w_]*", type = "symbol" },
  },
  symbols = {
    ["case"] = "keyword",
    ["in"] = "keyword",
    ["esac"] = "keyword",
    ["if"] = "keyword",
    ["then"] = "keyword",
    ["elif"] = "keyword",
    ["else"] = "keyword",
    ["fi"] = "keyword",
    ["while"] = "keyword",
    ["do"] = "keyword",
    ["done"] = "keyword",
    ["for"] = "keyword",
    ["break"] = "keyword",
    ["continue"] = "keyword",
    ["function"] = "keyword",
    ["local"] = "keyword",
    ["echo"] = "keyword",
    ["return"] = "keyword",
    ["exit"] = "keyword",
    ["alias"] = "keyword",
    ["test"] = "keyword",
    ["cd"] = "keyword",
    ["declare"] = "keyword",
    ["enable"] = "keyword",
    ["eval"] = "keyword",
    ["exec"] = "keyword",
    ["export"] = "keyword",
    ["getopts"] = "keyword",
    ["hash"] = "keyword",
    ["history"] = "keyword",
    ["help"] = "keyword",
    ["jobs"] = "keyword",
    ["kill"] = "keyword",
    ["let"] = "keyword",
    ["mapfile"] = "keyword",
    ["printf"] = "keyword",
    ["read"] = "keyword",
    ["readarray"] = "keyword",
    ["readonly"] = "keyword",
    ["pwd"] = "keyword",
    ["select"] = "keyword",
    ["set"] = "keyword",
    ["shift"] = "keyword",
    ["source"] = "keyword",
    ["time"] = "keyword",
    ["type"] = "keyword",
    ["until"] = "keyword",
    ["unalias"] = "keyword",
    ["unset"] = "keyword",
    ["true"] = "literal",
    ["false"] = "literal",
  },
}

local function merge_tables(a, b) for _, v in pairs(b) do table.insert(a, v) end end

expansions = {
  { pattern = { "%$%(%(", "%)%)" }, type = "keyword2", syntax = arithmetic_syntax },
  { pattern = { "%$%(", "%)" }, type = "keyword2", syntax = sh_syntax },
  { pattern = { "%${", "}" }, type = "keyword2", syntax = parameter_syntax },
  { pattern = "%$[%a_][%w_]*", type = "keyword2" },
  { pattern = "%$[@#?*!$%-%d]", type = "keyword2" },
}
for i = #expansions, 1, -1 do table.insert(sh_syntax.patterns, 2, expansions[i]) end

merge_tables(parameter_syntax.patterns, expansions)
merge_tables(parameter_syntax.patterns, {
  backslash_escape,
  { pattern = { '"', '"', '\\' }, type = "string", syntax = string_interpolation_syntax },
  { pattern = { "'", "'" }, type = "string" },
  { pattern = "[^}$'\"\\]+", type = "keyword2" },
  { pattern = ".", type = "keyword2" },
})
merge_tables(arithmetic_syntax.patterns, expansions)
merge_tables(arithmetic_syntax.patterns, {
  { pattern = { "%(", "%)" }, type = "operator", syntax = arithmetic_syntax },
  { pattern = "0[xX]%x+", type = "number" },
  { pattern = "%d+#[%w@_]+", type = "number" },
  { pattern = "%d+", type = "number" },
  { pattern = "[%a_][%w_]*", type = "symbol" },
  { pattern = "[%+%-*/%%<>=!~&|^?:,]+", type = "operator" },
})

merge_tables(string_interpolation_syntax.patterns, expansions)
merge_tables(string_interpolation_syntax.patterns, {
  { pattern = "\\[$`\"\\\n]", type = "character.special" },
  { pattern = { "`", "`", "\\" }, type = "keyword2", syntax = sh_syntax },
  { pattern = '[^"$`\\]+', type = "string" },
  { pattern = ".", type = "string" },
})

syntax.add(sh_syntax)
