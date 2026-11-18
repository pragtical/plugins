-- mod-version:3
local core = require "core"
local Node = require "core.node"
local RootView = require "core.rootview"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local keymap = require "core.keymap"

local tab_history = { }

local function trim_history(size)
  local history_size = math.max(1, math.floor(tonumber(size) or 10))
  while #tab_history > history_size do table.remove(tab_history, 1) end
end

config.plugins.restoretabs = common.merge({
  history_size = 10,
  config_spec = {
    name = "Restore Tabs",
    {
      label = "History Size",
      description = "Maximum number of closed tabs to remember.",
      path = "history_size",
      type = "number",
      default = 10,
      min = 1,
      step = 1,
      on_apply = trim_history
    }
  }
}, config.plugins.restoretabs)

local function remember_closed_view(view)
  if view.doc and view.doc.abs_filename then
    local filename = view.doc.abs_filename
    for i, f in ipairs(tab_history) do
      if f == filename then table.remove(tab_history, i) break end
    end
    table.insert(tab_history, filename)
    trim_history(config.plugins.restoretabs.history_size)
  end
end

local rootview_close_view = RootView.close_view
if rootview_close_view then
  function RootView:close_view(view, on_close)
    return rootview_close_view(self, view, function(closed_view)
      remember_closed_view(closed_view)
      if on_close then on_close(closed_view) end
    end)
  end
end

function Node:close_view(root, view)
  if core.root_view and root == core.root_view.root_node
    and core.root_view.close_view then
    return core.root_view:close_view(view)
  end

  -- Older editors close tabs directly through the node.
  view:try_close(function()
    self:remove_view(root, view)
    remember_closed_view(view)
  end)
end

command.add(nil, {
  ["restore-tabs:restore-tab"] = function()
    trim_history(config.plugins.restoretabs.history_size)
    if #tab_history > 0 then
      local file = tab_history[#tab_history]
      core.root_view:open_doc(core.open_doc(file))
      table.remove(tab_history)
    end
  end
})

keymap.add { ["ctrl+shift+t"] = "restore-tabs:restore-tab" }
