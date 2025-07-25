-- mod-version:3

local syntax = require "core.syntax"
local style = require "core.style"
local common = require "core.common"

style.syntax["ignore"] = { common.color "#72B886" }
style.syntax["exclude"] = { common.color "#F36161" }

syntax.add {
  name = ".ignore file",
  files = { PATHSEP .. "%..*ignore$" },
  comment = "#",
  patterns = {
    { pattern = "^%s*#.*", type = "comment" },
    { pattern = "^%s*!.*", type = "ignore"  },
    { pattern = ".+",      type = "exclude" },
  },
  symbols = {}
}
