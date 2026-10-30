-- mod-version:3.1
local syntax = require "core.syntax"

local definition = {
  name = "SSH config",
  files = {
    PATHSEP .. "ssh" .. PATHSEP .. "config$",
    PATHSEP .. "%.ssh" .. PATHSEP .. "config$",
    PATHSEP .. "sshd?_config$",
  },
  comment = '#',
  patterns = {
    { pattern = { '"', '"', '\\' }, type = "string" },
    { pattern = "#.*",        type = "comment"  },
    { pattern = "%d+",          type = "number"   },
    { pattern = "[%a_][%w_]*",  type = "symbol"   },
    { pattern = "@",            type = "operator" },
  },
  symbols = {
    -- ssh config
    ["Host"]                         = "function",
    ["ProxyCommand"]                 = "function",

    ["HostName"]                     = "keyword",
    ["IdentityFile"]                 = "keyword",
    ["IdentitiesOnly"]               = "keyword",
    ["User"]                         = "keyword",
    ["Port"]                         = "keyword",

    ["ForwardAgent"]                 = "keyword",
    ["ForwardX11"]                   = "keyword",
    ["ForwardX11Trusted"]            = "keyword",
    ["HostbasedAuthentication"]      = "keyword",
    ["GSSAPIAuthentication"]         = "keyword",
    ["GSSAPIDelegateCredentials"]    = "keyword",
    ["GSSAPIKeyExchange"]            = "keyword",
    ["GSSAPITrustDNS"]               = "keyword",
    ["BatchMode"]                    = "keyword",
    ["CheckHostIP"]                  = "keyword",
    ["AddressFamily"]                = "keyword",
    ["ConnectTimeout"]               = "keyword",
    ["StrictHostKeyChecking"]        = "keyword",
    ["Ciphers"]                      = "keyword",
    ["MACs"]                         = "keyword",
    ["EscapeChar"]                   = "keyword",
    ["Tunnel"]                       = "keyword",
    ["TunnelDevice"]                 = "keyword",
    ["PermitLocalCommand"]           = "keyword",
    ["VisualHostKey"]                = "keyword",
    ["RekeyLimit"]                   = "keyword",
    ["SendEnv"]                      = "keyword",
    ["HashKnownHosts"]               = "keyword",

    -- sshd config
    ["Subsystem"]                    = "keyword2",


    ["yes"]      = "literal",
    ["no"]       = "literal",
    ["any"]      = "literal",
    ["ask"]      = "literal",
  },
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
