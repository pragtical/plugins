-- mod-version:3

local syntax = require "core.syntax"

syntax.add {
  name = "INI",
  files = { "%.ini$", "%.conf$", "%.inf$", "%.cfg$", "%.editorconfig$", "%.theme$", "%.dockitem$" },
  comment = ';',
  patterns = {
    -- comments
    { pattern = ";.*", type = "comment" },
    { pattern = "#.*", type = "comment" },
    -- sections
    { pattern = { "%[", "%]" }, type = "keyword" },
    -- strings
    { pattern = { '"""', '"""', '\\' }, type = "string" },
    { pattern = { '"', '"', '\\' }, type = "string" },
    { pattern = { "'''", "'''" }, type = "string" },
    { pattern = { "'", "'" }, type = "string" },
    -- keys
    { pattern = "^[^=]+()=%s*", type = {"function", "operator"} },
    -- prevent treating boolean values with ending space as non enclosed string
    { pattern = "true%s+", type = "literal" },
    { pattern = "false%s+", type = "literal" },
    -- allows ini values that use comments symbol as value separator
    -- when no spaces are used between the symbol eg: value1;value2;value3
    { pattern = "[^%d%s][^%s]*[#;]%S*", type = "symbol" },
    { pattern = "[^%s]+%d+[^%s]*[#;]%S*", type = "symbol" },
    -- any non enclosed string value up to a starting comment
    { pattern = "[^%-+%.'\"#;%d]+[^#;]+()%s[#;].*", type = {"symbol", "comment"} },
    { pattern = "%a+%S*", type = "symbol" },
    -- numbers values
    { pattern = "[%-+]?%.?%d[%d_]*%.[%d_]+%f[%s%.]", type = "number" },
    { pattern = "[%-+]?%.?%d[%d_]*%f[%s]", type = "number" },
    -- any non enclosed string value
    { pattern = "%a+", type = "symbol" },
  },
  symbols = {
    ["true"] = "literal",
    ["false"] = "literal",
  },
}
