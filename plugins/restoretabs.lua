-- mod-version:3
local core = require "core"
local Node = require "core.node"
local command = require "core.command"
local keymap = require "core.keymap"

local tab_history = { }
local history_size = 10

local old_remove_view = Node.remove_view
function Node:remove_view(root, view)
  if view.doc and view.doc.abs_filename then
    local filename = view.doc.abs_filename
    for i, f in ipairs(tab_history) do
      if f == filename then table.remove(tab_history, i) break end
    end
    table.insert(tab_history, filename)
    if #tab_history > history_size then table.remove(tab_history, 1) end
  end
  return old_remove_view(self, root, view)
end

command.add(nil, {
  ["restore-tabs:restore-tab"] = function()
    if #tab_history > 0 then
      local file = tab_history[#tab_history]
      core.root_view:open_doc(core.open_doc(file))
      table.remove(tab_history)
    end
  end
})

keymap.add { ["ctrl+shift+t"] = "restore-tabs:restore-tab" }
