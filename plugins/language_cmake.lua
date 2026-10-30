-- mod-version:3.1
local syntax = require "core.syntax"

local variable = { patterns = {}, symbols = {} }
local generator = { patterns = {}, symbols = {} }
local arguments = { patterns = {}, symbols = {} }

local variable_reference = {
  pattern = { "%${", "}" }, type = "operator", syntax = variable,
}
local environment_reference = {
  pattern = { "%$ENV{", "}" }, type = "operator", syntax = variable,
}
local cache_reference = {
  pattern = { "%$CACHE{", "}" }, type = "operator", syntax = variable,
}
local generator_expression = {
  pattern = { "%$<", ">" }, type = "keyword2", syntax = generator,
}

variable.patterns = {
  variable_reference,
  environment_reference,
  cache_reference,
  generator_expression,
  { pattern = "\\.", type = "character.special" },
  { pattern = "[^}$\\]+", type = "operator" },
  { pattern = ".", type = "operator" },
}

generator.patterns = {
  variable_reference,
  environment_reference,
  cache_reference,
  generator_expression,
  { pattern = "[^>$]+", type = "keyword2" },
  { pattern = ".", type = "keyword2" },
}

local quoted = {
  patterns = {
    variable_reference,
    environment_reference,
    cache_reference,
    generator_expression,
    { pattern = "@[%w_]+@", type = "operator" },
    { pattern = "\\.", type = "character.special" },
    { pattern = '[^"$\\@]+', type = "string" },
    { pattern = ".", type = "string" },
  },
  symbols = {},
}

arguments.patterns = {
  { pattern = { "#%[=*%[", "%]=*%]" }, type = "comment" },
  { pattern = "#.*", type = "comment" },
  { pattern = { "%[=*%[", "%]=*%]" }, type = "string" },
  { pattern = { '"', '"', '\\' }, type = "string", syntax = quoted },
  { pattern = "\\.", type = "character.special" },
  variable_reference,
  environment_reference,
  cache_reference,
  generator_expression,
  { pattern = "@[%w_]+@", type = "operator" },
  { pattern = { "%(", "%)" }, type = "operator", syntax = arguments },
  { regex = [[(?i:ON|OFF|YES|NO|TRUE|FALSE|Y|N|IGNORE|NOTFOUND)(?=[\s();#]|$)]], type = "literal" },
  { regex = [[[-+]?(?:0[xX][0-9a-fA-F]+|[0-9]+(?:\.[0-9]+)*(?:[eE][-+]?[0-9]+)?)(?=[\s();#]|$)]], type = "number" },
  { pattern = ";", type = "operator" },
  { pattern = '[^%s()#"$\\;@]+', type = "normal" },
}

arguments.symbols = {
  ["AND"]                   = "keyword",
  ["OR"]                    = "keyword",
  ["NOT"]                   = "keyword",
  ["COMMAND"]               = "keyword",
  ["POLICY"]                = "keyword",
  ["TARGET"]                = "keyword",
  ["TEST"]                  = "keyword",
  ["DEFINED"]               = "keyword",
  ["DIAGNOSTIC"]            = "keyword",
  ["EXISTS"]                = "keyword",
  ["IS_READABLE"]           = "keyword",
  ["IS_WRITABLE"]           = "keyword",
  ["IS_EXECUTABLE"]         = "keyword",
  ["IS_DIRECTORY"]          = "keyword",
  ["IS_SYMLINK"]            = "keyword",
  ["IS_ABSOLUTE"]           = "keyword",
  ["IS_NEWER_THAN"]         = "keyword",
  ["MATCHES"]               = "keyword",
  ["LESS"]                  = "keyword",
  ["GREATER"]               = "keyword",
  ["EQUAL"]                 = "keyword",
  ["LESS_EQUAL"]            = "keyword",
  ["GREATER_EQUAL"]         = "keyword",
  ["STRLESS"]               = "keyword",
  ["STRGREATER"]            = "keyword",
  ["STREQUAL"]              = "keyword",
  ["STRLESS_EQUAL"]          = "keyword",
  ["STRGREATER_EQUAL"]       = "keyword",
  ["VERSION_LESS"]          = "keyword",
  ["VERSION_GREATER"]       = "keyword",
  ["VERSION_EQUAL"]         = "keyword",
  ["VERSION_LESS_EQUAL"]    = "keyword",
  ["VERSION_GREATER_EQUAL"] = "keyword",
  ["IN_LIST"]               = "keyword",
  ["PATH_EQUAL"]            = "keyword",

  ["PUBLIC"]                = "keyword2",
  ["PRIVATE"]               = "keyword2",
  ["INTERFACE"]             = "keyword2",
  ["PARENT_SCOPE"]          = "keyword2",
  ["CACHE"]                 = "keyword2",
  ["FORCE"]                 = "keyword2",
  ["BOOL"]                  = "keyword2",
  ["FILEPATH"]              = "keyword2",
  ["PATH"]                  = "keyword2",
  ["STRING"]                = "keyword2",
  ["INTERNAL"]              = "keyword2",
  ["STATIC"]                = "keyword2",
  ["SHARED"]                = "keyword2",
  ["MODULE"]                = "keyword2",
  ["OBJECT"]                = "keyword2",
  ["IMPORTED"]              = "keyword2",
  ["ALIAS"]                 = "keyword2",
  ["GLOBAL"]                = "keyword2",
  ["REQUIRED"]              = "keyword2",
  ["QUIET"]                 = "keyword2",
  ["COMPONENTS"]            = "keyword2",
  ["OPTIONAL_COMPONENTS"]   = "keyword2",
  ["CONFIG"]                = "keyword2",
  ["CONFIGURE_DEPENDS"]     = "keyword2",
  ["EXCLUDE_FROM_ALL"]      = "keyword2",
  ["BEFORE"]                = "keyword2",
  ["AFTER"]                 = "keyword2",
  ["SYSTEM"]                = "keyword2",
  ["APPEND"]                = "keyword2",
  ["VERSION"]               = "keyword2",
  ["LANGUAGES"]             = "keyword2",
  ["DESTINATION"]           = "keyword2",
  ["FILES"]                 = "keyword2",
  ["DIRECTORY"]             = "keyword2",
  ["TARGETS"]               = "keyword2",
  ["PROPERTIES"]            = "keyword2",
  ["IN"]                    = "keyword2",
  ["ITEMS"]                 = "keyword2",
  ["LISTS"]                 = "keyword2",
  ["RANGE"]                 = "keyword2",
  ["ZIP_LISTS"]             = "keyword2",
  ["STATUS"]                = "keyword2",
  ["WARNING"]               = "keyword2",
  ["AUTHOR_WARNING"]        = "keyword2",
  ["SEND_ERROR"]            = "keyword2",
  ["FATAL_ERROR"]           = "keyword2",
  ["NOTICE"]                = "keyword2",
  ["VERBOSE"]               = "keyword2",
  ["DEBUG"]                 = "keyword2",
  ["TRACE"]                 = "keyword2",
}

local cmake = {
  name = "CMake",
  files = {
    "%.cmake$", "%.cmake%.in$",
    PATHSEP .. "CMakeLists%.txt$", "^CMakeLists%.txt$",
    PATHSEP .. "CMakeLists%.txt%.in$", "^CMakeLists%.txt%.in$",
  },
  comment = "#",
  block_comment = { "#[[", "]]" },
  patterns = {
    { pattern = { "#%[=*%[", "%]=*%]" }, type = "comment" },
    { pattern = "#.*", type = "comment" },
    { pattern = { "%[=*%[", "%]=*%]" }, type = "string" },
    { pattern = { '"', '"', '\\' }, type = "string", syntax = quoted },
    { pattern = "\\.", type = "character.special" },
    variable_reference,
    environment_reference,
    cache_reference,
    generator_expression,
    { pattern = "@[%w_]+@", type = "operator" },
    { regex = [[(?i:if|elseif|else|endif|foreach|endforeach|while|endwhile|function|endfunction|macro|endmacro|block|endblock|return|break|continue)(?=[ \t]*\()]], type = "keyword" },
    { regex = [[[A-Za-z_][A-Za-z0-9_]*(?=[ \t]*\()]], type = "function" },
    { pattern = { "%(", "%)" }, type = "operator", syntax = arguments },
    { pattern = "[%a_][%w_]*", type = "normal" },
  },
  symbols = {},
}

-- Match common bracket lengths exactly before the generic fallback. Tokenizer
-- state cannot retain delimiter captures for arbitrarily many equals signs.
for count = 16, 0, -1 do
  local equals = string.rep("=", count)
  local comment = {
    pattern = { "#%[" .. equals .. "%[", "%]" .. equals .. "%]" },
    type = "comment",
  }
  local literal = {
    pattern = { "%[" .. equals .. "%[", "%]" .. equals .. "%]" },
    type = "string",
  }
  table.insert(arguments.patterns, 1, literal)
  table.insert(arguments.patterns, 1, comment)
  table.insert(cmake.patterns, 1, literal)
  table.insert(cmake.patterns, 1, comment)
end

syntax.add(cmake)
