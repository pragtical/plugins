-- mod-version:3
local syntax = require "core.syntax"

local function escaped_contents(delimiter, token_type)
  return {
    patterns = {
      { pattern = "\\x{%x+}", type = "character.special" },
      { pattern = "\\x%x%x", type = "character.special" },
      { pattern = "\\[0-7][0-7]?[0-7]?", type = "character.special" },
      { pattern = "\\%^.", type = "character.special" },
      { pattern = "\\.", type = "character.special" },
      { pattern = "[^\\" .. delimiter:gsub("(%W)", "%%%1") .. "]+", type = token_type },
      { pattern = ".", type = token_type },
    },
    symbols = {},
  }
end

local patterns = {}
local string_contents = escaped_contents('"', "string")
local atom_contents = escaped_contents("'", "literal")

-- Match delimiter lengths exactly. Tokenizer state cannot retain an arbitrary
-- opening quote count, so multiline strings support 3-16 delimiter quotes.
for count = 16, 3, -1 do
  local quotes = string.rep('"', count)
  local ending = '^[ \t]*' .. quotes .. '%f[^"]'
  patterns[#patterns + 1] = {
    pattern = { '~[bs]' .. quotes .. '[ \t]*\n', ending, '\\' },
    type = "string", syntax = string_contents,
  }
  patterns[#patterns + 1] = {
    pattern = { '~[BS]?' .. quotes .. '[ \t]*\n', ending }, type = "string",
  }
  patterns[#patterns + 1] = {
    pattern = { quotes .. '[ \t]*\n', ending }, type = "string",
  }
end

for _, delimiters in ipairs { "()", "[]", "{}", "<>", "//", "||", "''", '\"\"', "``", "##" } do
  local opener = delimiters:sub(1, 1):gsub("(%W)", "%%%1")
  local closer = delimiters:sub(2, 2):gsub("(%W)", "%%%1")
  patterns[#patterns + 1] = {
    pattern = { "~[bs]?" .. opener, closer, '\\' }, type = "string",
    syntax = escaped_contents(delimiters:sub(2, 2), "string"),
  }
  patterns[#patterns + 1] = {
    pattern = { "~[BS]" .. opener, closer }, type = "string",
  }
end

local token_patterns = {
  { pattern = "^#!.*", type = "comment" },
  { pattern = "%%.*", type = "comment" },
  { pattern = { '"', '"', '\\' }, type = "string", syntax = string_contents },
  { pattern = { "'", "'", '\\' }, type = "literal", syntax = atom_contents },
  { pattern = "%$\\x{%x+}", type = "character.special" },
  { pattern = "%$\\x%x%x", type = "character.special" },
  { pattern = "%$\\[0-7][0-7]?[0-7]?", type = "character.special" },
  { pattern = "%$\\%^.", type = "character.special" },
  { pattern = "%$\\.", type = "character.special" },
  { pattern = "%$.", type = "character" },
  { regex = [[[0-9](?:_?[0-9])*#[0-9A-Za-z](?:_?[0-9A-Za-z])*\.[0-9A-Za-z](?:_?[0-9A-Za-z])*#[eE][+-]?[0-9](?:_?[0-9])*]], type = "number" },
  { regex = [[[0-9](?:_?[0-9])*#[0-9A-Za-z](?:_?[0-9A-Za-z])*]], type = "number" },
  { regex = [[[0-9](?:_?[0-9])*\.[0-9](?:_?[0-9])*(?:[eE][+-]?[0-9](?:_?[0-9])*)?]], type = "number" },
  { pattern = "%d[%d_]*", type = "number" },
  { pattern = "%?%??[%a_][%w_@]*", type = "constant.macro" },
  { pattern = "#[a-z][%w_@]*", type = "type" },
  { regex = [[^[ \t]*-[a-z][a-zA-Z0-9_@]*(?=[ \t(.\r\n]|$)]], type = "preproc" },
  { pattern = "[A-Z_][%w_@]*", type = "symbol" },
  { regex = [[[a-z][a-zA-Z0-9_@]*(?=[ \t]*(?:\(|/[0-9]))]], type = "function" },
  { pattern = "[a-z][%w_@]*", type = "literal" },
  { regex = [[(?:=:=|=/=|<:=|<:-|->|<-|=>|:=|==|/=|=<|>=|<<|>>|\+\+|--|\|\||&&|\?=)]], type = "operator" },
  { pattern = "[%+%-%*/=<>!|:#?&]", type = "operator" },
}

for _, rule in ipairs(token_patterns) do patterns[#patterns + 1] = rule end

syntax.add {
  name = "Erlang",
  files = { "%.erl$", "%.hrl$", "%.escript$", "^escript$", PATHSEP .. "escript$" },
  headers = "^#![^\n]*[/ ]escript%f[^%w_]",
  comment = "%",
  patterns = patterns,
  symbols = {
    ["after"]   = "keyword",
    ["begin"]   = "keyword",
    ["case"]    = "keyword",
    ["catch"]   = "keyword",
    ["cond"]    = "keyword",
    ["end"]     = "keyword",
    ["else"]    = "keyword",
    ["fun"]     = "keyword",
    ["if"]      = "keyword",
    ["let"]     = "keyword",
    ["maybe"]   = "keyword",
    ["of"]      = "keyword",
    ["receive"] = "keyword",
    ["try"]     = "keyword",
    ["when"]    = "keyword",
    ["and"]     = "operator",
    ["andalso"] = "operator",
    ["band"]    = "operator",
    ["bnot"]    = "operator",
    ["bor"]     = "operator",
    ["bsl"]     = "operator",
    ["bsr"]     = "operator",
    ["bxor"]    = "operator",
    ["div"]     = "operator",
    ["not"]     = "operator",
    ["or"]      = "operator",
    ["orelse"]  = "operator",
    ["rem"]     = "operator",
    ["xor"]     = "operator",
    ["true"]    = "boolean",
    ["false"]   = "boolean",
  },
}
