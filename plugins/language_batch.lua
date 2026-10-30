-- mod-version:3
local syntax = require "core.syntax"

-- batch syntax for lite <liqube>

-- windows batch files use caseless matching for symbols
local symtable = {
  ["keyword"] = {
  "if", "else", "not", "for", "do", "in",
  "equ", "neq", "lss", "leq", "gtr", "geq", -- == != < <= > >=
  "nul", "con", "prn", "prn", "lpt1", "com1", "com2", "com3", "com4",
  "exist", "defined",
  "errorlevel", "cmdextversion",
  "goto", "call", "verify",
  },
  ["function"] = {
  "set", "setlocal", "endlocal", "enabledelayedexpansion",
  "echo", "type",
  "cd", "chdir",
  "md", "mkdir",
  "pause", "choice", "exit",
  "del", "rd", "rmdir",
  "copy", "xcopy",
  "move", "ren",
  "find", "findstr",
  "sort", "shift", "attrib",
  "cmd", "command",
  "forfiles",
 },
}
-- prepare a mixed symbol list
local function prepare_symbols(symtable)
  local symbols = { }
  for symtype, symlist in pairs(symtable) do
    for _, symname in ipairs(symlist) do
      symbols[symname:lower()] = symtype
    symbols[symname:upper()] = symtype
    end
  end
  return symbols
end

local definition = {
  name = "Batch",
  files = { "%.bat$", "%.cmd$" },
  comment = "rem",
  patterns = {
    { pattern = "@echo off\n",                  type = "keyword"  },
    { pattern = "@echo on\n",                   type = "keyword"  },
    { regex = [[(?i:rem)\b.*]],                 type = "comment"  },
    { pattern = "%:%:.*",                       type = "comment"  },
    { pattern = "%s*:[%w%-]+",                  type = "symbol"   },    -- :labels
    { pattern = "%%%w+%%",                      type = "symbol"   },    -- %variable%
    { pattern = "%%%%?~?[%w:]+",                type = "symbol"   },    -- %1, %~dpn1, %~1:2, %%i, %%~i
    { pattern = "[!=()%>&%^/\\@]",              type = "operator" },    -- operators
    { pattern = "-?%.?%d+f?",                   type = "number"   },    -- integer numbers
    { pattern = { '"', '"', '\\' },             type = "string"   },    -- "strings"
    { pattern = "[%a_][%w_]*",                  type = "normal"   },
    { pattern = ":eof",                         type = "keyword"  },    -- not quite as intended, but ok for now
  },
  symbols = prepare_symbols(symtable),
}

-- Match keywords independently of their spelling's case.
local groups = {}
for word, token_type in pairs(definition.symbols) do
  local escaped = word:gsub("([^%w_])", "\\%1")
  groups[token_type] = groups[token_type] or {}
  table.insert(groups[token_type], escaped)
end
local token_types = {}
for token_type in pairs(groups) do token_types[#token_types + 1] = token_type end
table.sort(token_types)
for _, token_type in ipairs(token_types) do
  local words = groups[token_type]
  table.sort(words)
  table.insert(definition.patterns, 1, {
    regex = "(?i:" .. table.concat(words, "|") .. ")(?![a-zA-Z0-9_])",
    type = token_type,
  })
end

syntax.add(definition)
