-- mod-version:3
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local Doc = require "core.doc"
local DocView = require "core.docview"

config.plugins.input_latency = common.merge({
  enabled = true,
  print_stdout = true,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Input Latency",
    {
      label = "Enable",
      description = "Enable or disable the recollection of input latency data.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Print Time to Standard Out",
      description = "On each key press it prints time taken in ms to standard out.",
      path = "print_stdout",
      type = "toggle",
      default = true
    }
  }
}, config.plugins.input_latency)

local EVENT_LAST_TIME = 0
local TEXTINPUT_EVENT_EMITTED = false
local INPUT_LATENCY_DATA = {}

local core_step = core.step
function core.step()
  if config.plugins.input_latency.enabled then
    local start_time = system.get_time()
    local diddraw = core_step()
    if not diddraw then
      EVENT_LAST_TIME = start_time
    end
    return diddraw
  end
  return core_step()
end

local core_on_event = core.on_event
function core.on_event(type, a, b, c, d)
  if config.plugins.input_latency.enabled and core.active_view:is(DocView) then
    if type == "textinput" then
      TEXTINPUT_EVENT_EMITTED = true
    end
  end
  return core_on_event(type, a, b, c, d)
end

local renderer_end_frame = renderer.end_frame
function renderer.end_frame()
  renderer_end_frame()
  if config.plugins.input_latency.enabled then
    if TEXTINPUT_EVENT_EMITTED then
      -- keep a maximum of 200 results
      if #INPUT_LATENCY_DATA > 199 then table.remove(INPUT_LATENCY_DATA, 1) end
      -- insert new result
      local value = (system.get_time() - EVENT_LAST_TIME) * 1000
      table.insert(INPUT_LATENCY_DATA, value)
      if config.plugins.input_latency.print_stdout then
        print(value)
      end
      -- reset event
      TEXTINPUT_EVENT_EMITTED = false
    end
  end
end

local function get_average()
  local sum = 0
  for _, value in ipairs(INPUT_LATENCY_DATA) do
    sum = sum + value
  end
  return sum / #INPUT_LATENCY_DATA
end

command.add(nil, {
  ["input-latency:toggle"] = function()
    config.plugins.input_latency.enabled = not config.plugins.input_latency.enabled
    if config.plugins.input_latency.enabled then
      core.log("Input Latency: Enabled Data Recollection")
    else
      core.log("Input Latency: Disabled Data Recollection")
    end
  end,
  ["input-latency:reset-results"] = function()
    INPUT_LATENCY_DATA = {}
  end,
  ["input-latency:show-results"] = function()
    if config.plugins.input_latency.enabled then
      local results = {}
      table.insert(results, "# Input Latency Results")
      table.insert(results, "")
      table.insert(results, "* MIN: " .. math.min(table.unpack(INPUT_LATENCY_DATA)) .. " ms")
      table.insert(results, "* MAX: " .. math.max(table.unpack(INPUT_LATENCY_DATA)) .. " ms")
      table.insert(results, "* AVERAGE: " .. get_average() .. " ms")
      table.insert(results, "")
      table.insert(results, "## Enabled Plugins:")
      table.insert(results, "")
      for name, _ in pairs(config.plugins) do
        table.insert(results, "* " .. name)
      end
      local doc = Doc("Input Latency Results.md", "Input Latency Results.md", true)
      for line, text in ipairs(results) do
        doc:insert(line, math.huge, text .. "\n")
      end
      core.root_view:get_active_node_default():add_view(DocView(doc))
    end
  end
})
