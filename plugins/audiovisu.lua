-- mod-version:3.12.5 priority:0
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local style = require "core.style"
local RootView = require "core.rootview"
local View = require "core.view"
local keymap = require "core.keymap"
local Canvas = require "canvas"

local audiovisu = {}
local FRAMES = 2048
local supported, audio = pcall(require, "audio")
supported = supported and type(audio) == "table" and type(audio.create_mixer) == "function"
local active, reported = false, false
local sync_enabled
local apply_presentation
local advance_visualizers

local effects = {
  { "Warp", "warp" }, { "Alchemy", "alchemy" }, { "Battery", "battery" },
  { "Spikes", "spikes" }, { "Scope", "scope" }, { "Particle", "particle" },
  { "Spectrum Bars", "bars" }, { "Random", "random" }
}

local function redraw() core.redraw = true end
local function number_option(label, path, default, min, max)
  return {
    label = label, path = path, default = default, min = min, max = max,
    type = "number", on_apply = redraw
  }
end

config.plugins.audiovisu = common.merge({
  enabled = true,
  presentation = "overlay",
  effect = "warp",
  random_interval = 20,
  effect_speed = 1,
  effect_custom_color = false,
  effect_color = { table.unpack(style.text) },
  vertical_position = "bottom",
  horizontal_position = "right",
  bar_count = 24,
  bar_spacing = 3,
  width = 320,
  height = 160,
  margin = 12,
  fps = 30,
  sensitivity = 1,
  decay = 0.25,
  custom_color = false,
  color = { table.unpack(style.text) },
  config_spec = {
    name = "Editor Audio Visualizer",
    {
      label = "Enable", path = "enabled", type = "toggle", default = true,
      on_apply = function(enabled)
        if sync_enabled then sync_enabled() end
        if enabled and apply_presentation and core.window then apply_presentation() end
      end
    },
    {
      label = "Display Mode", path = "presentation", type = "selection", default = "overlay",
      values = {
        { "Spectrum Overlay", "overlay" }, { "Visualizer Tab", "view" },
        { "Fullscreen Visualizer", "fullscreen" }
      },
      on_apply = function() if apply_presentation then apply_presentation() end end
    },
    {
      label = "View Effect", path = "effect", type = "selection", default = "warp",
      values = effects, on_apply = redraw
    },
    number_option("Random Effect Seconds", "random_interval", 20, 5, 300),
    number_option("Effect Speed", "effect_speed", 1, 0.1, 5),
    {
      label = "Custom Effect Color", path = "effect_custom_color", type = "toggle",
      default = false, on_apply = redraw
    },
    {
      label = "Effect Color", path = "effect_color", type = "color",
      default = { table.unpack(style.text) }, on_apply = redraw
    },
    {
      label = "Vertical Position", path = "vertical_position", type = "selection",
      default = "bottom", on_apply = redraw,
      values = { { "Top", "top" }, { "Center", "center" }, { "Bottom", "bottom" } }
    },
    {
      label = "Horizontal Position", path = "horizontal_position", type = "selection",
      default = "right", on_apply = redraw,
      values = { { "Left", "left" }, { "Center", "center" }, { "Right", "right" } }
    },
    number_option("Bars", "bar_count", 24, 2, 128),
    number_option("Bar Spacing", "bar_spacing", 3, 0, 64),
    number_option("Width", "width", 320, 32, 2048),
    number_option("Height", "height", 160, 16, 1024),
    number_option("Margin", "margin", 12, 0, 128),
    number_option("Frame Rate", "fps", 30, 5, 60),
    number_option("Sensitivity", "sensitivity", 1, 0.1, 10),
    number_option("Decay Seconds", "decay", 0.25, 0.05, 2),
    {
      label = "Custom Bar Color", path = "custom_color", type = "toggle",
      default = false, on_apply = redraw
    },
    {
      label = "Bar Color", path = "color", type = "color",
      default = { table.unpack(style.text) }, on_apply = redraw
    }
  }
}, config.plugins.audiovisu)

local function settings()
  local options = config.plugins.audiovisu
  return type(options) == "table" and options or {}
end

local function number(name, default, min, max)
  local value = settings()[name]
  if type(value) ~= "number" or value ~= value then value = default end
  return common.clamp(value, min, max)
end

local function report(err)
  if not reported then
    reported = true
    core.error("Editor Audio Visualizer: %s", err)
  end
end

-- Forward radix-2/4 FFT adapted from zorggn/zorg-fft's plain Lua version:
-- https://github.com/zorggn/zorg-fft/blob/master/src/lua/zfft.lua
-- Its unused FFI import, inverse transform, and other radices are omitted.
--
-- Copyright (c) 2020 zorg (ISC):
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
-- ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
-- OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
-- CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
--
-- Based on luafft, Copyright (c) 2011 Benjamin von Ardenne (MIT):
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
-- THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--
-- Based on KISS FFT, Copyright (c) 2003-2010 Mark Borgerding (BSD-3-Clause):
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright
--    notice, this list of conditions and the following disclaimer in the
--    documentation and/or other materials provided with the distribution.
-- 3. Neither the name of the copyright holder nor the names of its
--    contributors may be used to endorse or promote products derived from
--    this software without specific prior written permission.
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
-- POSSIBILITY OF SUCH DAMAGE.
local tw_re, tw_im, window, window_sum = {}, {}, {}, 0
for i = 0, FRAMES - 1 do
  local phase = 2 * math.pi * i / FRAMES
  tw_re[i + 1], tw_im[i + 1] = math.cos(phase), -math.sin(phase)
  window[i + 1] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (FRAMES - 1))
  window_sum = window_sum + window[i + 1]
end

local input, real, imaginary = {}, {}, {}
local function fft_work(offset, source, stride, count)
  local radix = count % 4 == 0 and 4 or 2
  local m = count / radix
  for j = 0, radix - 1 do
    if m == 1 then
      real[offset + j], imaginary[offset + j] = input[source + j * stride], 0
    else
      fft_work(offset + j * m, source + j * stride, stride * radix, m)
    end
  end
  for k = 0, m - 1 do
    local i, t = offset + k, 1 + k * stride
    local ar, ai = real[i], imaginary[i]
    local br = real[i + m] * tw_re[t] - imaginary[i + m] * tw_im[t]
    local bi = real[i + m] * tw_im[t] + imaginary[i + m] * tw_re[t]
    if radix == 2 then
      real[i], imaginary[i] = ar + br, ai + bi
      real[i + m], imaginary[i + m] = ar - br, ai - bi
    else
      local t2, t3 = 1 + k * stride * 2, 1 + k * stride * 3
      local cr = real[i + 2*m] * tw_re[t2] - imaginary[i + 2*m] * tw_im[t2]
      local ci = real[i + 2*m] * tw_im[t2] + imaginary[i + 2*m] * tw_re[t2]
      local dr = real[i + 3*m] * tw_re[t3] - imaginary[i + 3*m] * tw_im[t3]
      local di = real[i + 3*m] * tw_im[t3] + imaginary[i + 3*m] * tw_re[t3]
      real[i], imaginary[i] = ar + cr + br + dr, ai + ci + bi + di
      real[i + m], imaginary[i + m] = ar - cr + bi - di, ai - ci - br + dr
      real[i + 2*m], imaginary[i + 2*m] = ar + cr - br - dr, ai + ci - bi - di
      real[i + 3*m], imaginary[i + 3*m] = ar - cr - bi + di, ai - ci + br - dr
    end
  end
end

local function finite(value)
  return value == value and value ~= math.huge and value ~= -math.huge and value or 0
end

local function analyze(samples, spec, power, bars)
  local channels = spec.channels
  local frames = math.min(FRAMES, math.floor(#samples / channels))
  if frames < 2 then return 0, 1 end
  local top = math.min(16000, spec.sample_rate / 2)
  local bottom = math.min(40, top / 2)
  local factor = 4 / (window_sum * window_sum * channels)
  local span, strongest = 0, 1
  for channel = 1, channels do
    local sum, low, high = 0, math.huge, -math.huge
    for i = 1, frames do
      local sample = finite(samples[(i - 1) * channels + channel])
      sum, low, high = sum + sample, math.min(low, sample), math.max(high, sample)
    end
    if high - low > span then span, strongest = high - low, channel end
    if high - low > 1e-7 then
      local mean = sum / frames
      for i = 1, FRAMES do
        input[i] = i <= frames
          and (finite(samples[(i - 1) * channels + channel]) - mean) * window[i] or 0
      end
      fft_work(1, 1, 1, FRAMES)
      for bar = 1, bars do
        local first = math.max(1, math.floor(bottom * (top / bottom)^((bar - 1) / bars) * FRAMES / spec.sample_rate))
        local last = math.min(FRAMES / 2, math.max(first,
          math.floor(bottom * (top / bottom)^(bar / bars) * FRAMES / spec.sample_rate) - 1))
        local peak = 0
        for bin = first, last do
          peak = math.max(peak, real[bin + 1]^2 + imaginary[bin + 1]^2)
        end
        power[bar] = power[bar] + peak * factor
      end
    end
  end
  return span, strongest
end

local mixers = setmetatable({}, { __mode = "k" })
local groups = setmetatable({}, { __mode = "k" })
local hooked = {}
local levels, pixels, powers = {}, {}, {}
local signal = { bass = 0, middle = 0, treble = 0, energy = 0, beat = 0, wave = {} }
local wave_target = {}

local function wake()
  local thread = core.threads[audiovisu]
  if active and thread then thread.wake = 0 end
end

local function capture(mixer, state, enabled)
  if enabled and state.failed then return end
  local frames = enabled and math.max(FRAMES, state.requested) or state.requested
  local ok, err = state.set_buffer(mixer, frames)
  if not ok then
    state.failed = true
    report(err)
  end
end

sync_enabled = function()
  local options = config.plugins.audiovisu
  local enabled = supported and type(options) == "table" and options.enabled ~= false
  if active == enabled then return end
  active = enabled
  for mixer, state in pairs(mixers) do capture(mixer, state, active) end
  if not active then
    for i = 1, #levels do levels[i], pixels[i] = 0, 0 end
    if audiovisu.exit_fullscreen then audiovisu.exit_fullscreen() end
  end
  redraw()
  wake()
end

local function hook_resume(mt)
  local original = mt.resume
  mt.resume = function(...)
    local result = table.pack(original(...))
    if result[1] then wake() end
    return table.unpack(result, 1, result.n)
  end
end

local function hook_play(mt, name, states)
  local original = mt[name]
  mt[name] = function(self, ...)
    local result = table.pack(original(self, ...))
    local state = states[self]
    if state and result[1] then
      state.voices[result[1]] = true
      state.pending = true
      local voice_mt = getmetatable(result[1])
      if not hooked[voice_mt] then
        hooked[voice_mt] = true
        hook_resume(voice_mt)
      end
      wake()
    end
    return table.unpack(result, 1, result.n)
  end
end

local function hook_group(group)
  local mt = getmetatable(group)
  if hooked[mt] then return end
  hooked[mt] = true
  hook_resume(mt)
  for _, name in ipairs { "play", "play_file", "play_stream" } do
    hook_play(mt, name, groups)
  end
end

local function hook_mixer(mixer)
  local mt = getmetatable(mixer)
  if hooked[mt] then return end
  if type(mt.set_sample_buffer) ~= "function" or type(mt.get_samples) ~= "function" then
    supported = false
    report("This editor does not support mixer sample buffers.")
    return
  end
  local set_buffer, group, close = mt.set_sample_buffer, mt.group, mt.close
  hooked[mt] = set_buffer
  hook_resume(mt)
  mt.set_sample_buffer = function(self, frames, ...)
    local state = mixers[self]
    -- Invalid arguments must still be validated by the native API.
    if not state or type(frames) ~= "number" or frames < 0
      or frames > 65536 or frames % 1 ~= 0 then
      return set_buffer(self, frames, ...)
    end
    local capacity = active and not state.failed and math.max(FRAMES, frames) or frames
    local result = table.pack(set_buffer(self, capacity, ...))
    if result[1] then state.requested = frames end
    return table.unpack(result, 1, result.n)
  end
  mt.group = function(self, ...)
    local result = table.pack(group(self, ...))
    if result[1] and mixers[self] then
      groups[result[1]] = mixers[self]
      hook_group(result[1])
    end
    return table.unpack(result, 1, result.n)
  end
  mt.close = function(self, ...)
    local result = table.pack(close(self, ...))
    local state = mixers[self]
    if state then state.voices = {} end
    mixers[self] = nil
    return table.unpack(result, 1, result.n)
  end
  for _, name in ipairs { "play", "play_file", "play_stream" } do
    hook_play(mt, name, mixers)
  end
end

local last_time = system.get_time()
local function update()
  sync_enabled()
  local bars = math.floor(number("bar_count", 24, 2, 128))
  local changed = #levels ~= bars
  for i = 1, bars do powers[i] = 0 end
  if changed then
    levels, pixels = {}, {}
    for i = 1, bars do levels[i], pixels[i] = 0, 0 end
  end
  local playing = false
  local strongest = 0
  for i = 1, 256 do wave_target[i] = 0 end
  for mixer, state in pairs(mixers) do
    local running, terminal = false, false
    for voice in pairs(state.voices) do
      local status = voice:get_state()
      if status == "playing" then running = true end
      if status == "finished" or status == "stopped" then
        state.voices[voice] = nil
        terminal = true
      end
    end
    playing = playing or running
    if active and not state.failed and (running or terminal and state.pending) then
      local samples, spec, err = mixer:get_samples(FRAMES)
      if samples then
        local span, channel = analyze(samples, spec, powers, bars)
        if span > strongest then
          strongest = span
          local frames = math.floor(#samples / spec.channels)
          for i = 1, 256 do
            local frame = math.min(frames - 1, math.floor((i - 1) * frames / 256))
            wave_target[i] = finite(samples[frame * spec.channels + channel])
          end
        end
      else
        state.failed = true
        report(err)
      end
    end
    state.pending = false
  end
  local now = system.get_time()
  local dt = math.max(0, now - last_time)
  last_time = now
  local height = number("height", 160, 16, 1024) * SCALE
  local sensitivity = number("sensitivity", 1, 0.1, 10)
  local release = number("decay", 0.25, 0.05, 2)
  local moving = false
  for i = 1, bars do
    local amplitude = math.sqrt(powers[i]) * sensitivity
    local target = active and amplitude > 1e-6
      and common.clamp((20 * math.log(amplitude) / math.log(10) + 60) / 60, 0, 1) or 0
    local level = levels[i]
    level = target + (level - target) * math.exp(-dt / (target > level and 0.035 or release))
    if level < 0.001 then level = 0 end
    local pixel = math.floor(level * height + 0.5)
    changed = changed or pixel ~= pixels[i]
    levels[i], pixels[i] = level, pixel
    moving = moving or level > 0
  end
  local bass, middle, treble = 0, 0, 0
  local lower, upper = math.max(1, math.floor(bars / 3)), math.floor(bars * 2 / 3)
  for i = 1, bars do
    if i <= lower then bass = bass + levels[i]
    elseif i <= upper then middle = middle + levels[i]
    else treble = treble + levels[i] end
  end
  bass, middle, treble = bass / lower, middle / math.max(1, upper - lower), treble / math.max(1, bars - upper)
  signal.beat = math.max(signal.beat * math.exp(-dt / 0.18), math.min(1, math.max(0, bass - signal.bass) * 8))
  signal.bass, signal.middle, signal.treble = bass, middle, treble
  signal.energy = (bass + middle + treble) / 3
  for i = 1, 256 do
    local old = signal.wave[i] or 0
    local target = active and common.clamp(wave_target[i] * sensitivity, -1, 1) or 0
    signal.wave[i] = target + (old - target) * math.exp(-dt / (strongest > 0 and 0.02 or release))
  end
  local visual_changed = advance_visualizers and advance_visualizers(dt, playing or moving)
  if visual_changed or changed and (settings().presentation or "overlay") == "overlay" then redraw() end
  return active and (playing or moving) and 1 / number("fps", 30, 5, 60) or 0.2
end

local function content_bounds(node, bounds)
  if node.type ~= "leaf" then
    content_bounds(node.a, bounds)
    content_bounds(node.b, bounds)
  elseif not node.locked or not (node.locked.x or node.locked.y) then
    local view = node.active_view
    if view and view.size.x > 0 and view.size.y > 0 then
      local x, y = view.position.x, view.position.y
      bounds[1], bounds[2] = math.min(bounds[1], x), math.min(bounds[2], y)
      bounds[3], bounds[4] = math.max(bounds[3], x + view.size.x), math.max(bounds[4], y + view.size.y)
    end
  end
end

local function render(root)
  if not active or (settings().presentation or "overlay") ~= "overlay"
    or core.active_view == core.command_view then return end
  local bounds = { math.huge, math.huge, -math.huge, -math.huge }
  content_bounds(root.root_node, bounds)
  bounds[1], bounds[3] = root.position.x, root.position.x + root.size.x
  local width, height = bounds[3] - bounds[1], bounds[4] - bounds[2]
  if width <= 0 or height <= 0 then return end
  local margin = math.min(number("margin", 12, 0, 128) * SCALE, width / 4, height / 4)
  local w = math.min(number("width", 320, 32, 2048) * SCALE, width - margin * 2)
  local h = math.min(number("height", 160, 16, 1024) * SCALE, height - margin * 2)
  local options = settings()
  local horizontal = options.horizontal_position == "left" and 0
    or options.horizontal_position == "center" and 0.5 or 1
  local vertical = options.vertical_position == "top" and 0
    or options.vertical_position == "center" and 0.5 or 1
  local x = bounds[1] + margin + (width - margin * 2 - w) * horizontal
  local y = bounds[2] + margin + (height - margin * 2 - h) * vertical
  local count = #levels
  if count == 0 then return end
  local gap = math.min(number("bar_spacing", 3, 0, 64) * SCALE, math.max(0, w / count - 1))
  local color = options.custom_color and options.color or style.text
  core.push_clip_rect(bounds[1], bounds[2], width, height)
  for i = 1, count do
    local bar_x = math.floor(x + (i - 1) * w / count)
    local bar_w = math.floor(x + i * w / count - gap) - bar_x
    local bar_h = math.floor(levels[i] * h + 0.5)
    if bar_h > 0 and bar_w > 0 then
      local bar_y = options.vertical_position == "top" and math.floor(y)
        or options.vertical_position == "center" and math.floor(y + (h - bar_h) / 2)
        or math.floor(y + h) - bar_h
      renderer.draw_rect(bar_x, bar_y, bar_w, bar_h, color)
    end
  end
  core.pop_clip_rect()
end

local scene_serial = 0
local function new_scene()
  scene_serial = scene_serial + 1
  return {
    time = 0, age = 0, frame = 0, seed = 12345 + scene_serial * 1777,
    audio = { bass = 0, middle = 0, treble = 0, energy = 0, beat = 0, wave = {}, levels = {} }
  }
end

local function random(scene)
  scene.seed = scene.seed * 48271 % 2147483647
  return scene.seed / 2147483647
end

local function choose_effect(scene, force)
  local requested = settings().effect or "warp"
  if not force and scene.requested == requested
    and (requested ~= "random" or scene.age < number("random_interval", 20, 5, 300)) then
    return
  end
  local selected = requested
  if selected == "random" then
    local choices = {}
    for i = 1, #effects - 1 do
      if effects[i][2] ~= scene.effect then choices[#choices + 1] = effects[i][2] end
    end
    selected = choices[math.floor(random(scene) * #choices) + 1]
  else
    local valid = false
    for i = 1, #effects - 1 do if effects[i][2] == selected then valid = true end end
    if not valid then selected = "warp" end
  end
  scene.requested, scene.effect, scene.age = requested, selected, 0
  scene.field, scene.previous, scene.image, scene.canvas = nil, nil, nil, nil
  scene.rendered_frame = nil
  redraw()
end

local function effect_color(scene, hue, brightness, alpha)
  brightness = common.clamp(brightness, 0, 1)
  local custom = settings()
  if custom.effect_custom_color and type(custom.effect_color) == "table" then
    return {
      math.floor(custom.effect_color[1] * brightness), math.floor(custom.effect_color[2] * brightness),
      math.floor(custom.effect_color[3] * brightness), alpha or custom.effect_color[4] or 255
    }
  end
  local h = ((hue + scene.time * 0.025) % 1) * 6
  local sector, f = math.floor(h), h % 1
  local low, falling, rising = 0.1, 1 - f * 0.9, 0.1 + f * 0.9
  local r, g, b
  if sector == 0 then r, g, b = 1, rising, low
  elseif sector == 1 then r, g, b = falling, 1, low
  elseif sector == 2 then r, g, b = low, 1, rising
  elseif sector == 3 then r, g, b = low, falling, 1
  elseif sector == 4 then r, g, b = rising, low, 1
  else r, g, b = 1, low, falling end
  return { math.floor(r * brightness * 255), math.floor(g * brightness * 255),
    math.floor(b * brightness * 255), alpha or 255 }
end

-- A filled strip keeps a glowing curve to a few draw calls instead of one per segment.
local function draw_path(points, width, color, target)
  local polygon, count = {}, #points
  for i = 1, count do
    local before, after = points[math.max(1, i - 1)], points[math.min(count, i + 1)]
    local dx, dy = after[1] - before[1], after[2] - before[2]
    local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
    local nx, ny = -dy / length * width / 2, dx / length * width / 2
    polygon[i] = { points[i][1] + nx, points[i][2] + ny }
    polygon[count * 2 - i + 1] = { points[i][1] - nx, points[i][2] - ny }
  end
  if target then target:draw_poly(polygon, color) else renderer.draw_poly(polygon, color) end
end

local function glow_path(scene, points, hue, width, brightness)
  draw_path(points, width * 4, effect_color(scene, hue, brightness, 24), scene.target)
  draw_path(points, width * 2, effect_color(scene, hue, brightness, 70), scene.target)
  draw_path(points, width, effect_color(scene, hue, brightness), scene.target)
end

local function inject(field, w, h, x, y, radius, strength)
  local r2 = radius * radius
  for py = math.max(0, math.floor(y - radius)), math.min(h - 1, math.ceil(y + radius)) do
    for px = math.max(0, math.floor(x - radius)), math.min(w - 1, math.ceil(x + radius)) do
      local distance = ((px - x)^2 + (py - y)^2) / r2
      if distance < 1 then
        local index = py * w + px + 1
        field[index] = math.min(255, field[index] + strength * (1 - distance)^2)
      end
    end
  end
end

-- Bounded feedback surfaces reproduce the low-resolution, flowing XP-era look.
-- Field motion runs in Lua; scaling and presentation use the native canvas API.
local function feedback_image(scene, width, height)
  local signal, levels = scene.audio, scene.audio.levels
  local scale = math.min(1, 240 / width, 160 / height)
  local w, h = math.max(16, math.floor(width * scale)), math.max(16, math.floor(height * scale))
  if scene.field_w ~= w or scene.field_h ~= h or not scene.field then
    scene.field_w, scene.field_h = w, h
    scene.field, scene.previous = {}, {}
    for i = 1, w * h do scene.field[i], scene.previous[i] = 0, 0 end
    scene.canvas = Canvas.new(w, h, { 0, 0, 0, 255 })
    scene.rendered_frame = nil
  end
  local options = settings()
  local palette_key = tostring(options.effect_custom_color) .. table.concat(options.effect_color or {}, ",")
  if scene.rendered_frame == scene.frame and scene.image_w == width and scene.image_h == height
    and scene.palette_key == palette_key then
    return scene.image
  end
  local time, energy = scene.time, signal.energy
  local twist = scene.effect == "alchemy" and 0.025 or 0.006
  local angle = twist + math.sin(time * 0.45) * 0.015 + signal.beat * 0.008
  local zoom = scene.effect == "alchemy" and 0.982 or 0.955 - signal.bass * 0.012
  local cosine, sine = math.cos(angle) * zoom, math.sin(angle) * zoom
  local cx, cy = (w - 1) / 2, (h - 1) / 2
  local field, previous = scene.previous, scene.field
  local shifts = {}
  for px = 0, w - 1 do shifts[px] = math.sin(px / w * 7 + time * 0.7) * (0.2 + energy) end
  for py = 0, h - 1 do
    local dx, dy = -cx, py - cy
    local shift = math.sin(py / h * 6 - time * 0.6) * (0.2 + energy)
    local sx, sy = cx + dx * cosine - dy * sine + shift, cy + dx * sine + dy * cosine
    for px = 0, w - 1 do
      local ix, iy = math.floor(sx + 0.5), math.floor(sy + shifts[px] + 0.5)
      local value = ix >= 0 and ix < w and iy >= 0 and iy < h and previous[iy * w + ix + 1] or 0
      field[py * w + px + 1] = value * 0.965
      sx, sy = sx + cosine, sy + sine
    end
  end
  local radius = 1.3 + energy * 2.2 + signal.beat
  local strength = 35 + signal.middle * 85 + signal.beat * 90
  if scene.effect == "warp" then
    for ribbon = 1, 3 do
      for i = 1, 128 do
        local t = (i - 1) / 127
        local sample = signal.wave[(i - 1) * 2 + 1] or 0
        local x = cx + (t - 0.5) * w * (0.5 + ribbon * 0.06)
        local y = cy + math.sin(t * math.pi * (2 + ribbon) + time * 0.7 + ribbon) * h * 0.08
          + sample * h * 0.26 + math.cos(t * 8 - time) * signal.bass * h * 0.06
        inject(field, w, h, x, y, radius, strength)
      end
    end
  else
    for ribbon = 1, 3 do
      for i = 0, 159 do
        local a = i / 159 * math.pi * 2
        local band = levels[math.floor(i / 160 * #levels) + 1] or 0
        local r = (0.2 + math.sin(a * (3 + ribbon) + time * 0.8) * 0.08 + band * 0.06)
          * math.min(w, h)
        inject(field, w, h, cx + math.cos(a + time * 0.15 + ribbon) * r * 1.5,
          cy + math.sin(a * 2 - time * 0.11 + ribbon) * r, radius, strength * 0.7)
      end
    end
  end
  scene.field, scene.previous = field, previous
  local palette = {}
  local fade = math.min(1, 0.3 + scene.age * 1.5)
  for i = 0, 255 do
    palette[i] = effect_color(scene, 0.58 + i / 255 * 0.48,
      (i / 255)^0.7 * fade)
  end
  local rows, row = {}, {}
  for py = 0, h - 1 do
    for px = 0, w - 1 do
      local color = palette[math.floor(field[py * w + px + 1])]
      local offset = px * 4
      row[offset + 1], row[offset + 2], row[offset + 3], row[offset + 4] = color[1], color[2], color[3], 255
    end
    rows[py + 1] = string.char(table.unpack(row, 1, w * 4))
  end
  scene.canvas:set_pixels(table.concat(rows), 0, 0, w, h)
  scene.canvas:render()
  scene.image = scene.canvas:scaled(width, height, "linear")
  scene.image_w, scene.image_h, scene.rendered_frame = width, height, scene.frame
  scene.palette_key = palette_key
  return scene.image
end

local function draw_battery(scene, x, y, w, h)
  local signal, levels = scene.audio, scene.audio.levels
  local cx, cy, time = x + w / 2, y + h / 2, scene.time
  for trail = 2, 0, -1 do
    for ribbon = 1, 3 do
      local points = {}
      local phase = time * 0.6 - trail * 0.07 + ribbon * 2.1
      for i = 0, 128 do
        local a = i / 128 * math.pi * 2
        local band = levels[i % math.max(1, #levels) + 1] or 0
        local wave = signal.wave[math.floor(i / 128 * 255) + 1] or 0
        local radius = 0.3 + math.sin(a * 3 + phase) * 0.07 + band * 0.06
        points[i + 1] = {
          cx + math.cos(a + phase * 0.35) * w * radius,
          cy + math.sin(a * 2 - phase) * h * 0.24 + wave * h * 0.12
        }
      end
      local brightness = (0.45 + signal.energy * 0.55) * (1 - trail / 6)
      glow_path(scene, points, ribbon / 3 + trail * 0.03, math.max(1, h / 250), brightness)
    end
  end
end

local function draw_spikes(scene, x, y, w, h)
  local signal, levels = scene.audio, scene.audio.levels
  local cx, cy, radius = x + w / 2, y + h / 2, math.min(w, h) * 0.22
  local ring = {}
  for i = 0, 96 do
    local angle = i / 96 * math.pi * 2 + scene.time * 0.12
    local band = levels[i % math.max(1, #levels) + 1] or 0
    local inner = radius * (0.8 + signal.bass * 0.35)
    local outer = inner + radius * (0.15 + band * 0.85 + signal.beat * 0.25)
    local cosine, sine = math.cos(angle), math.sin(angle)
    ring[i + 1] = { cx + cosine * inner, cy + sine * inner }
    if i < 96 then
      glow_path(scene, { ring[i + 1], { cx + cosine * outer, cy + sine * outer } },
        i / 96, math.max(1, w / 650), 0.5 + band * 0.5)
    end
  end
  glow_path(scene, ring, 0.55, math.max(1, w / 500), 0.8)
end

local function draw_scope(scene, x, y, w, h)
  local signal = scene.audio
  for trail = 3, 0, -1 do
    local points = {}
    for i = 1, 256 do
      local sample = signal.wave[i] or 0
      points[i] = { x + w * (i - 1) / 255,
        y + h / 2 + sample * h * (0.32 - trail * 0.025) + math.sin(i / 25 + scene.time) * trail * h / 300 }
    end
    glow_path(scene, points, 0.32 + trail * 0.05, math.max(1, h / 250), 1 - trail / 7)
  end
end

local function draw_particles(scene, x, y, w, h)
  local signal = scene.audio
  local cx, cy = x + w / 2, y + h / 2
  local rotation = scene.time * 0.06
  for i = 1, 180 do
    local angle = i * 2.399963 + rotation
    local z = (i * 0.618034 - scene.time * (0.15 + signal.bass * 0.2)) % 1
    local spread = 0.08 + ((i * 73) % 97) / 97 * 0.4
    local radius = spread / (0.15 + z)
    local px, py = cx + math.cos(angle) * w * radius, cy + math.sin(angle) * h * radius
    local trail = 0.012 + signal.beat * 0.035 + signal.treble * 0.015
    local tail = spread / (0.15 + z + trail)
    glow_path(scene, { {cx + math.cos(angle) * w * tail, cy + math.sin(angle) * h * tail}, {px, py} },
      i / 180 + scene.time * 0.03, math.max(1, (1 - z) * 2 * SCALE), (1 - z) * 0.8 + 0.2)
  end
end

local function vector_image(scene, width, height, draw)
  local options = settings()
  local palette_key = tostring(options.effect_custom_color) .. table.concat(options.effect_color or {}, ",")
  if scene.image and scene.rendered_frame == scene.frame and scene.image_w == width
    and scene.image_h == height and scene.palette_key == palette_key then return scene.image end
  local scale = math.min(1, 560 / width, 320 / height)
  local w, h = math.max(1, math.floor(width * scale)), math.max(1, math.floor(height * scale))
  local cw, ch
  if scene.canvas then cw, ch = scene.canvas:get_size() end
  if cw ~= w or ch ~= h then scene.canvas = Canvas.new(w, h, {2, 4, 8, 255}) end
  scene.canvas:draw_rect(0, 0, w, h, {2, 4, 8, 255}, true)
  scene.target = scene.canvas
  draw(scene, 0, 0, w, h)
  scene.target = nil
  scene.canvas:render()
  scene.image = scene.canvas:scaled(width, height, "linear")
  scene.image_w, scene.image_h, scene.rendered_frame = width, height, scene.frame
  scene.palette_key = palette_key
  return scene.image
end

local function draw_scene(scene, x, y, w, h)
  local levels = scene.audio.levels
  if w < 1 or h < 1 then return end
  choose_effect(scene)
  renderer.draw_rect(x, y, w, h, { 2, 4, 8, 255 })
  core.push_clip_rect(x, y, w, h)
  if scene.effect == "warp" or scene.effect == "alchemy" then
    renderer.draw_canvas(feedback_image(scene, math.max(1, math.floor(w)), math.max(1, math.floor(h))), x, y)
  elseif scene.effect ~= "bars" then
    local draw = scene.effect == "battery" and draw_battery
      or scene.effect == "spikes" and draw_spikes
      or scene.effect == "scope" and draw_scope or draw_particles
    renderer.draw_canvas(vector_image(scene, math.max(1, math.floor(w)), math.max(1, math.floor(h)), draw), x, y)
  else
    local count = math.max(1, #levels)
    local gap = math.min(number("bar_spacing", 3, 0, 64) * SCALE, math.max(0, w / count - 1))
    for i = 1, #levels do
      local width = math.max(1, math.floor(w / count - gap))
      local height = math.floor(levels[i] * h * 0.8)
      local vertical = settings().vertical_position
      local top = vertical == "top" and y or vertical == "center" and y + (h - height) / 2 or y + h - height
      renderer.draw_rect(math.floor(x + (i - 1) * w / count), top, width, height,
        effect_color(scene, (i - 1) / count, 0.9))
    end
  end
  core.pop_clip_rect()
end

local visualizers = setmetatable({}, { __mode = "k" })
local current_view, fullscreen
local previous_focus = setmetatable({}, { __mode = "v" })
local VisualizerView = View:extend()
VisualizerView.context = "session"

function VisualizerView:new()
  VisualizerView.super.new(self)
  self.scene, self.paused = new_scene(), false
  self.scrollable = false
  visualizers[self] = true
end

function VisualizerView:get_name()
  local selected = self.scene.effect or settings().effect or "warp"
  for _, effect in ipairs(effects) do
    if effect[2] == selected then return "Audio Visualizer - " .. effect[1] end
  end
  return "Audio Visualizer"
end

function VisualizerView:draw(x, y, w, h)
  x, y, w, h = x or self.position.x, y or self.position.y, w or self.size.x, h or self.size.y
  if active then draw_scene(self.scene, x, y, w, h)
  else renderer.draw_rect(x, y, w, h, {2, 4, 8, 255}) end
end

function VisualizerView:try_close(do_close)
  if fullscreen and fullscreen.view == self then audiovisu.exit_fullscreen() end
  visualizers[self] = nil
  self.scene.image, self.scene.canvas, self.scene.field, self.scene.previous = nil, nil, nil, nil
  if current_view == self then
    current_view = nil
    if settings().presentation == "view" then settings().presentation = "overlay" end
  end
  do_close()
end

audiovisu.VisualizerView = VisualizerView

function audiovisu.exit_fullscreen()
  if not fullscreen then return end
  local state = fullscreen
  fullscreen = nil
  if state.root.draw == state.override then state.root.draw = state.draw end
  if state.restore_window and core.window and system.get_window_mode(core.window) == "fullscreen" then
    command.perform "core:toggle-fullscreen"
  end
  settings().presentation = "view"
  redraw()
end

function audiovisu.open()
  audiovisu.exit_fullscreen()
  audiovisu.start()
  settings().presentation = "view"
  local root = core.root_view
  if core.active_view and not core.active_view:extends(VisualizerView) then previous_focus.view = core.active_view end
  local node = current_view and root.root_node:get_node_for_view(current_view)
  if node then
    node:set_active_view(current_view)
  else
    current_view = VisualizerView()
    root:get_active_node_default():add_view(current_view)
    root.root_node:update_layout()
  end
  redraw()
  return current_view
end

function audiovisu.open_fullscreen(view)
  if fullscreen then return fullscreen.view end
  local matrix = package.loaded["plugins.matrix"]
  if type(matrix) == "table" and matrix.exit_fullscreen then matrix.exit_fullscreen() end
  view = view or audiovisu.open()
  if not core.window then return view end
  local root = core.root_view
  local state = {
    view = view, root = root, draw = rawget(root, "draw"),
    restore_window = system.get_window_mode(core.window) ~= "fullscreen"
  }
  state.override = function(self)
    for i = #self.deferred_draws, 1, -1 do self.deferred_draws[i] = nil end
    local w, h = core.window:get_size()
    view:draw(0, 0, w, h)
  end
  fullscreen = state
  if state.restore_window then command.perform "core:toggle-fullscreen" end
  settings().presentation = "fullscreen"
  root.draw = state.override
  redraw()
  return view
end

function audiovisu.toggle_fullscreen(view)
  if fullscreen then audiovisu.exit_fullscreen() else audiovisu.open_fullscreen(view) end
end

apply_presentation = function()
  if not active then return end
  local requested = settings().presentation or "overlay"
  if requested == "fullscreen" then
    if core.window then audiovisu.open_fullscreen() end
  elseif requested == "view" then
    audiovisu.open()
  else
    audiovisu.exit_fullscreen()
    settings().presentation = "overlay"
    local node = previous_focus.view and core.root_view.root_node:get_node_for_view(previous_focus.view)
    if node then node:set_active_view(previous_focus.view) end
  end
  redraw()
end

advance_visualizers = function(dt, moving)
  local changed = false
  for view in pairs(visualizers) do
    local node = core.root_view.root_node:get_node_for_view(view)
    local visible = fullscreen and fullscreen.view == view or node and node.active_view == view
    if visible then
      choose_effect(view.scene)
      if active and moving and not view.paused then
        local snapshot = view.scene.audio
        snapshot.bass, snapshot.middle, snapshot.treble = signal.bass, signal.middle, signal.treble
        snapshot.energy, snapshot.beat = signal.energy, signal.beat
        for i = 1, 256 do snapshot.wave[i] = signal.wave[i] end
        for i = 1, #levels do snapshot.levels[i] = levels[i] end
        for i = #snapshot.levels, #levels + 1, -1 do snapshot.levels[i] = nil end
        local delta = math.min(dt, 0.1)
        view.scene.time = view.scene.time + delta * number("effect_speed", 1, 0.1, 5)
        view.scene.age = view.scene.age + delta
        view.scene.frame = view.scene.frame + 1
        choose_effect(view.scene)
        changed = true
      end
    end
  end
  return changed
end

local function cycle_effect(direction)
  if settings().effect == "random" then
    for view in pairs(visualizers) do choose_effect(view.scene, true) end
  else
    local index = 1
    for i = 1, #effects - 1 do if effects[i][2] == settings().effect then index = i end end
    settings().effect = effects[(index - 1 + direction) % (#effects - 1) + 1][2]
  end
  redraw()
end

function audiovisu.start()
  settings().enabled = true
  sync_enabled()
end

function audiovisu.stop()
  settings().enabled = false
  sync_enabled()
end

function audiovisu.toggle()
  if active then audiovisu.stop() else audiovisu.start() end
end

command.add(nil, {
  ["audio-visualizer:start"] = audiovisu.start,
  ["audio-visualizer:stop"] = audiovisu.stop,
  ["audio-visualizer:toggle"] = audiovisu.toggle,
  ["audio-visualizer:open"] = audiovisu.open,
  ["audio-visualizer:open-fullscreen"] = function() return audiovisu.open_fullscreen() end
})

command.add(VisualizerView, {
  ["audio-visualizer:toggle-fullscreen"] = audiovisu.toggle_fullscreen,
  ["audio-visualizer:next-effect"] = function() cycle_effect(1) end,
  ["audio-visualizer:previous-effect"] = function() cycle_effect(-1) end,
  ["audio-visualizer:toggle-pause"] = function(view)
    view.paused = not view.paused
    redraw()
  end
})

keymap.add {
  ["space"] = "audio-visualizer:toggle-pause",
  ["f11"] = "audio-visualizer:toggle-fullscreen",
  ["right"] = "audio-visualizer:next-effect",
  ["left"] = "audio-visualizer:previous-effect"
}

if not supported then
  report("The native mixer audio API is unavailable.")
  return audiovisu
end

local on_event = core.on_event
local pointer_events = {
  mousemoved = true, mousepressed = true, mousereleased = true, mousewheel = true,
  touchpressed = true, touchreleased = true, touchmoved = true
}
core.on_event = function(event, ...)
  if fullscreen then
    if event == "keypressed" and select(1, ...) == "escape" then
      audiovisu.exit_fullscreen()
      return true
    elseif event == "focuslost" or event == "quit" or event == "filedropped" then
      audiovisu.exit_fullscreen()
    elseif pointer_events[event] or event == "textinput" then
      return true
    end
  end
  return on_event(event, ...)
end

local create_mixer = audio.create_mixer
audio.create_mixer = function(...)
  local result = table.pack(create_mixer(...))
  local mixer = result[1]
  if mixer then
    local info = mixer:get_info()
    if info and not info.offline then
      hook_mixer(mixer)
      local set_buffer = hooked[getmetatable(mixer)]
      if set_buffer then
        local state = { requested = 0, voices = {}, set_buffer = set_buffer }
        mixers[mixer] = state
        if active then capture(mixer, state, true) end
      end
    end
  end
  return table.unpack(result, 1, result.n)
end

local rootview_draw = RootView.draw
function RootView:draw(...)
  if active then self:defer_draw(render, self) end
  return rootview_draw(self, ...)
end

sync_enabled()
core.add_thread(function()
  if active and (settings().presentation or "overlay") ~= "overlay" then
    while not core.window do coroutine.yield(0.05) end
    apply_presentation()
  end
  while true do coroutine.yield(update()) end
end, audiovisu)

return audiovisu
