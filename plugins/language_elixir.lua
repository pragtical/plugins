-- mod-version:3
local syntax = require "core.syntax"

local elixir_syntax = {
  name = "Elixir",
  files = { "%.ex$", "%.exs$" },
  comment = "#",
  patterns = {},
}

local function escape_pattern(text)
  return (text:gsub("(%W)", "%%%1"))
end

local function string_syntax(delimiter, token_type, interpolated)
  local patterns = {}
  if interpolated then
    patterns = {
      { pattern = { "#{", "}" }, type = "keyword", syntax = elixir_syntax },
      { pattern = "\\u{%x+}", type = "character.special" },
      { pattern = "\\u%x%x%x%x", type = "character.special" },
      { pattern = "\\x%x%x", type = "character.special" },
    }
  end
  table.insert(patterns, { pattern = "\\.", type = interpolated and "character.special" or token_type })
  -- Stop before any possible closer so the tokenizer can check it first.
  table.insert(patterns, {
    pattern = "[^#\\" .. escape_pattern(delimiter:sub(1, 1)) .. "]+", type = token_type
  })
  table.insert(patterns, { pattern = ".", type = token_type })
  return { patterns = patterns, symbols = {} }
end

local function add_string(opener, closer, token_type, contents)
  table.insert(elixir_syntax.patterns, {
    pattern = { opener, closer, "\\" },
    type = token_type,
    syntax = contents,
  })
end

-- Sigils must match their own closing delimiter, not any sigil delimiter.
local delimiters = {
  { '"""', '"""' }, { "'''", "'''" },
  { '"', '"' }, { "'", "'" }, { "/", "/" }, { "|", "|" },
  { "(", ")" }, { "[", "]" }, { "{", "}" }, { "<", ">" },
}
for _, delimiter in ipairs(delimiters) do
  local opener, closer = delimiter[1], delimiter[2]
  local ending = (#closer == 3 and "^[ \t]*" or "") .. escape_pattern(closer) .. "[%a%d]*"
  add_string("~%l" .. escape_pattern(opener), ending, "string", string_syntax(closer, "string", true))
  add_string("~%u[%u%d]*" .. escape_pattern(opener), ending, "string", string_syntax(closer, "string", false))
end

for _, quote in ipairs { '"', "'" } do
  add_string(quote:rep(3), "^[ \t]*" .. quote:rep(3), "string", string_syntax(quote, "string", true))
  add_string(":" .. quote, quote, "number", string_syntax(quote, "number", true))
  add_string(quote, quote, "string", string_syntax(quote, "string", true))
end

local patterns = {
  { pattern = "#[^\n]*",                         type = "comment"  },
  -- Character literals may contain the interpolation's closing brace or quotes.
  { pattern = "%?\\u{%x+}",                     type = "number"   },
  { pattern = "%?\\u%x%x%x%x",                  type = "number"   },
  { pattern = "%?\\x%x%x",                      type = "number"   },
  { pattern = "%?\\.",                          type = "number"   },
  { pattern = "%?.",                            type = "number"   },
  -- Nested maps, structs and tuples must not close the surrounding interpolation.
  { pattern = { "{", "}" }, type = "operator", syntax = elixir_syntax },
  { pattern = "0[xX][%x_]+",                     type = "number"   },
  { pattern = "0[bB][01_]+",                     type = "number"   },
  { pattern = "0[oO][0-7_]+",                    type = "number"   },
  { pattern = "%d[%d_]*%.%d[%d_]*[eE][+-]?%d[%d_]*", type = "number" },
  { pattern = "%d[%d_]*%.%d[%d_]*",              type = "number"   },
  { pattern = "%d[%d_]*",                       type = "number"   },
  { pattern = "::",                             type = "operator" },
  { pattern = ":[%a_][%w_@]*[!?]?",              type = "number"   },
  { pattern = ":[%+%-%*%/=<>|&!%^~%.]+",         type = "number"   },
  { pattern = "[%a_][%w_@]*[!?]?:%f[%s]",        type = "number"   },
  { pattern = "[%a_][%w_]*[!?]?%f[(]",           type = "function" },
  { pattern = "%u[%w_]*",                       type = "normal"   },
  { pattern = "@[%a_][%w_]*",                    type = "keyword2" },
  { pattern = "_%a[%w_]*[!?]?",                  type = "keyword2" },
  { pattern = "[%+%-=/%*<>!|&%^%%~\\%.:]",      type = "operator" },
  { pattern = "[%a_][%w_]*[!?]?",                type = "symbol"   },
}
for _, pattern in ipairs(patterns) do
  table.insert(elixir_syntax.patterns, pattern)
end
elixir_syntax.symbols = {
  ["def"]              = "keyword",
  ["defp"]             = "keyword",
  ["defguard"]         = "keyword",
  ["defguardp"]        = "keyword",
  ["defmodule"]        = "keyword",
  ["defprotocol"]      = "keyword",
  ["defimpl"]          = "keyword",
  ["defrecord"]        = "keyword",
  ["defrecordp"]       = "keyword",
  ["defmacro"]         = "keyword",
  ["defmacrop"]        = "keyword",
  ["defdelegate"]      = "keyword",
  ["defoverridable"]   = "keyword",
  ["defexception"]     = "keyword",
  ["defcallback"]      = "keyword",
  ["defstruct"]        = "keyword",
  ["for"]              = "keyword",
  ["case"]             = "keyword",
  ["when"]             = "keyword",
  ["with"]             = "keyword",
  ["cond"]             = "keyword",
  ["if"]               = "keyword",
  ["unless"]           = "keyword",
  ["try"]              = "keyword",
  ["receive"]          = "keyword",
  ["after"]            = "keyword",
  ["raise"]            = "keyword",
  ["rescue"]           = "keyword",
  ["catch"]            = "keyword",
  ["else"]             = "keyword",
  ["quote"]            = "keyword",
  ["unquote"]          = "keyword",
  ["super"]            = "keyword",
  ["unquote_splicing"] = "keyword",
  ["do"]               = "keyword",
  ["end"]              = "keyword",
  ["fn"]               = "keyword",
  ["import"]           = "keyword2",
  ["alias"]            = "keyword2",
  ["use"]              = "keyword2",
  ["require"]          = "keyword2",
  ["and"]              = "operator",
  ["or"]               = "operator",
  ["not"]              = "operator",
  ["in"]               = "operator",
  ["__MODULE__"]       = "keyword2",
  ["__ENV__"]          = "keyword2",
  ["__DIR__"]          = "keyword2",
  ["__CALLER__"]       = "keyword2",
  ["true"]             = "literal",
  ["false"]            = "literal",
  ["nil"]              = "literal",
}

local template_expression = {
  pattern = { '<%%=?', '%%>' }, type = "keyword2", syntax = elixir_syntax,
}
local function attribute_syntax(quote)
  return {
    patterns = {
      template_expression,
      { pattern = "[^<" .. quote .. "]+", type = "string" },
      { pattern = ".", type = "string" },
    },
    symbols = {},
  }
end

local curly_expression = { pattern = { "{", "}" }, type = "keyword2", syntax = elixir_syntax }
local function embedded_syntax(extension)
  require("plugins.language_" .. (extension == ".js" and "js" or "css"))
  local base = syntax.get("file" .. extension)
  local patterns = { template_expression }
  for _, rule in ipairs(base.patterns) do
    local opener = rule.pattern and type(rule.pattern) == "table" and rule.pattern[1]
    if opener == '"' or opener == "'" or opener == "`" then
      patterns[#patterns + 1] = {
        pattern = rule.pattern, type = rule.type, syntax = attribute_syntax(opener),
      }
    else
      patterns[#patterns + 1] = rule
    end
  end
  return { patterns = patterns, symbols = base.symbols }
end
local script_syntax, style_syntax = embedded_syntax(".js"), embedded_syntax(".css")
local literal_template = { patterns = {}, symbols = {} }
literal_template.patterns = {
  { pattern = { '<%%#', '%%>' }, type = "comment" },
  { pattern = { '<%%!%-%-', '%-%-%%>' }, type = "comment" },
  template_expression,
  { pattern = { "<!%-%-", "%-%->" }, type = "comment" },
  { regex = [[<(?i:area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)(?=\s|/?>)[^>]*>]], type = "function" },
  { regex = [[<[A-Za-z_.:][\w.:-]*(?:[^>"']|"[^"]*"|'[^']*')*/>]], type = "function" },
  { regex = { [[<[A-Za-z_.:][\w.:-]*(?:[^>"']|"[^"]*"|'[^']*')*>]], [[</[A-Za-z_.:][\w.:-]*\s*>]] }, type = "function", syntax = literal_template },
  { pattern = "[^<]+", type = "normal" },
  { pattern = ".", type = "normal" },
}
local function template_syntax(heex)
  local tag = {
    patterns = {
      template_expression,
      { pattern = { '"', '"' }, type = "string", syntax = attribute_syntax('"') },
      { pattern = { "'", "'" }, type = "string", syntax = attribute_syntax("'") },
      { pattern = "[:@]?[%a_][%w_.:%-]*", type = "keyword" },
      { pattern = "=", type = "operator" },
    },
    symbols = {},
  }
  local patterns = {
    { pattern = { '<%%#', '%%>' }, type = "comment" },
    { pattern = { '<%%!%-%-', '%-%-%%>' }, type = "comment" },
    { pattern = "<%%%%", type = "normal" },
    template_expression,
    { pattern = { "<!%-%-", "%-%->" }, type = "comment" },
    { pattern = { "<[sS][cC][rR][iI][pP][tT]%f[%s>][^>]*>", "</[sS][cC][rR][iI][pP][tT]%s*>" }, type = "function", syntax = script_syntax },
    { pattern = { "<[sS][tT][yY][lL][eE]%f[%s>][^>]*>", "</[sS][tT][yY][lL][eE]%s*>" }, type = "function", syntax = style_syntax },
    { pattern = { "</?[%a_.:][%w_.:%-]*", "/?>" }, type = "function", syntax = tag },
    { pattern = heex and "[^<{]+" or "[^<]+", type = "normal" },
    { pattern = ".", type = "normal" },
  }
  if heex then
    table.insert(tag.patterns, 1, curly_expression)
    table.insert(patterns, 1, curly_expression)
    table.insert(patterns, 1, {
      regex = {
        [[<(?!(?i:area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)(?=\s|/?>))[A-Za-z][\w.:-]*(?=\s|>)(?=(?:[^>"']|"[^"]*"|'[^']*')*\sphx-no-curly-interpolation(?=\s|/?>))(?:[^>"']|"[^"]*"|'[^']*')*(?<!/)>]],
        [[</[A-Za-z][\w.:-]*\s*>]],
      },
      type = "function", syntax = literal_template,
    })
  end
  return {
    name = heex and "HEEx" or "Elixir Template",
    files = heex and { "%.heex$" } or { "%.eex$", "%.leex$" },
    patterns = patterns,
    symbols = {},
  }
end
local heex = template_syntax(true)
-- ~H uses HEEx's own interpolation, not Elixir string interpolation.
for _, delimiter in ipairs { { "'", "'" }, { '"', '"' }, { '"""', '"""' } } do
  table.insert(elixir_syntax.patterns, 1, {
    pattern = { "~H" .. delimiter[1], (#delimiter[2] == 3 and "^[ \t]*" or "") .. delimiter[2] },
    type = "string", syntax = heex,
  })
end

syntax.add(elixir_syntax)

syntax.add(template_syntax(false))

syntax.add(heex)
