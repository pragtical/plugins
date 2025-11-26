-- mod-version:3.1
local syntax = require "core.syntax"

local hex = {pattern = "\\[xX][%da-fA-F][%da-fA-F]", type = "function"}
local backslash_escape = {pattern = "\\.", type = "function"}
local unicode = {
	pattern = "\\[uU][%da-fA-F][%da-fA-F][%da-fA-F][%da-fA-F]",
	type = "function"
}

local string_interpolation_syntax = {patterns = {}, symbols = {}}

local zsh_syntax = {
	name = "Zsh",
	files = {
		"%.zsh$", PATHSEP .. "%.zshrc$", "%.zshenv$", "%.zprofile$", "%.zlogin$",
  "%.zlogout$"
	},
	headers = "^#!.*zsh%s*.*$",
	comment = "#",
	patterns = {
		-- Comments
		{pattern = "#.*", type = "comment"}, -- Strings (with interpolation)
		{
			pattern = {"\"", "\"", "\\"},
			type = "string",
			syntax = string_interpolation_syntax
		}, {pattern = {"'", "'", "\\"}, type = "string"}, {
			pattern = {"`", "`", "\\"},
			type = "string",
			syntax = string_interpolation_syntax
		}, {
			pattern = {"%$%(", "%)", "\\"},
			type = "string",
			syntax = string_interpolation_syntax
		}, -- Numbers
		{pattern = "%f[%w_%.%/]%d[%d%.]*%f[^%w_%.]", type = "number"},
  {pattern = "0x[%da-fA-F]+", type = "number"},
  {pattern = "0[0-7]+", type = "number"}, -- Operators
		{pattern = "==|!=|<=|>=|<|>", type = "operator"},
  {pattern = "[=!<>|&%[%]+:%*%-]", type = "operator"},
  {pattern = "+=", type = "operator"},
  {pattern = "[%+%-*/%%]=?", type = "operator"},
  {pattern = "&&|\\|\\||!", type = "operator"}, -- Redirection
		{
			pattern = "<<<|>>>|<<|>>|<|>|<>|>\\||\\|&|&>|>&|2>|2>>|2>&1",
			type = "operator"
		}, -- Variable expansions
		{pattern = "%${.-}", type = "keyword2"},
  {pattern = "%$[%w_]+", type = "keyword2"},
  {pattern = "%$[%d@#*]", type = "keyword2"}, -- Function definitions
		{pattern = "%f[%w_]function%s+[%w_]+%s*%(%)", type = "function"},
  {pattern = "%f[%w_][%w_]+%s*%(%)", type = "function"}, -- Variable assignment
		{pattern = "[%a_][%w_]*%f[%+=]", type = "keyword2"}, -- Arrays
		{pattern = "%b()", type = "symbol"}, -- general matching for `(...)`
		-- All other words
		{pattern = "[%a_][%w_%-]*", type = "symbol"}
	},

	symbols = {
		["if"] = "keyword",
		["then"] = "keyword",
		["else"] = "keyword",
		["elif"] = "keyword",
		["fi"] = "keyword",
		["for"] = "keyword",
		["while"] = "keyword",
		["until"] = "keyword",
		["do"] = "keyword",
		["done"] = "keyword",
		["in"] = "keyword",
		["case"] = "keyword",
		["esac"] = "keyword",
		["function"] = "keyword",
		["time"] = "keyword",
		["coproc"] = "keyword",
		["repeat"] = "keyword",
		["select"] = "keyword",
		["always"] = "keyword",

		-- builtins
		["alias"] = "keyword",
		["autoload"] = "keyword",
		["bg"] = "keyword",
		["bindkey"] = "keyword",
		["break"] = "keyword",
		["builtin"] = "keyword",
		["cd"] = "keyword",
		["chdir"] = "keyword",
		["command"] = "keyword",
		["compdef"] = "keyword",
		["compinit"] = "keyword",
		["continue"] = "keyword",
		["dirs"] = "keyword",
		["disable"] = "keyword",
		["disown"] = "keyword",
		["echo"] = "keyword",
		["emulate"] = "keyword",
		["enable"] = "keyword",
		["eval"] = "keyword",
		["exec"] = "keyword",
		["exit"] = "keyword",
		["fc"] = "keyword",
		["fg"] = "keyword",
		["getopts"] = "keyword",
		["hash"] = "keyword",
		["history"] = "keyword",
		["jobs"] = "keyword",
		["kill"] = "keyword",
		["let"] = "keyword",
		["limit"] = "keyword",
		["logout"] = "keyword",
		["popd"] = "keyword",
		["print"] = "keyword",
		["pushd"] = "keyword",
		["pwd"] = "keyword",
		["read"] = "keyword",
		["rehash"] = "keyword",
		["return"] = "keyword",
		["setopt"] = "keyword",
		["shift"] = "keyword",
		["source"] = "keyword",
		["suspend"] = "keyword",
		["test"] = "keyword",
		["times"] = "keyword",
		["trap"] = "keyword",
		["true"] = "literal",
		["false"] = "literal",
		["ttyctl"] = "keyword",
		["type"] = "keyword",
		["ulimit"] = "keyword",
		["umask"] = "keyword",
		["unalias"] = "keyword",
		["unfunction"] = "keyword",
		["unhash"] = "keyword",
		["unlimit"] = "keyword",
		["unset"] = "keyword",
		["unsetopt"] = "keyword",
		["vared"] = "keyword",
		["wait"] = "keyword",
		["whence"] = "keyword",
		["where"] = "keyword",
		["which"] = "keyword",
		["zcompile"] = "keyword",
		["zformat"] = "keyword",
		["zftp"] = "keyword",
		["zle"] = "keyword",
		["zmodload"] = "keyword",
		["zparseopts"] = "keyword",
		["zprof"] = "keyword",
		["zpty"] = "keyword",
		["zregexparse"] = "keyword",
		["zsocket"] = "keyword",
		["zstyle"] = "keyword",
		["ztsched"] = "keyword"
	}
}

local function merge_tables(a, b) for _, v in ipairs(b) do table.insert(a, v) end end

merge_tables(string_interpolation_syntax.patterns, {
	unicode, hex, backslash_escape, {pattern = "%$[%w_]+", type = "keyword2"},
 {pattern = "%$[@#]", type = "keyword2"},
 {pattern = "%${.-}", type = "keyword2"},
 {pattern = {"%$%(%(", "%)%)"}, type = "keyword2", syntax = zsh_syntax},
 {pattern = {"%$%(", "%)"}, type = "keyword2", syntax = zsh_syntax},
 {pattern = "[%S][%w]*", type = "string"}
})

syntax.add(zsh_syntax)
