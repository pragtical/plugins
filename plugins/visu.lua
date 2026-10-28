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
  pollRate = 60,
  cavaFrameRate = 60,
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
          visu:start()
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
        if visu.started then visu:start(nil, mode) end
      end
    },
    {
      label = "Poll Rate",
      description = "How many times per second to retrieve data from cava on "
        .. "workers mode. If visualization is out of sync try increasing this "
        .. "value to be higher than the cava frame rate.",
      path = "pollRate",
      type = "NUMBER",
      default = 60,
      min = 1,
      on_apply = function()
        if not visu_initialized then return end
        if visu.started then visu:start() end
      end
    },
    {
      label = "Cava Frame Rate",
      description = "Amount of frames per second that cava will generate.",
      path = "cavaFrameRate",
      type = "NUMBER",
      default = 60,
      min = 1,
      on_apply = function()
        if not visu_initialized then return end
        if visu.started then visu:start() end
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
        if visu.started then visu:start(value) end
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
framerate = %d

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
  self.workers = false
  self.tmpConfFile = nil
  self.chunkSize = 0
  self.bars = 1
  self.barsInfo = nil
  self.started = false
  self.pollRate = 1 / 200
end

---@param bars? integer
---@param fetchMode? "workers" | "ondraw" | "both"
function Visu:start(bars, fetchMode)
  self:stop()

  bars = bars or config.plugins.visu.barsNumber
  fetchMode = fetchMode or config.plugins.visu.fetchMode
  self.bars = bars
  self.fetchMode = fetchMode
  self.chunkSize = 2 * bars
  self.dataFormat = Visu.byteFormat:rep(bars)

  local cavaConf = Visu.confFormat:format(
    bars, config.plugins.visu.cavaFrameRate, '/dev/stdout', '16bit'
  )
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

    self.started = true
    self.pollRate = 1 / config.plugins.visu.pollRate
    self.pendingInfo = ""
    self.barsInfo = self:getLatestInfo()

    -- Cava has one output stream. One reader also wakes the On Draw mode.
    core.add_thread(function()
      local quiet_since = system.get_time()
      while self.started and self.proc do
        local latest = self:getLatestInfo()
        if latest then
          -- Skip queued old frames without letting a producer starve the UI.
          for _ = 1, 64 do
            local next_frame = self:getLatestInfo()
            if not next_frame then break end
            latest = next_frame
          end
          local changed = not self.barsInfo
          for i, value in ipairs(latest) do
            local previous = self.barsInfo and self.barsInfo[i] or 0
            changed = changed or value ~= previous
          end
          self.barsInfo = latest
          if changed then core.redraw = true end
          quiet_since = system.get_time()
        end
        local delay = math.max(.001, self.pollRate)
        if system.get_time() - quiet_since >= 1 then delay = math.max(delay, .05) end
        coroutine.yield(delay)
      end
    end, self)
    self.workers = true
    core.redraw = true
  end
end

function Visu:stop()
  if self.started then core.redraw = true end
  if self.workers then
    core.threads[self] = nil
    self.workers = false
  end
  if self.proc then
    self.proc:terminate()
    self.proc = nil
  end
  if self.tmpConfFile then
    os.remove(self.tmpConfFile)
    self.tmpConfFile = nil
  end
  self.started = false
end

---@return table<integer,number> | nil
function Visu:getLatestInfo()
  if not self.proc then return nil end
  local pending = self.pendingInfo or ""
  local data = self.proc:read_stdout(self.chunkSize - #pending)

  if not data or #data == 0 then return nil end
  pending = pending .. data
  self.pendingInfo = pending
  if #pending < self.chunkSize then return nil end
  data, self.pendingInfo = pending, ""

  local bars = table.pack(string.unpack(self.dataFormat, data))
  bars[self.bars + 1], bars.n = nil, nil

  for i, b in ipairs(bars) do
    bars[i] = b / Visu.byteMax
  end

  return bars
end

function Visu:render(rootview)
  if (not config.plugins.visu.enabled and not self.started) or not self.proc then
    return
  end

  if core.active_view == core.command_view then return end
  local w = 10 * SCALE

  local fetchMode = self.fetchMode
  if fetchMode == "ondraw" or fetchMode == "both" then
    local newInfo = self:getLatestInfo()
    if newInfo ~= nil then
      self.barsInfo = newInfo
    end
  end

  if self.barsInfo then
    for i = 1, self.bars do
      local h = ((self.barsInfo[i] * 239)) * SCALE
      if h > 0 then
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
      config.plugins.visu.fetchMode
    )
  end
  visu_initialized = true
end)

local RootView_draw = RootView.draw
function RootView:draw(...)
  RootView_draw(self, ...)
  visu:render(self)
end

command.add(nil, {
  ['visu:stop'] = function()
    visu:stop()
    core.log("Audio Visualizer: Stopped")
  end,

  ['visu:start'] = function()
    visu:start(
      config.plugins.visu.barsNumber,
      config.plugins.visu.fetchMode
    )
    core.log("Audio Visualizer: Started")
  end,

  ['visu:toggle'] = function()
    if visu.started then
      visu:stop()
    else
      visu:start()
    end
    core.log(
      "Audio Visualizer: %s",
      visu.started and "Started" or "Stopped"
    )
  end,
})


return visu
