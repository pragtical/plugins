-- mod-version:3
local syntax = require "core.syntax"

-----------------------
-- Utility functions --
-----------------------

local function escape_lua_pattern(input_str)
  local special_chars = {
    ["("] = "%(",
    [")"] = "%)",
    ["."] = "%.",
    ["%"] = "%%",
    ["+"] = "%+",
    ["-"] = "%-",
    ["*"] = "%*",
    ["?"] = "%?",
    ["["] = "%[",
    ["^"] = "%^",
    ["$"] = "%$"
  }

  return input_str:gsub(".", function(char)
    return special_chars[char] or char
  end)
end

local function merge_kv_tables(...)
  local res = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    for k, v in pairs(tbl) do
      res[k] = v
    end
  end
  return res
end

local function merge_i_tables(...)
  local res = {}
  for i = 1, select('#', ...) do
    local tbl = select(i, ...)
    for _, v in ipairs(tbl) do
      table.insert(res, v)
    end
  end
  return res
end

local function create_symbols_table(symbols_str, type_str)
  local symbols = {}
  for word in symbols_str:gmatch("%S+") do
    symbols[word] = type_str
  end
  return symbols
end

local function create_patterns_table(patterns_str, type_str)
  local patterns = {}
  for patt in patterns_str:gmatch("%S+") do
    table.insert(patterns, { pattern = patt, type = type_str })
  end
  return patterns
end

---------------------------
-- Utility functions end --
---------------------------


----------------------
-- C3 Specification --
----------------------

local c3_keywords = [[
alias      asm        assert     attrdef    bitstruct
break      case       catch      const      constdef
continue   default    defer      do         else
enum       extern                faultdef   fn
for        foreach    foreach_r  if         import
inline     interface  lengthof   macro      module
nextcase              return     static     struct
switch     tlocal                try        typedef
union      var        while
]]

local c3_literal_keywords = [[
true false null
]]

local c3_builtin_types = [[
any        bfloat     bool       char       double
fault      float      float16    float128   ichar
int        int128     iptr       long       short
sz         typeid     uint       uint128    untypedlist
uptr       ushort     usz        void       ulong
]]

local c3_compile_time_keywords = [[
$assert     $case       $default    $defined    $echo
$else       $embed      $endforeach $endfor     $endif
$endswitch  $error      $eval       $exec       $expand
$feature    $foreach    $for        $if         $include
$reflect    $stringify  $switch     $Typefrom   $Typeof
$vaarg
]]

local c3_operators = [[
+    -    *    /    %
&    |    ^    ~    <<   >>
=    +=   -=   *=   /=   %=
&=   |=   ^=   <<=  >>=
==   !=   <    >    <=   >=
&&   ||   !
?:   ?    ??   !!
++   --
]]

local c3_punctuations = [[
[<   >]
->   =>
]]

-- _unused
local _c3_compile_time_operators = [[
&&&  |||  ???  +++  +++=
]]

local _c3_something_else = [[
@    #    $
]]

--------------------------
-- C3 Specification end --
--------------------------


--------------------------
-- Gathering altogether --
--------------------------

syntax.add {
  name = "C3 Contract",
  files = { "%.c3contract$" },
  patterns = { 
    -- absurdity hacks to get syntax highlighting for @guards in contracts
    -- while remaining everythin else a comment
    { pattern = {"@require",    " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@require",    "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@ensure",     " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@ensure",     "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@param",      " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@param",      "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@pure",       " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@pure",       "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@return",     " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@return",     "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@return%?",   " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@return%?",   "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@deprecated", " $"}, type = "keyword", syntax = ".c3" },
    { pattern = {"@deprecated", "\n"}, type = "keyword", syntax = ".c3" },
    { pattern = ".",                   type = "comment" },
  },
}

local syntax_patterns = merge_i_tables(
  {
    { pattern = "//.-\n",                  type = "comment"  },
    { pattern = { "/%*", "%*/" },          type = "comment"  },
    { pattern = { "<%*", "%*>" },          type = "comment", syntax = ".c3contract"  },
    { pattern = { '"', '"', '\\' },        type = "string"   },
    { pattern = { "`", "`", '\\' },        type = "string"   },
    { pattern = { "'", "'", '\\' },        type = "string"   },
    { pattern = "0b[01_]+",                type = "number"   },
    { pattern = "0[oO][0-7_]+",            type = "number"   },
    { pattern = "0[xX][%da-fA-F_]+",       type = "number"   },
    { pattern = "%d+[%d%._e]*",            type = "number"   },
    { pattern = "[%l_]+[%u]*[%w_]*%f[(]",  type = "function" },
    { pattern = "@[%a_][%w_]*",            type = "keyword"  }, -- @my_builtin
    { pattern = "%u[%u%d_]+%f[^%w_]",      type = "normal"   }, -- MY_CONSTANT
    { pattern = "%u[%w_]*",                type = "literal"  }, -- MyType
    -- This ensures any identifier gets tokenized as "symbol",
    -- which then gets looked up in the symbols table.
    { pattern = "[%a_][%w_]*",             type = "symbol" },
    -- edge case for [<*>]
    { pattern = "%[<()%*()>%]", type = {"normal", "operator", "normal"} },
    -- Otherwise the closing *> of C3 Contract won't be of "comment" type
    { pattern = "%*>", type = "comment" },
  },
  create_patterns_table(escape_lua_pattern(c3_punctuations), "normal"),
  create_patterns_table(escape_lua_pattern(c3_compile_time_keywords), "keyword"),
  create_patterns_table(escape_lua_pattern(c3_operators), "operator")
)

local syntax_symbols = merge_kv_tables(
  create_symbols_table(c3_keywords, "keyword"),
  create_symbols_table(c3_literal_keywords, "literal"),
  create_symbols_table(c3_builtin_types, "keyword2")
)

syntax.add {
  name = "C3",
  files = { "%.c3$", "%.c3i$", "%.c3t$" },
  comment = "//",
  block_comment = {"/*", "*/"},

  patterns = syntax_patterns,
  symbols = syntax_symbols,
}

------------------------------
-- Gathering altogether end --
------------------------------

