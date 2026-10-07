-- mod-version:3
-- 10 types:
-- normal symbol comment keyword keyword2 number literal string operator function

local syntax = require "core.syntax"

local symbols = {}

-- ordered patterns
local patterns = { }
local function addpt(k,t) table.insert(patterns, {pattern=k, type=t}) end
local function add(p)     table.insert(patterns, p) end

-- comments

-- shebang module comment must be at the start of the file (only check line start)
add { pattern = { "[^#]#!", "!#" },    type = "normal"  } -- not comment
add { pattern = { "#!", "!#" },        type = "comment" } -- #! ...!# shebang comment

add { pattern = { "##", "##" },        type = "comment"  } -- multi lines comment
add { pattern = { "#%*", "%*#" },      type = "literal"  } -- #* ...*# doc comment (not check: must before declaration , let const global fn pub）
add { pattern =   "#.*",               type = "comment"  } -- single line comment after #

local keywords = "break comp const continue declare do end fn for global if import in let loop macro match orelse proc pub return spawn suite test type when unless while yield"
for k in keywords:gmatch('%w+') do symbols[k] = "keyword" end

local types = "int float number num string table function atom bool"
for k in types:gmatch('%w+') do symbols[k] = "function" end

local keyword2s = "any else skip never argv"
for k in keyword2s:gmatch('%w+') do symbols[k] = "keyword2" end

local operators = "and or not band bor bxor shl shr"
for k in operators:gmatch('%w+') do symbols[k] = "operator" end

local knownatoms = "true false nil no missing no_result undef ok err done loop opaque resource table string number function chan fiber parked file directory InvalidCharacter FileNotFound eof WrongArity read_some read_line read_all     SocketClosed InvalidAddress ConnectionFailed SocketSetupFailed NotServerSocket AcceptFailed CannotSendOnServer SendFailed CannotRecvOnServer RecvFailed"
for k in knownatoms:gmatch('%w+') do symbols[':'..k] = "literal" end

-- strings
add { pattern = { '"""', '"""', [[\]] },   type = "keyword2"   } -- triple quotes, normalize indentation,  escaped by \
add { pattern = { '"', '"', [[\]] },    type = "string"   } -- double quote,  escaped by \
add { pattern = { "'", "'" },           type = "literal"  } -- single quote, no escape

-- inside ` is normal quasi quoted block
-- { pattern = { "`", "`" },              type = "literal"   },

-- number: 0b101 0b10_1 0o567 0xabC 0 1 12.34 0.4 -23.45 -12.3e23 23e012 45.6E4 -12.3e2_3 -20.45_5 23E12 123_456_789
-- not number: 023 0b10_ 0b1_1__00 0b11__11 0B101 777_ 0o_567 0O5678 0XabC -12.3e  -12.3_e23 12.e3.4 12.3e3.4

-- continuous __ disallowed
add { pattern = "-?[%d_eE.]*__",     type =  "normal" }

--  continuous --, first is minus operator, second is minus number sign, 4--5  3- - ---4
add { pattern = "-()[%s-]*-",   type = {"operator", "number"} }

-- 0b10__1  continuous __ disallowed
add { pattern = "0b[01_]*()__",     type = {"number", "normal"} }
-- 0b101 0b10_10, ending _ disallowed
add { pattern = "0b()%f[01][01_]*[01]",     type = {"literal", "number"}   }

add { pattern = "0o[0-7_]*()__",     type = {"number", "normal"} }
add { pattern = "0o()%f[0-7][0-7_]*[0-7]",    type = {"literal", "number"}   }

add { pattern = "0x[%da-fA-F_]*()__",     type = {"number", "normal"} }
add { pattern = "0x()%f[%da-fA-F][%da-fA-F_]+",    type = {"literal", "number"}   }

-- numbers ------------------------------------------
local num = '%f[1-9][%d_]*%d' -- like 24_000, begin with 19, middle allow _, ends with 09

-- （minus） scientific notation fraction number   45.6E4 -12.3e23, 4e04 is ok?
add { pattern = '-?'..num..'%.'..num..'()[eE]()0*'..num, type = {"number", "literal", "number"}    }

-- 0.xx
add { pattern = '-?0%.'..num..'()[eE]()0*'..num, type = {"number", "literal", "number"}    }

-- （minus） fraction number 0.45 -20.45_5
add { pattern = '-?'..num..'%.'..num, type = "number"   }
-- 0.xx
add { pattern = '-?0%.'..num, type = "number"   }

-- （minus） scientific notation integer number   456E4 -123e23
add { pattern = '-?'..num..'()[eE]()0*'..num, type = {"number", "literal", "number"}    }

-- （minus）integer
add { pattern = '-?'..num, type = "number"   }

-- 0
add { pattern = '0%f[^0-9]', type = "number"   }

-- table<string, table>
add { pattern = "table%s*%b<>",          type =  "function"  }

-- generic <T>
add { pattern = "<T>",          type =  "function"  }

-- operators ------------------------------------------
local opchars   = '+-*/<=>~^%|'
do local t = {}
  string.gsub(opchars, '.', function(c) t[#t+1] = '%'..c end)
  opchars = table.concat(t) -- %-%+%*%/%<%=%>%~%^%%%|%`
end
local op = '['..opchars..']'

-- no space between operators
add { pattern = op..'+%s+['..opchars..'%s]*'..op,       type = "normal" }

-- no 3 operators
add { pattern = op..'+%s*'..op..'+%s*'..op..'+%s*'..'['..opchars..'%s]*',     type = "normal" }

-- long operators .. // |> => == >= != <= += -= *= /= %= ^= ~= ->
local longops = '.. // |> => == >= != <= += -= *= /= %= ^= ~= ->'
for k in longops:gmatch('%S+') do addpt('%'..k:sub(1,1)..'%'..k:sub(2,2), 'operator') end

-- no other 2 operators
add { pattern = op..op..'['..opchars..'%s]*',     type = "normal" }

-- no continuous operators
for k in operators:gmatch('%w+') do addpt(op..'['..opchars..'%s]*'..k..'['..opchars..'%s]*', 'normal') end
for k in operators:gmatch('%w+') do addpt(                          k..'['..opchars..'%s]*'..op, 'normal') end

add { pattern = op,                type = "operator" }

-- join string.join
add { pattern = "%.join()%(",  type =  {"function", 'normal' }  }
add { pattern = "join()%(",      type = {"keyword", 'normal' }  }

-- name?! before (, no space between parens and callee
add { pattern = "[%a_][%w_]*[?!]?%f[(]",    type = "function" }

-- atom ------------------------------------------
local atomchars = '-+*/<=>~^?!.@$_'
-- allowed atom :+-*/~<=>?!^.@$_  not begin with number
-- not allowed atom  ",;'`#&()[]{}:\|%
add { pattern = ":[%a"..atomchars.."][%a%d"..atomchars.."]*", type = "keyword2"   }




--  no continuous , : ? !
local othersymbols = ',:?!'
for c in othersymbols:gmatch('.') do
  add { pattern = c..'[%s'..c..']*'..c,    type = "normal" }
  add { pattern = c,    type = "keyword2" }
end

-- quasiquote
add { pattern = "`%s*`[%s`]*`",    type = "normal" } -- no ```
add { pattern = "`",    type = "operator" }

-- space optimization after space rules
add { pattern = "%s+", type = "normal" }

-- Other text
add { pattern = "[%a_][%w_]*",    type = "normal" }

syntax.add {
  name = "Revo",
  files = "%.rv$",
  comment = "#",                -- for toggle
  block_comment = {"##", "##"}, -- for toggle
  space_handling = false, -- add it later
  symbols = symbols,    -- first match symbols
  patterns = patterns,  -- then ordered patterns
}
