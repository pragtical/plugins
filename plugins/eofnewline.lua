-- mod-version:3
local core = require "core"
local command = require "core.command"
local Doc = require "core.doc"

local function eof_newline(doc)
    local leof, neof = #doc.lines, #doc.lines
    for i = leof, 1, -1 do
        if not string.match(doc.lines[i], "^%s*$") then break end
        neof = i
    end
    if neof ~= leof then
        doc:remove(neof, 1, leof, math.huge)
        return
    end
    if "\n" ~= doc.lines[leof] then doc:insert(leof, math.huge, "\n") end
end

command.add("core.docview", {
    ["eof-newline:eof-newline"] = function()
        eof_newline(core.active_view.doc)
    end,
})

local save = Doc.save
function Doc:save(...)
    eof_newline(self)
    save(self, ...)
end
