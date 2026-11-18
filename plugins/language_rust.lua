-- mod-version:3
local syntax = require "core.syntax"

local block_comment = { patterns = {}, symbols = {} }
block_comment.patterns = {
  { pattern = { "/%*", "%*/" }, type = "comment", syntax = block_comment },
  { pattern = "[^/%*]+", type = "comment" },
  { pattern = ".", type = "comment" },
}

local expression = { patterns = {}, symbols = {} }
local generic_arguments = { patterns = {}, symbols = {} }
local format_arguments = { patterns = {}, symbols = {} }
local skip_argument = { patterns = {}, symbols = {} }
local skip_two_arguments = { patterns = {}, symbols = {} }

local identifier = [[(?!_(?!\p{XID_Continue}))[_\p{XID_Start}]\p{XID_Continue}*]]
local argument = "(?:[0-9]+|" .. identifier .. ")"
local count = "(?:" .. argument .. "\\$|[0-9]+)"
local escape = [[\\(?:u\{(?:[0-9a-fA-F]_*){1,6}\}|x[0-7][0-9a-fA-F]|[nrt0\\'"])]]

local function format_placeholder(raw)
  local fill = raw and [=[[^{}\r\n]]=] or "(?:" .. escape .. [[|[^{}"\\\r\n])]]
  local format_spec = "(?:(?:" .. fill .. ")?[<^>])?[+-]?#?0?"
    .. count .. "?(?:\\.(?:" .. count .. [[|\*))?(?:[xX]\?|[?oxXpbeE])?]]
  local spec_contents = {
    patterns = {
      { regex = fill .. [[(?=[<^>])]], type = "string" },
      { regex = identifier .. [[(?=\$)]], type = "symbol" },
      { pattern = "%d+", type = "number" },
      { regex = [[(?:[xX]\?|[?oxXpbeE])(?=\s*\})]], type = "keyword2" },
      { pattern = "[<>%^%+%-%#%$%.%*]", type = "operator" },
      { pattern = ".", type = "keyword2" },
    },
    symbols = {},
  }
  if not raw then table.insert(spec_contents.patterns, 1, { regex = escape, type = "character.special" }) end
  return {
    regex = { "\\{(?=" .. argument .. "?(?::" .. format_spec .. [[)?\s*\})]], "}" },
    type = "operator",
    syntax = {
      patterns = {
        { regex = { ":", [[(?=\})]] }, type = "operator", syntax = spec_contents },
        { pattern = "%d+", type = "number" },
        { regex = identifier, type = "symbol" },
      },
      symbols = {},
    },
  }
end

local placeholder = format_placeholder(false)
local raw_placeholder = format_placeholder(true)

local function string_contents(kind, formatted)
  local patterns = {}
  if kind ~= "raw" then
    if kind ~= "byte" then
      patterns[#patterns + 1] = {
        regex = [[\\u\{(?:[0-9a-fA-F]_*){1,6}\}]], type = "character.special",
      }
    end
    patterns[#patterns + 1] = {
      pattern = kind == "string" and "\\x[0-7]%x" or "\\x%x%x", type = "character.special",
    }
    patterns[#patterns + 1] = {
      pattern = kind == "c" and [=[\[nrt\\'"]]=] or [=[\[nrt0\\'"]]=], type = "character.special",
    }
    patterns[#patterns + 1] = { pattern = "\\\r?\n[ \t\r\n]*", type = "character.special" }
  end
  if formatted then
    patterns[#patterns + 1] = { pattern = "{{", type = "character.special" }
    patterns[#patterns + 1] = { pattern = "}}", type = "character.special" }
    patterns[#patterns + 1] = kind == "raw" and raw_placeholder or placeholder
  end
  patterns[#patterns + 1] = {
    pattern = formatted and '[^"\\{}]+' or '[^"\\]+', type = "string",
  }
  patterns[#patterns + 1] = { pattern = ".", type = "string" }
  return { patterns = patterns, symbols = {} }
end

local plain_contents = string_contents("string", false)
local byte_contents = string_contents("byte", false)
local c_contents = string_contents("c", false)
local formatted_contents = string_contents("string", true)
local raw_format_contents = string_contents("raw", true)

local function string_patterns(formatted)
  local patterns = {}
  -- Exact raw delimiter lengths, including byte/C strings. More than 16 hashes
  -- needs delimiter capture state that the tokenizer currently cannot retain.
  for hashes = 16, 0, -1 do
    local marks = string.rep("#", hashes)
    patterns[#patterns + 1] = {
      pattern = { (formatted and "r" or "[bc]?r") .. marks .. '"', '"' .. marks },
      type = "string", syntax = formatted and raw_format_contents or nil,
    }
    if formatted then
      patterns[#patterns + 1] = {
        pattern = { "[bc]r" .. marks .. '"', '"' .. marks }, type = "string",
      }
    end
  end
  patterns[#patterns + 1] = { pattern = { 'b"', '"', '\\' }, type = "string", syntax = byte_contents }
  patterns[#patterns + 1] = { pattern = { 'c"', '"', '\\' }, type = "string", syntax = c_contents }
  patterns[#patterns + 1] = {
    pattern = { '"', '"', '\\' }, type = "string", syntax = formatted and formatted_contents or plain_contents,
  }
  return patterns
end

local macro_patterns = {}
-- Standard macro argument positions; panic follows Rust 2021+ formatting.
-- Custom macros and strings produced by macro expansion cannot be inferred here.
for _, group in ipairs {
  { "format|format_args|format_args_nl|print|println|eprint|eprintln|panic|todo|unimplemented|unreachable", format_arguments },
  { "write|writeln|assert|debug_assert", skip_argument },
  { "assert_eq|assert_ne|assert_matches|debug_assert_eq|debug_assert_ne|debug_assert_matches", skip_two_arguments },
} do
  -- Keep the macro context through whitespace/comments before its delimiter.
  -- The inner group leaves its closer for this outer rule to consume.
  macro_patterns[#macro_patterns + 1] = {
    regex = { "(?:" .. group[1] .. ")\\s*!", "[)\\]}]" }, type = "function",
    syntax = {
      patterns = {
        { pattern = "%s+", type = "normal" },
        { pattern = "//.*", type = "comment" },
        { pattern = { "/%*", "%*/" }, type = "comment", syntax = block_comment },
        { regex = { [[\(]], [[(?=\))]] }, type = "normal", syntax = group[2] },
        { regex = { [[\[]], [[(?=\])]] }, type = "normal", syntax = group[2] },
        { regex = { "{", [[(?=\})]] }, type = "normal", syntax = group[2] },
      },
      symbols = {},
    },
  }
end

local comments = {
  { pattern = "//.*",                                          type = "comment"  },
  { pattern = { "/%*", "%*/" },                                  type = "comment", syntax = block_comment  },
}

local tokens = {
  { pattern = "'()\\u{[%x_]+}()'", type = { "character", "character.special", "character" } },
  { pattern = "b?'()\\x%x%x()'", type = { "character", "character.special", "character" } },
  { pattern = [[b?'()\[nrt0\\'"]()']], type = { "character", "character.special", "character" } },
  { pattern = "b?'[^'\\\n]'", type = "character" },
  { pattern = "'[%a_][%a%d_]*",                                  type = "keyword2" },
  { pattern = "%.%.%.?=?", type = "operator" },
  { regex = [[(?:0b[01_]+|0o[0-7_]+|0x[0-9a-fA-F_]+|\d[\d_]*(?:\.(?![.a-df-zA-DF-Z_])[\d_]*)?(?:[eE][+-]?[\d_]+)?)(?:[A-Za-z_][A-Za-z0-9_]*)?]], type = "number" },
  { pattern = { "::%s*<", ">" }, type = "operator", syntax = generic_arguments },
  { pattern = "[%+%-=/%*%^%%<>!~|&.?:]", type = "operator" },
  { regex   = "[a-zA-Z_]\\w*(?=\\s*<[\\w\\s,']+>\\s*\\()", type = "function" },
  { pattern = "[%a_][%w_]*!%f[%[(]",                             type = "function" },
  { pattern = "[%a_][%w_]*%f[(]",                                type = "function" },
  { pattern = "r#[%a_][%w_]*", type = "symbol" },
  { pattern = "[%a_][%w_]*",                                     type = "symbol"   },
  { pattern = { "%(", "%)" }, type = "normal", syntax = expression },
  { pattern = { "%[", "%]" }, type = "normal", syntax = expression },
  { pattern = { "{", "}" }, type = "normal", syntax = expression },
}

local symbols = {
  ["as"]       = "keyword",
  ["async"]    = "keyword",
  ["await"]    = "keyword",
  ["break"]    = "keyword",
  ["const"]    = "keyword",
  ["continue"] = "keyword",
  ["crate"]    = "keyword",
  ["dyn"]      = "keyword",
  ["else"]     = "keyword",
  ["enum"]     = "keyword",
  ["extern"]   = "keyword",
  ["fn"]       = "keyword",
  ["for"]      = "keyword",
  ["if"]       = "keyword",
  ["impl"]     = "keyword",
  ["in"]       = "keyword",
  ["let"]      = "keyword",
  ["loop"]     = "keyword",
  ["match"]    = "keyword",
  ["mod"]      = "keyword",
  ["move"]     = "keyword",
  ["mut"]      = "keyword",
  ["pub"]      = "keyword",
  ["ref"]      = "keyword",
  ["return"]   = "keyword",
  ["Self"]     = "keyword",
  ["self"]     = "keyword",
  ["static"]   = "keyword",
  ["struct"]   = "keyword",
  ["super"]    = "keyword",
  ["trait"]    = "keyword",
  ["type"]     = "keyword",
  ["unsafe"]   = "keyword",
  ["use"]      = "keyword",
  ["where"]    = "keyword",
  ["while"]    = "keyword",
  ["i32"]      = "keyword2",
  ["i64"]      = "keyword2",
  ["i128"]     = "keyword2",
  ["i16"]      = "keyword2",
  ["i8"]       = "keyword2",
  ["u8"]       = "keyword2",
  ["u16"]      = "keyword2",
  ["u32"]      = "keyword2",
  ["u64"]      = "keyword2",
  ["u128"]     = "keyword2",
  ["usize"]    = "keyword2",
  ["isize"]    = "keyword2",
  ["f32"]      = "keyword2",
  ["f64"]      = "keyword2",
  ["f128"]     = "keyword2",
  ["String"]   = "keyword2",
  ["char"]     = "keyword2",
  ["str"]      = "keyword2",
  ["bool"]     = "keyword2",
  ["true"]     = "literal",
  ["false"]    = "literal",
  ["None"]     = "literal",
  ["Some"]     = "literal",
  ["Option"]   = "literal",
  ["Result"]   = "literal",
}

local function append(patterns, rules)
  for _, rule in ipairs(rules) do patterns[#patterns + 1] = rule end
end

append(expression.patterns, comments)
append(expression.patterns, macro_patterns)
append(expression.patterns, string_patterns(false))
append(expression.patterns, tokens)
expression.symbols = symbols

generic_arguments.patterns = {
  { pattern = { "<", ">" }, type = "operator", syntax = generic_arguments },
}
append(generic_arguments.patterns, expression.patterns)
generic_arguments.symbols = symbols

-- Each top-level comma advances one macro argument. Nested Rust expressions
-- shield their commas; after the format argument all strings are ordinary.
format_arguments.patterns = {
  { regex = { ",", [[(?=[)\]}])]] }, type = "normal", syntax = expression },
}
append(format_arguments.patterns, comments)
append(format_arguments.patterns, macro_patterns)
append(format_arguments.patterns, string_patterns(true))
append(format_arguments.patterns, tokens)
format_arguments.symbols = symbols

skip_argument.patterns = {
  { regex = { ",", [[(?=[)\]}])]] }, type = "normal", syntax = format_arguments },
}
append(skip_argument.patterns, expression.patterns)
skip_argument.symbols = symbols

skip_two_arguments.patterns = {
  { regex = { ",", [[(?=[)\]}])]] }, type = "normal", syntax = skip_argument },
}
append(skip_two_arguments.patterns, expression.patterns)
skip_two_arguments.symbols = symbols

syntax.add {
  name = "Rust",
  files = { "%.rs$" },
  comment = "//",
  block_comment = { "/*", "*/" },
  patterns = expression.patterns,
  symbols = symbols,
}
