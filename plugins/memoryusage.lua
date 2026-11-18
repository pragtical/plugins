-- mod-version:3
-- original implementation by AqilCont
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local style = require "core.style"
local StatusView = require "core.statusview"

config.plugins.memoryusage = common.merge({
  enabled = true,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Memory Usage",
    {
      label = "Enabled",
      description = "Show or hide the lua memory usage from the status bar.",
      path = "enabled",
      type = "toggle",
      default = true,
      on_apply = function(enabled)
        core.add_thread(function()
          if enabled then
            core.status_view:get_item("status:memory-usage"):show()
          else
            core.status_view:get_item("status:memory-usage"):hide()
          end
        end)
      end
    }
  }
}, config.plugins.memoryusage)

local last_usage

core.status_view:add_item({
  name = "status:memory-usage",
  alignment = StatusView.Item.RIGHT,
  get_item = function()
    if core.request_update then core.request_update(1) end
    local usage = string.format(
      "%.2f MB", (math.floor(collectgarbage("count") / 10.24) / 100)
    )
    if usage ~= last_usage then
      last_usage = usage
      core.redraw = true
    end
    return {
      style.text,
      usage
    }
  end,
  position = 1,
  tooltip = "lua memory usage",
  separator = core.status_view.separator2
})

command.add(nil, {
  ['memory-usage:toggle'] = function()
    config.plugins.memoryusage.enabled = not config.plugins.memoryusage.enabled
    if config.plugins.memoryusage.enabled then
      core.status_view:get_item("status:memory-usage"):show()
    else
      core.status_view:get_item("status:memory-usage"):hide()
    end
  end,
})
