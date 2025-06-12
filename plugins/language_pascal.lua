-- mod-version:3
local syntax = require "core.syntax"

syntax.add {
  name = "Pascal",
  files = { "%.pas$", "%.pp$", "%.p$", "%.dpr$" },
  comment = "//",
  patterns = {
    -- comments
    { pattern = "//.*",                  type = "comment" },
    { pattern = "{.-}",                  type = "comment" },
    { pattern = { "%(%*", "%*%)" },      type = "comment" },
    -- strings
    { pattern = { "'", "'", "\\" },      type = "string" },
    -- compiler directives
    { pattern = "#%d+",                  type = "string" },
    -- uppercase constants of at least 2 chars in len
    { pattern = "_?%u[%u_][%u%d_]*%f[%s%+%*%-%.%)%]}%?%^%%=/<>~|&;:,!]",
      type = "number"
    },
    -- numbers
    { pattern = "0x[%da-fA-F]+",         type = "number" },
    { pattern = "%d+%.%d+",              type = "number" },
    { pattern = "%d+",                   type = "number" },
    -- operators
    { pattern = "[<>~!%^&*+=|/%-]",      type = "operator" },
    -- function names
    { pattern = "[%a_][%w_]*%s*%f[%(]",  type = "function" },
    -- keywords and types
    { pattern = "[%a_][%w_]*",           type = "symbol" },
  },
  symbols = {
    -- keywords
    ["and"] = "keyword",
    ["array"] = "keyword",
    ["begin"] = "keyword",
    ["case"] = "keyword",
    ["const"] = "keyword",
    ["div"] = "keyword",
    ["do"] = "keyword",
    ["downto"] = "keyword",
    ["else"] = "keyword",
    ["end"] = "keyword",
    ["file"] = "keyword",
    ["for"] = "keyword",
    ["function"] = "keyword",
    ["goto"] = "keyword",
    ["if"] = "keyword",
    ["implementation"] = "keyword",
    ["in"] = "keyword",
    ["interface"] = "keyword",
    ["label"] = "keyword",
    ["mod"] = "keyword",
    ["nil"] = "literal",
    ["not"] = "keyword",
    ["of"] = "keyword",
    ["or"] = "keyword",
    ["packed"] = "keyword",
    ["procedure"] = "keyword",
    ["program"] = "keyword",
    ["record"] = "keyword",
    ["repeat"] = "keyword",
    ["set"] = "keyword",
    ["shl"] = "keyword",
    ["shr"] = "keyword",
    ["then"] = "keyword",
    ["to"] = "keyword",
    ["type"] = "keyword",
    ["unit"] = "keyword",
    ["until"] = "keyword",
    ["uses"] = "keyword",
    ["var"] = "keyword",
    ["while"] = "keyword",
    ["with"] = "keyword",
    ["xor"] = "keyword",
    -- types
    ["Integer"] = "keyword2",
    ["integer"] = "keyword2",
    ["real"] = "keyword2",
    ["boolean"] = "keyword2",
    ["char"] = "keyword2",
    ["string"] = "keyword2",
    ["byte"] = "keyword2",
    ["word"] = "keyword2",
    ["longint"] = "keyword2",
    ["cardinal"] = "keyword2",
    ["pointer"] = "keyword2",
    ["qword"] = "keyword2",
    ["dword"] = "keyword2",
    ["shortint"] = "keyword2",
    ["smallint"] = "keyword2",
    ["comp"] = "keyword2",
    ["double"] = "keyword2",
    ["extended"] = "keyword2",
    ["single"] = "keyword2",
    -- functions
    ["exit"] = "function"
  }
}
