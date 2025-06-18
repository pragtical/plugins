-- mod-version:3
-- Adaptation of https://github.com/TorchedSammy/Visu for Pragtical
-- License: MIT | Copyright (c) 2022 TorchedSammy
local core = require 'core'
local common = require 'core.common'
local command = require 'core.command'
local style = require 'core.style'
local config = require 'core.config'
local RootView = require 'core.rootview'
local Object = require 'core.object'

---@type plugins.visu
local visu

local visu_initialized = false

config.plugins.visu = common.merge({
  enabled = true,
  fetchMode = "workers", -- workers, ondraw, both
  workers = 1,
  barsNumber = 10,
  barsCustomColor = false,
  barsColor = table.pack(table.unpack(style.text)),
  -- The config specification used by the settings gui
  config_spec = {
    name = "Audio Visualizer",
    {
      label = "Enable",
      description = "Enable or disable the audio visualizer.",
      path = "enabled",
      type = "TOGGLE",
      default = true,
      on_apply = function(enabled)
        if not visu_initialized then return end
        if enabled then
          visu:start(
            config.plugins.visu.barsNumber,
            config.plugins.visu.fetchMode,
            config.plugins.visu.workers
          )
        else
          visu:stop()
        end
      end
    },
    {
      label = "Fetch Mode",
      description = "The strategy used to fetch the visualization data. "
        .. "Use 'Workers' to let the scheduler handle it on a reasonable time, "
        .. "'On Draw' for more precise data (may cause UI stuttering) or "
        .. "'Both' to use the two methods at the same time.",
      path = "fetchMode",
      type = "selection",
      default = "workers",
      values = {
        { "Workers", "workers" },
        { "On Draw", "ondraw" },
        { "Both", "both" }
      },
      on_apply = function(mode)
        if not visu_initialized then return end
        if config.plugins.visu.enabled then
          visu:start(
            config.plugins.visu.barsNumber,
            mode,
            config.plugins.visu.workers
          )
        else
          visu:stop()
        end
      end
    },
    {
      label = "Workers",
      description = "On 'workers' mode this is the amount of co-routines to "
        .. "scan the spectrum data from cava.",
      path = "workers",
      type = "NUMBER",
      default = 1,
      min = 1,
      on_apply = function(value)
        if not visu_initialized then return end
        if config.plugins.visu.enabled then
          visu:start(
            config.plugins.visu.barsNumber,
            config.plugins.visu.fetchMode,
            value
          )
        end
      end
    },
    {
      label = "Spectrum Analyzer Bars",
      description = "Amount of spectrum bars to show.",
      path = "barsNumber",
      type = "NUMBER",
      default = 10,
      min = 2,
      step = 2,
      on_apply = function(value)
        if not visu_initialized then return end
        if config.plugins.visu.enabled then
          visu:start(
            value,
            config.plugins.visu.fetchMode,
            config.plugins.visu.workers
          )
        end
      end
    },
    {
      label = "Custom Spectrum Color",
      description = "Use a custom color for spectrum bars.",
      path = "barsCustomColor",
      type = "toggle",
      default = true
    },
    {
      label = "Spectrum Analyzer Color",
      description = "Color used for the spectrum bars.",
      path = "barsColor",
      type = "color",
      default = table.pack(table.unpack(style.text))
    }
  }
}, config.plugins.visu)

---@class plugins.visu : core.object
local Visu = Object:extend()

Visu.byteFormat = 'H'
Visu.byteMax = 65535
Visu.confFormat = [[
[general]
bars = %d

[output]
method = raw
raw_target = %s
bit_format = %s
]]

---@overload fun():plugins.visu
function Visu:new()
  Visu.super.new(self)
  self.proc = nil
  self.fetchMode = "workers"
  self.workers = {}
  self.tmpConfFile = nil
  self.chunkSize = 0
  self.bars = 1
  self.barsInfo = nil
end

---@param bars? integer
---@param fetchMode? "workers" | "ondraw" | "both"
---@param workers? integer
function Visu:start(bars, fetchMode, workers)
  self:stop()

  bars = bars or 10
  workers = workers or 1
  self.bars = bars
  self.fetchMode = fetchMode or "workers"
  self.chunkSize = 2 * bars

  local cavaConf = Visu.confFormat:format(bars, '/dev/stdout', '16bit')
  local tmp = core.temp_filename('cavaconf', '/tmp')
  self.tmpConfFile = tmp

  local f = io.open(tmp, 'w')
  if f then
    f:write(cavaConf)
    f:close()

    local perr
    local created, pcerr = pcall(function()
      self.proc, perr = process.start {'cava', '-p', tmp}
    end)
    if not created or not self.proc then
      core.error(
        "Could not start the audio visualizer with error:\n\n%s\n\n"
          .. "Make sure that cava is installed on your system.\n"
          .. "https://github.com/karlstav/cava",
        (perr or pcerr or "unknown error")
      )
      os.remove(tmp)
      return
    end

    self.barsInfo = self:getLatestInfo()

    if self.fetchMode == "workers" or self.fetchMode == "both" then
      for _ = 1, workers do
        local wid = core.add_thread(function()
          while true do
            local newBarsInfo = self:getLatestInfo()
            if newBarsInfo ~= nil then
              self.barsInfo = newBarsInfo
            end
            coroutine.yield(0)
          end
        end)
        core.threads[wid].visu = true
        table.insert(self.workers, wid)
      end
    end
  end
end

function Visu:stop()
  if #self.workers > 0 then
    for _, wid in ipairs(self.workers) do
      if core.threads[wid] and core.threads[wid].visu then
        core.threads[wid].cr = coroutine.create(function() end)
      end
    end
    self.workers = {}
  end
  if self.proc then
    self.proc:terminate()
    self.proc = nil
  end
  if self.tmpConfFile then
    os.remove(self.tmpConfFile)
    self.tmpConfFile = nil
  end
end

---@return table<integer,number> | nil
function Visu:getLatestInfo()
  if not self.proc then return nil end
  local data = self.proc:read_stdout(self.chunkSize)

  if not data or data:len() < self.chunkSize then return nil end

  local fmt = Visu.byteFormat:rep(self.bars)
  local bars = table.pack(string.unpack(fmt, data))

  for i, b in ipairs(bars) do
    bars[i] = b / Visu.byteMax
  end

  return bars
end

function Visu:render(rootview)
  if not config.plugins.visu.enabled or not self.proc then return end

  if core.active_view == core.command_view then return end
  local w = 10 * SCALE

  local fetchMode = self.fetchMode
  if fetchMode == "ondraw" or fetchMode == "both" then
    local newInfo = self:getLatestInfo()
    if newInfo ~= nil then
      self.barsInfo = newInfo
    end
  end

  if self.barsInfo ~= nil then
    for i = 1, self.bars do
      local h = ((self.barsInfo[i] * 239)) * SCALE
      if h > 0 then
        core.redraw = true

        local color = not config.plugins.visu.barsCustomColor
          and style.text
          or config.plugins.visu.barsColor

        -- y = self.size.y - core.status_view.size.y

        renderer.draw_rect(
          rootview.size.x - ((30 * i) * SCALE),
          rootview.size.y - core.status_view.size.y - h - (5 * SCALE),
          w, h,
          color
        )

        -- dual in the middle
        --[[ renderer.draw_rect(
          rootview.size.x - (30 * i),
          (rootview.size.y / 2),
          w, h / 2,
        color)

        renderer.draw_rect(
          rootview.size.x - (30 * i),
          rootview.size.y / 2 - h / 2,
          w, h / 2,
          color
        ) ]]
      end
    end
  end
end

visu = Visu()

core.add_thread(function()
  if config.plugins.visu.enabled then
    visu:start(
      config.plugins.visu.barsNumber,
      config.plugins.visu.fetchMode,
      config.plugins.visu.workers
    )
    visu_initialized = true
  end
end)

local RootView_draw = RootView.draw
function RootView:draw(...)
  RootView_draw(self, ...)
  visu:render(self)
end

command.add(nil, {
  ['visu:stop'] = function()
    visu:stop()
  end,

  ['visu:start'] = function()
    visu:start(
      config.plugins.visu.barsNumber,
      config.plugins.visu.fetchMode,
      config.plugins.visu.workers
    )
  end,
})


return visu
