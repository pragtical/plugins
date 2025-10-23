-- mod-version:3
local syntax = require "core.syntax"

syntax.add {
  name = "innosetup",
  files = { "%.iss$", "%.iss%.in$", "%.inno$" },
  comment = ";",
  patterns = {
    { pattern = "^%s*;.*",                 type = "comment" },
    { pattern = "^%s*//.*",                 type = "comment" },
    { pattern = { '/%*', '%*/'},             type = "comment" },
    -- strings
    { pattern = { '"', '"', '\\' },        type = "string" },
    { pattern = { "'", "'", '\\' },        type = "string" },
    -- pre processor
    { pattern = "#%w+", type = "keyword2" },
    -- pascal code section
    { pattern = { "%[Code%]", "^%[%w+%]" },
      syntax = ".pas",
      type = "keyword"
    },
    -- sections
    { pattern = "%[%a+%]", type = "keyword"},
    -- GUID
    { pattern = "{{.-}", type = "number"},
    -- constants
    { pattern = "{.-}", type = "number"},
    -- magic constants
    { pattern = "__[%u%l]+__",             type = "number"   },
    -- uppercase constants of at least 2 chars in len
    { pattern = "_?%u[%u_][%u%d_]*%f[%s%+%*%-%.%)%]}%?%^%%=/<>~|&;:,!]",
      type = "number"
    },
    -- numbers
    { pattern = "0x[%da-fA-F]+",           type = "number" },
    { pattern = "%d+%.%d+",                type = "number" },
    { pattern = "%d+",                     type = "number" },
    { pattern = "%a[%w_]*%s*%f[:]",   type = "keyword2" },
    -- operators
    { pattern = "[\\=:%;.,%+%-%*/<>%?]",   type = "operator" },
    -- keywords and types
    { pattern = "%a[%w_]*",                type = "function" },
  },
  symbols = {
    -- sections
    ["Setup"] = "keyword",
    ["Files"] = "keyword",
    ["Registry"] = "keyword",
    ["Icons"] = "keyword",
    ["Dirs"] = "keyword",
    ["Code"] = "keyword",
    ["UninstallRun"] = "keyword",
    ["UninstallDelete"] = "keyword",
    ["Run"] = "keyword",
    ["Components"] = "keyword",
    ["Tasks"] = "keyword",
    ["Types"] = "keyword",
    ["Messages"] = "keyword",
    ["INI"] = "keyword",
    ["Languages"] = "keyword",
    ["LangOptions"] = "keyword",
    ["CustomMessages"] = "keyword",
    ["UserInfoPage"] = "keyword",
    ["InstallDelete"] = "keyword",
    -- setup section directives/properties
    ["AppId"] = "function",
    ["AppName"] = "function",
    ["AppVersion"] = "function",
    ["AppVerName"] = "function",
    ["AppPublisher"] = "function",
    ["AppPublisherURL"] = "function",
    ["AppSupportURL"] = "function",
    ["AppUpdatesURL"] = "function",
    ["ArchitecturesAllowed"] = "function",
    ["ArchitecturesInstallIn64BitMode"] = "function",
    ["AllowNoIcons"] = "function",
    ["DefaultDirName"] = "function",
    ["DefaultGroupName"] = "function",
    ["OutputBaseFilename"] = "function",
    ["Compression"]  = "function",
    ["SolidCompression"] = "function",
    ["PrivilegesRequired"] = "function",
    ["PrivilegesRequiredOverridesAllowed"] = "function",
    ["WizardStyle"]  = "function",
    ["Uninstallable"] = "function",
    ["UninstallFilesDir"] = "function",
    ["DisableDirPage"] = "function",
    ["DisableProgramGroupPage"] = "function",
    ["DisableReadyPage"] = "function",
    ["DisableFinishedPage"] = "function",
    -- pre-processor keywords
    ["public"] = "keyword",
    ["protected"] = "keyword",
    ["private"] = "keyword",
    ["int"] = "keyword",
    ["str"] = "keyword",
    ["any"] = "keyword",
    ["void"] = "keyword",
    ["Local"] = "keyword",
    -- other keywords
    ["not"] = "keyword2",
    ["yes"] = "literal",
    ["no"] = "literal",
    ["Yes"] = "literal",
    ["No"] = "literal",
    ["true"] = "literal",
    ["false"] = "literal",
    ["True"] = "literal",
    ["False"] = "literal",
  }
}
