-- mod-version:3
local syntax = require "core.syntax"

syntax.add {
  name = "V",
  files = { "%.v$", "%.vsh$" },
  headers = "^#!.*[ /]v\n",
  comment = "//",
  symbol_pattern = "[%a_#@%$][%w_]*",
  symbol_non_word_chars = " \t\n/\\()\"':,.;<>~!%^&*|+=[]{}`?-",
  patterns = {
    { pattern = "^#!.*[ /]v\n",             type = "comment"  },
    { pattern = "//.-\n",                   type = "comment"  },
    { pattern = { "/%*", "%*/" },           type = "comment"  },
    -- Strings
    { pattern = { '"', '"', '\\' },
      syntax = {
        -- Interpolation
        patterns = {
          { pattern = { "%${", "}" },
            syntax = {
              patterns = {
                { pattern = { '"', '"', '\\' }, type = "string" },
                { pattern = { "'", "'", '\\' }, type = "string" },
                { pattern = { "`", "`", '\\' }, type = "string" },
                { pattern = "0x[%da-fA-F_]+", type = "number" },
                { pattern = "0b[01_]+", type = "number" },
                { pattern = "0o[0-7_]+", type = "number" },
                { pattern = "-?%.?%d%d*e[%+%-]*%d+", type = "number" },
                { pattern = "%d[%d_]*", type = "number" },
                { pattern = "-?%.?%d+", type = "number" },
                { pattern = "[%+%-%*/&~!^<>=]+", type = "operator" },
                { pattern = "[%a_][%w_]*%f[%(]", type = "function" },
                { pattern = "[%a_][%w_]*", type = "symbol" }
              },
              symbols = {}
            },
            type = "keyword"
          },
          { regex = [[\\x[0-9a-fA-F]{2}]], type = "operator" },
          { regex = [[\\u[0-9a-fA-F]{4}]], type = "operator" },
          { regex = [[\\[0-7]{3}]], type = "operator" },
          { pattern = "\\[abfnrtv\\\"%?0]", type = "operator" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = "string"
    },
    { pattern = { "'", "'", "\\" },
      syntax = {
        patterns = {
          -- Interpolation
          { pattern = { "%${", "}" },
            syntax = {
              patterns = {
                { pattern = { '"', '"', '\\' }, type = "string" },
                { pattern = { "'", "'", '\\' }, type = "string" },
                { pattern = { "`", "`", '\\' }, type = "string" },
                { pattern = "0x[%da-fA-F_]+", type = "number" },
                { pattern = "0b[01_]+", type = "number" },
                { pattern = "0o[0-7_]+", type = "number" },
                { pattern = "-?%.?%d%d*e[%+%-]*%d+", type = "number" },
                { pattern = "%d[%d_]*", type = "number" },
                { pattern = "-?%.?%d+", type = "number" },
                { pattern = "[%+%-%*/&~!^<>=]+", type = "operator" },
                { pattern = "[%a_][%w_]*%f[%(]", type = "function" },
                { pattern = "[%a_][%w_]*", type = "symbol" }
              },
              symbols = {}
            },
            type = "keyword"
          },
          { regex = [[\\x[0-9a-fA-F]{2}]], type = "operator" },
          { regex = [[\\u[0-9a-fA-F]{4}]], type = "operator" },
          { regex = [[\\[0-7]{3}]], type = "operator" },
          { pattern = "\\[abfnrtv\\'%?0]", type = "operator" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = "string"
    },
    -- Rune strings
    { pattern = { "`", "`", '\\' },
      syntax = {
        patterns = {
          -- Interpolation
          { pattern = { "%${", "}" },
            syntax = {
              patterns = {
                { pattern = { '"', '"', '\\' }, type = "string" },
                { pattern = { "'", "'", '\\' }, type = "string" },
                { pattern = { "`", "`", '\\' }, type = "string" },
                { pattern = "0x[%da-fA-F_]+", type = "number" },
                { pattern = "0b[01_]+", type = "number" },
                { pattern = "0o[0-7_]+", type = "number" },
                { pattern = "-?%.?%d%d*e[%+%-]*%d+", type = "number" },
                { pattern = "%d[%d_]*", type = "number" },
                { pattern = "-?%.?%d+", type = "number" },
                { pattern = "[%+%-%*/&~!^<>=]+", type = "operator" },
                { pattern = "[%a_][%w_]*%f[%(]", type = "function" },
                { pattern = "[%a_][%w_]*", type = "symbol" }
              },
              symbols = {}
            },
            type = "keyword"
          },
          { regex = [[\\x[0-9a-fA-F]{2}]], type = "operator" },
          { regex = [[\\u[0-9a-fA-F]{4}]], type = "operator" },
          { regex = [[\\[0-7]{3}]], type = "operator" },
          { pattern = "\\[abfnrtv\\`%?0]", type = "operator" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = "string"
    },
    -- C strings
    { pattern = { "c()'", "()'", "\\" },
      syntax = {
        patterns = {
          { pattern = "\\[%a]", type = "operator" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = {"function", "string"}
    },
    { pattern = { 'c()"', '()"', "\\" },
      syntax = {
        patterns = {
          { pattern = "\\[%a]", type = "operator" },
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = {"function", "string"}
    },
    -- Raw strings
    { pattern = { "r()'", "()'" },
      syntax = {
        patterns = {
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = {"function", "string"}
    },
    { pattern = { 'r()"', '()"' },
      syntax = {
        patterns = {
          { pattern = ".", type = "string" },
        },
        symbols = {},
      },
      type = {"function", "string"}
    },
    -- Numbers
    { pattern = "0x[%da-fA-F_]+",           type = "number"   },
    { pattern = "0b[01_]+",                 type = "number"   },
    { pattern = "0o[0-7_]+",                type = "number"   },
    { pattern = "-?%.?%d%d*e[%+%-]*%d+",    type = "number"   },
    { pattern = "%d[%d_]*",                 type = "number"   },
    { pattern = "-?%.?%d+",                 type = "number"   },
    -- Functions
    { pattern = "[%a_][%w_]*%f[(]",         type = "function" },
    -- C import module
    { pattern = "%f[^%s&]C()%.()[%a_][%w_]*",
      type = { "namespace", "normal", "keyword2" }
    },
    -- Structs accessed from modules
    { pattern = "%f[^%.][%u][%w_]*%f[%.]",  type = "keyword2" },
    -- Operators
    { pattern = "[%+%-%*%/%%%~%&%|%^%!%=:]",type = "operator" },
    { pattern = "%.%.%.?",                  type = "operator" },
    -- Compile constants
    { pattern = "@[%u]+",                   type = "keyword2" },
    -- Escaped reserved keywords
    { pattern = "@%s?[%a_][%w_]*",          type = "normal" },
    -- Compile time keywords
    { pattern = "%$%s?[%a_][%w_]*",         type = "keyword2" },
    -- Attributes
    { pattern = "%@%[()[%a][%w_]+()%]",
      type = { "annotation", "annotation.type", "annotation" }
    },
    { pattern = { "@%[", "%]" },
      syntax = {
        patterns = {
          { pattern = { '"', '"', '\\' }, type = "annotation.string" },
          { pattern = { "'", "'", '\\' }, type = "annotation.string" },
          { pattern = "[%a_][%w_]*%f[:]", type = "annotation.type" },
          { pattern = "[%a_][%w_]*",      type = "annotation.param" },
          { pattern = "[:;]",             type = "annotation.operator" }
        },
        symbols = {
          ["flag"] = "annotation.type",
          ["deprecated"] = "annotation.type",
          ["deprecated_after"] = "annotation.type",
          ["inline"] = "annotation.type",
          ["noinline"] = "annotation.type",
          ["noreturn"] = "annotation.type",
          ["heap"] = "annotation.type",
          ["keep_args_alive"] = "annotation.type",
          ["unsafe"] = "annotation.type",
          ["manualfree"] = "annotation.type",
          ["typedef"] = "annotation.type",
          ["callconv"] = "annotation.type",
          ["console"] = "annotation.type",
          ["if"] = "annotation.type",
          ["required"] = "annotation.type",
          ["export"] = "annotation.type",
          ["noinit"] = "annotation.type",
          ["live"] = "annotation.type",
        }
      },
      type = "attribute"
    },
    -- Import statements
    { pattern = "import()%s+()[%l][%w%._]*%s+",
      type = { "keyword", "normal", "namespace" }
    },
    -- C interoperability flags
    { pattern = "#include%s()<.->",
      type = { "keyword", "string" }
    },
    { pattern = "#preinclude%s()<.->",
      type = { "keyword", "string" }
    },
    { pattern = { "#pkgconfig", "%f[\n]" },
      syntax = {
        patterns = {
          { regex = [[\-\-(?:cflags|libs)]], type="operator" },
          { pattern = "[%a_][%w_]*", type = "string" },
        },
        symbols = {}
      },
      type = "keyword"
    },
    { pattern = { "#flag", "%f[\n]" },
      syntax = {
        patterns = {
          { pattern = "%-[IlLD]", type="operator" },
          { pattern = { '"', '"', '\\' }, type = "string" },
          { pattern = { "'", "'", '\\' }, type = "string" },
          { pattern = "[%$@]%s?[%a_][%w_]*", type = "keyword2" },
          { pattern = "[/]", type = "operator" },
          { pattern = "[%a_][%w_]*", type = "symbol" },
        },
        symbols = {
          ["linux"] = "string",
          ["darwin"] = "string" ,
          ["freebsd"] = "string",
          ["windows"] = "string"
        }
      },
      type = "keyword"
    },
    { regex = "#(?:include|preinclude)",
      type = "keyword"
    },
    -- Structs and some parameter types
    { pattern = "[%u][%w_]*", type = "keyword2" },
    -- Var declaration (we add this to prevent conflicts with fields)
    { pattern = "[%a_][%w_]*()%s*():=",
      type = { "symbol", "normal", "operator" }
    },
    -- Fields
    { pattern = "[%a_][%w_]*%f[:]", type = "keyword2" },
    -- Variables
    { pattern = "[%l][%l%d_]*", type = "symbol" },
    -- All other symbols
    { pattern = "[%a_][%w_]*", type = "symbol" },
  },
  symbols = {
    ["as"] = "keyword",
    ["asm"] = "keyword",
    ["assert"] = "keyword",
    ["atomic"] = "keyword",
    ["break"] = "keyword",
    ["const"] = "keyword",
    ["continue"] = "keyword",
    ["defer"] = "keyword",
    ["else"] = "keyword",
    ["enum"] = "keyword",
    ["fn"] = "keyword",
    ["for"] = "keyword",
    ["go"] = "keyword",
    ["goto"] = "keyword",
    ["if"] = "keyword",
    ["import"] = "keyword",
    ["in"] = "keyword",
    ["interface"] = "keyword",
    ["is"] = "keyword",
    ["isreftype"] = "keyword",
    ["lock"] = "keyword",
    ["match"] = "keyword",
    ["module"] = "keyword",
    ["mut"] = "keyword",
    ["or"] = "keyword",
    ["pub"] = "keyword",
    ["return"] = "keyword",
    ["rlock"] = "keyword",
    ["select"] = "keyword",
    ["shared"] = "keyword",
    ["sizeof"] = "keyword",
    ["spawn"] = "keyword",
    ["static"] = "keyword",
    ["struct"] = "keyword",
    ["type"] = "keyword",
    ["typeof"] = "keyword",
    ["union"] = "keyword",
    ["unsafe"] = "keyword",
    ["volatile"] = "keyword",
    ["__global"] = "keyword",
    ["__offsetof"] = "keyword",

    ["#flag"] = "keyword",
    ["#pkgconfig"] = "keyword",
    ["#include"] = "keyword",
    ["#preinclude"] = "keyword",

    ["any"] = "keyword2",
    ["bool"] = "keyword2",
    ["i8"] = "keyword2",
    ["i16"] = "keyword2",
    ["int"] = "keyword2",
    ["i64"] = "keyword2",
    ["i128"] = "keyword2",
    ["u8"] = "keyword2",
    ["u16"] = "keyword2",
    ["u32"] = "keyword2",
    ["u64"] = "keyword2",
    ["u128"] = "keyword2",
    ["isize"] = "keyword2",
    ["usize"] = "keyword2",
    ["f32"] = "keyword2",
    ["f64"] = "keyword2",
    ["byte"] = "keyword2",
    ["char"] = "keyword2",
    ["rune"] = "keyword2",
    ["chan"] = "keyword2",
    ["string"] = "keyword2",
    ["map"] = "keyword2",
    ["voidptr"] = "keyword2",
    ["thread"] = "keyword2",

    ["true"] = "literal",
    ["false"] = "literal",
    ["none"] = "literal",
    ["nil"] = "literal",

    ["@FN"] = "keyword2",
    ["@METHOD"] = "keyword2",
    ["@MOD"] = "keyword2",
    ["@STRUCT"] = "keyword2",
    ["@FILE"] = "keyword2",
    ["@LINE"] = "keyword2",
    ["@FILE_LINE"] = "keyword2",
    ["@LOCATION"] = "keyword2",
    ["@COLUMN"] = "keyword2",
    ["@VEXE"] = "keyword2",
    ["@VEXEROOT"] = "keyword2",
    ["@VHASH"] = "keyword2",
    ["@VCURRENTHASH"] = "keyword2",
    ["@VMOD_FILE"] = "keyword2",
    ["@VMODROOT"] = "keyword2",

    ["$if"] = "keyword2",
    ["$else"] = "keyword2",
    ["$embed_file"] = "keyword2",
    ["$tmpl"] = "keyword2",
    ["$env"] = "keyword2",
    ["$compile_error"] = "keyword2",
    ["$compile_warn"] = "keyword2",

    ["$alias"] = "keyword2",
    ["$array"] = "keyword2",
    ["$array_dynamic"] = "keyword2",
    ["$array_fixed"] = "keyword2",
    ["$enum"] = "keyword2",
    ["$float"] = "keyword2",
    ["$function"] = "keyword2",
    ["$int"] = "keyword2",
    ["$interface"] = "keyword2",
    ["$map"] = "keyword2",
    ["$option"] = "keyword2",
    ["$struct"] = "keyword2",
    ["$sumtype"] = "keyword2",

    ["print"] = "function",
    ["println"] = "function",
    ["eprint"] = "function",
    ["eprintln"] = "function",
    ["exit"] = "function",
    ["panic"] = "function",
    ["print_backtrace"] = "function"
  },
}

syntax.add {
  name = "V Mod",
  files = { PATHSEP .. "v%.mod$" },
  comment = "//",
  patterns = {
    { pattern = "//.-\n",                   type = "comment"  },
    { pattern = { "/%*", "%*/" },           type = "comment"  },
    { pattern = { '"', '"', '\\' },         type = "string"   },
    { pattern = { "'", "'", '\\' },         type = "string"   },
    { pattern = "[%={}%[%]:]+",             type = "operator" },
    { pattern = "[%a_][%w_]*%f[:]",         type = "keyword2"   },
  },
  symbols = {
    ["Module"] = "keyword",
  },
}
