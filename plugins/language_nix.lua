-- mod-version:3
-- https://nixos.wiki/wiki/Overview_of_the_Nix_Language
local syntax = require "core.syntax"

local function merge_tables(a, b)
  for _, v in pairs(b) do
    table.insert(a, v)
  end
end

local default_symbols = {
  ["import"]   = "keyword2",
  ["with"]     = "keyword2",
  ["builtins"] = "keyword2",
  ["inherit"]  = "keyword2",
  ["assert"]   = "keyword2",
  ["let"]      = "keyword2",
  ["in"]       = "keyword2",
  ["rec"]      = "keyword2",
  ["if"]       = "keyword",
  ["else"]     = "keyword",
  ["then"]     = "keyword",
  ["true"]     = "literal",
  ["false"]    = "literal",
  ["null"]     = "literal",
}

local default_patterns = {}

local string_interpolation = {
  { pattern = {"%${", "}"}, type = "keyword2", syntax = {
    patterns = default_patterns,
    symbols = default_symbols,
  }},
  { pattern = "\\.", type = "character.special" },
  { pattern = '[^"$\\]+', type = "string" },
  { pattern = ".", type = "string" },
}

local indented_string = {
  patterns = {
    { pattern = "''%${", type = "character.special" },
    { pattern = "'''", type = "character.special" },
    { pattern = "''\\.", type = "character.special" },
    string_interpolation[1],
    { pattern = "[^'$]+", type = "string" },
    { pattern = ".", type = "string" },
  },
  symbols = {},
}

merge_tables(default_patterns, {
  { pattern = "#.*",          type = "comment" },
  { pattern = {"/%*", "%*/"}, type = "comment" },
  { regex = [[-?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][+-]?\d+)?]], type = "number" },
  { pattern = { "{", "}" }, type = "normal", syntax = {
    patterns = default_patterns, symbols = default_symbols,
  }},

  -- interpolation
  { pattern = {"%${", "}"}, type = "keyword2", syntax = {
    patterns = default_patterns,
    symbols = default_symbols,
  }},
  { pattern = {'"', '"', '\\'}, type = "string", syntax = {
    patterns = string_interpolation,
    symbols = {},
  }},
  { regex = {"''", "''(?!['$\\\\])"}, type = "string", syntax = indented_string },

  -- operators
  { pattern = "[%+%-%?!>%*]", type = "operator" },
  { pattern = "/ ",           type = "operator" },
  { pattern = "< ",           type = "operator" },
  { pattern = "//",           type = "operator" },
  { pattern = "&&",           type = "operator" },
  { pattern = "%->",          type = "operator" },
  { pattern = "||",           type = "operator" },
  { pattern = "==",           type = "operator" },
  { pattern = "!=",           type = "operator" },
  { pattern = ">=",           type = "operator" },
  { pattern = "<=",           type = "operator" },

  -- paths (function because its not used otherwise)
  { pattern = "%.?%.?/[^%s%[%]%(%){};,:]+", type = "function" },
  { pattern = "~/[^%s%[%]%(%){};,:]+",      type = "function" },
  { pattern = {"<", ">"},                   type = "function" },

  -- every other symbol
  { pattern = "[%a%-%_][%w%-%_]*", type = "symbol" },
  { pattern = "[;.,:=]",          type = "operator" },
})

syntax.add {
  name = "Nix",
  files = {"%.nix$"},
  comment = "#",
  block_comment = {"/*", "*/"},
  patterns = default_patterns,
  symbols = default_symbols,
}
