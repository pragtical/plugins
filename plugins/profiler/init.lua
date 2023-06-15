-- mod-version:3 --priority:0

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local profiler_lua = require "plugins.profiler.lua"
local profiler_jit = LUAJIT and require("jit.profile")
local profiler_jit_high = LUAJIT and require("plugins.profiler.jit")
local profiler_data = {}

--Keep track of profiler status.
local RUNNING = false
--The profiler runs before the settings plugin, we need to manually load them.
local SETTINGS_PATH = USERDIR .. PATHSEP .. "user_settings.lua"
-- Default location to store the profiler results.
local DEFAULT_LOG_PATH = USERDIR .. PATHSEP .. "profiler.log"

config.plugins.profiler = common.merge({
  enable_on_startup = false,
  log_file = DEFAULT_LOG_PATH,
  jit_profiler = true,
  raw = false,
  highlevel = true,
  options = "f",
  depth = 3,
  config_spec = {
    name = "Profiler",
    {
      label = "Enable on Startup",
      description = "Enable profiler early on plugin startup process.",
      path = "enable_on_startup",
      type = "toggle",
      default = false
    },
    {
      label = "Log Path",
      description = "Path to the file that will contain the profiler logged data.",
      path = "log_file",
      type = "file",
      default = DEFAULT_LOG_PATH,
      filters = {"%.log$"}
    },
    {
      label = "JIT Profiler",
      description = "Use the LuaJIT profiler, applicable only with LuaJIT.",
      path = "jit_profiler",
      type = "toggle",
      default = true
    },
    {
      label = "JIT Profiler Raw",
      description = "The generated output file can be read by graphical tools, eg: `flamegraph profiler.log > out.svg`",
      path = "raw",
      type = "toggle",
      default = false
    },
    {
      label = "JIT Profiler HighLevel",
      description = "Use Mike Pall High Level Profiler.",
      path = "highlevel",
      type = "toggle",
      default = true
    },
    {
      label = "JIT Profiler HighLevel Options",
      description = "Flags that control the profiler output, see README.md.",
      path = "options",
      type = "string",
      default = "f"
    },
    {
      label = "JIT Profiler Depth",
      description = "Maximum calls depth to register.",
      path = "depth",
      type = "number",
      default = 3,
      min = -100,
      max = 10,
      step = 1
    }
  }
}, config.plugins.profiler)

---@class plugins.profiler
local Profiler = {}

function Profiler.start()
  if RUNNING then return end
  if not LUAJIT or not config.plugins.profiler.jit_profiler then
    profiler_lua.start()
  elseif config.plugins.profiler.raw then
    profiler_jit_high.start("G", config.plugins.profiler.log_file)
  elseif config.plugins.profiler.highlevel then
    profiler_jit_high.start(
      config.plugins.profiler.depth .. config.plugins.profiler.options,
      config.plugins.profiler.log_file
    )
  else
    profiler_data = {}
    profiler_jit.start("li1", function(th, samples, vmstate)
      local sep = ""
      if config.plugins.profiler.depth > 1 then
        sep = " <- "
      end
      local path = profiler_jit.dumpstack(th, "pl"..sep, config.plugins.profiler.depth)
      local dump = profiler_jit.dumpstack(th, "f"..sep, config.plugins.profiler.depth)
      profiler_data[dump] = {
        (profiler_data[dump] and profiler_data[dump][1] or 0) + samples,
        path,
        vmstate
      }
    end)
  end
  RUNNING = true
end

---@param str string
---@param text string
---@param replacement string
---@return string
local function replace(str, text, replacement)
  local s, e = str:find(text, 1, true)
  while s do
    local new_text = str:sub(1,s-1) .. replacement
    local next_index = #new_text + 1
    str = new_text .. str:sub(e+1)
    s, e = str:find(text, next_index, true)
  end
  return str
end

function Profiler.stop()
  if RUNNING then
    if not LUAJIT or not config.plugins.profiler.jit_profiler then
      profiler_lua.stop()
      profiler_lua.report(config.plugins.profiler.log_file)
    elseif config.plugins.profiler.raw or config.plugins.profiler.highlevel then
      profiler_jit_high.stop()
    else
      profiler_jit.stop()
      local log_file = io.open(config.plugins.profiler.log_file, "w+")
      if log_file then
        local sorted_data = {}
        local sw, dw = 0, 0
        for dump, data in pairs(profiler_data) do
          if config.plugins.profiler.depth > 1 then
            dump = string.gsub(dump, " <%- $", "")
            data[2] = string.gsub(data[2], " <%- $", "")
          end
          data[2] = replace(data[2], DATADIR .. PATHSEP, "")
          data[2] = replace(data[2], USERDIR .. PATHSEP, "")
          sw = math.max(sw, string.len(tostring(data[1])))
          dw = math.max(dw, #dump)
          table.insert(sorted_data, {dump, data})
        end
        table.sort(sorted_data, function (a, b)
          return a[2][1] > b[2][1]
        end)
        local state = {
          N = "Compiled",
          I = "Interpreted",
          C = "C Code",
          G = "Garbage Collector",
          J = "JIT compiler"
        }
        log_file:write(
          string.format(
            "%-"..sw.."s | %-"..dw.."s | %s\n",
            "#",
            "Func",
            "State"
          )
        )
        local divider = string.rep("-", sw + 3 + dw + 3 + 17) .. "\n"
        log_file:write(divider)
        for _, data in ipairs(sorted_data) do
          -- samples | dump | vmstate,
          --         | locations
          log_file:write(
            string.format(
              "%-"..sw.."s | %-"..dw.."s | %s\n",
              data[2][1],
              data[1],
              state[data[2][3]]
            )
          )
          for location in (data[2][2].." <- "):gmatch("(.-)".." <%- ") do
            log_file:write(
              string.format(
                "%-"..sw.."s  -> %s\n",
                "",
                location
              )
            )
          end
          log_file:write(divider)
        end
        log_file:close()
      end
    end
    profiler_data = {}
    RUNNING = false
  end
end

--------------------------------------------------------------------------------
-- Run profiler at startup if enabled.
--------------------------------------------------------------------------------
if system.get_file_info(SETTINGS_PATH) then
  local ok, t = pcall(dofile, SETTINGS_PATH)
  if ok and t.config and t.config.plugins and t.config.plugins.profiler then
    local options = t.config.plugins.profiler
    local profiler_ref = config.plugins.profiler
    profiler_ref.enable_on_startup = options.enable_on_startup or false
    profiler_ref.log_file = options.log_file or DEFAULT_LOG_PATH
  end
end

if config.plugins.profiler.enable_on_startup then
  Profiler.start()
end

--------------------------------------------------------------------------------
-- Override core.run to stop profiler before exit if running.
--------------------------------------------------------------------------------
local core_run = core.run
function core.run(...)
  core_run(...)
  Profiler.stop()
end

--------------------------------------------------------------------------------
-- Add a profiler toggle command.
--------------------------------------------------------------------------------
command.add(nil, {
  ["profiler:toggle"] = function()
    if RUNNING then
      Profiler.stop()
      if not config.plugins.profiler.raw then
        core.log("Profiler: stopped")
        core.root_view:open_doc(core.open_doc(config.plugins.profiler.log_file))
        -- in case the document was already open we reload it
        core.add_thread(function ()
          command.perform "doc:reload"
        end)
      else
        core.log("Profiler: stopped and raw data saved to log file")
      end
    else
      Profiler.start()
      core.log("Profiler: started")
    end
  end
})


return Profiler
