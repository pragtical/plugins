-- mod-version:3
--
-- Originally developed by: Ferrari Martino Giordano <https://codeberg.org/Mandarancio/keyhud/>
-- Modified to account for mouse press and scroll events, also directly
-- included into pragtical plugins repository.
--
-- A font that provides additional glyphs like FiraCodeNerdFontMono-Regular.ttf
-- is recommended for the key symbols used on this plugin by default.
--
-- Part of Original README:
--
-- ## Configuration
--
-- The behaviour can be configured using the following settings:
--
--  - custom key mapping: table `config.plugins.keyhud.stroke_map`
--  - time after release: `config.plugins.keyhud.max_time`
--  - show only key mapped: `config.plugins.keyhud.only_mapped`
--  - stroke filters: `config.plugins.keyhud.filters`
--  - HUD position: `config.plugins.keyhud.position` (`left` or `right`, the default)
--
-- For the style of the HUD:
--
--  - background color: `style.keyhud.background` (default: `#00000066`)
--  - text color: `style.keyhud.text` (default: `#ffffffdd`)
--  - font: `style.keyhud.text` (default: `big_font`)
--
-- ## Example of configuration
--
-- ```lua
-- local config = require "core.config"
--
-- config.plugins.keyhud.max_time = 0.25
-- config.plugins.keyhud.stroke_map = {
--   ["left shift"] = "<SHFT", -- just for the example
--   ["righ shift"] = "SHIFT>",
--   ["left ctrl"] = "<CTRL",
--   ["right ctrl"] = "CTRL>",
-- }
-- ```
-- ### My Configuration
--
-- ```lua
-- local config = require "core.config"
-- local style = require "core.style"
--
-- config.plugins.keyhud.position = 'left'
-- config.plugins.keyhud.stroke_map["left gui"] = "⌘"
-- config.plugins.keyhud.stroke_map["right gui"] = "⌘"
-- config.plugins.keyhud.stroke_map["space"] = "␣"
-- config.plugins.keyhud.stroke_map["tab"] = "⇥"
-- config.plugins.keyhud.stroke_map["return"] = "⏎"
-- config.plugins.keyhud.stroke_map["pageup"] = "⇞"
-- config.plugins.keyhud.stroke_map["pagedown"] = "⇟"
-- config.plugins.keyhud.stroke_map["end"] = "↘"
-- config.plugins.keyhud.stroke_map["home"] = "↖"
--
-- style.keyhud.font = renderer.font.load("FiraCodeNerdFontMono-Regular.ttf", 24 * SCALE)
-- ```
--
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"
local CommandView = require "core.commandview"
local RootView = require "core.rootview"
local config = require "core.config"
local common = require "core.common"


local keyhud = {}

config.plugins.keyhud = common.merge({
  enabled = true,
  show_mouse_button = false,
  stroke_map = {
    ["escape"] = "<ESC>",
    ["space"] = "<SPACE>",  --"␣""
    ["left gui"] = "<CMD>", --"⌘"
    ["right gui"] = "<CMD>",
    ["left ctrl"] = "<CTRL>",
    ["right ctrl"] = "<CTRL>",
    ["left alt"] = "<ALT>",
    ["right alt"] = "<ALT>",
    ["left"] = "←",
    ["right"] = "→",
    ["up"] = "↑",
    ["down"] = "↓",
    ["left shift"] = "⇧",
    ["right shift"] = "⇧",
    ["capslock"] = "⇪",
    ["return"] = "<RETURN>", --"↵",
    ["backspace"] = "⌫",
    ["delete"] = "⌦",
    ["pageup"] = "<UP>",     --"⇞",
    ["pagedown"] = "<DOWN>", --"⇟",
    ["home"] = "<HOME>",     --"↖",
    ["end"] = "<END>",       --"↘",
    ["tab"] = "<TAB>",       --"⇥",
  },
  max_time = 0.5,
  only_mapped = false,
  filters = {
    ["commandview"] = true,
    ["mouse"] = true
  },
  position = "right",
  -- The config specification used by the settings gui
  config_spec = {
    name = "Key HUD",
    {
      label = "Enabled",
      description = "Display recently pressed keys by default.",
      path = "enabled",
      type = "toggle",
      default = true,
      on_apply = function(enabled)
        keyhud.set_enabled(enabled)
      end
    },
    {
      label = "Show Mouse Input",
      description = "Display mouse click counts and vertical scrolling after keyboard input.",
      path = "show_mouse_button",
      type = "toggle",
      default = false,
      on_apply = function(enabled)
        keyhud.set_show_mouse_button(enabled)
      end
    }
  }
}, config.plugins.keyhud)

style.keyhud = common.merge(
  {
    background = { common.color "#00000066" },
    text = { common.color "#ffffffdd" },
    font = style.big_font,  -- style.code_font:copy(46 * SCALE)
  },
  style.keyhud
)

keyhud.last_strokes = {}
keyhud.last_strokes_time_stamp = {}
keyhud.mouse_button = nil
keyhud.mouse_button_name = nil
keyhud.mouse_button_time_stamp = nil


keyhud.on_key_pressed__orig = keymap.on_key_pressed
keyhud.on_key_released__orig = keymap.on_key_released


local mouse_button_labels = {
  left = "LMB",
  middle = "MMB",
  right = "RMB",
  x1 = "X1",
  x2 = "X2"
}


local function clear_mouse_button()
  keyhud.mouse_button = nil
  keyhud.mouse_button_name = nil
  keyhud.mouse_button_time_stamp = nil
end


function keyhud.clear()
  keyhud.last_strokes = {}
  keyhud.last_strokes_time_stamp = {}
  clear_mouse_button()
  core.redraw = true
end


function keyhud.set_enabled(enabled)
  config.plugins.keyhud.enabled = enabled
  if not enabled then
    keyhud.clear()
  else
    core.redraw = true
  end
end


function keyhud.set_show_mouse_button(enabled)
  config.plugins.keyhud.show_mouse_button = enabled
  if not enabled then
    clear_mouse_button()
  end
  core.redraw = true
end


local function get_stroke(k)
  local stroke = config.plugins.keyhud.stroke_map[k]
  if stroke == nil and not config.plugins.keyhud.only_mapped then
    stroke = #k > 1 and "<" .. k .. ">" or k
  end
  return stroke
end


local function dv()
  return core.active_view
end

function keymap.on_key_pressed(k, ...)
  if not config.plugins.keyhud.enabled then
    return keyhud.on_key_pressed__orig(k, ...)
  end
  if dv():is(CommandView) and config.plugins.keyhud.filters.commandview then
    return keyhud.on_key_pressed__orig(k, ...)
  end
  local is_click = string.find(k, "click", 1, true)
  local is_wheel = string.find(k, "wheel", 1, true)
  if
    (config.plugins.keyhud.filters.mouse and (is_click or is_wheel))
    or (config.plugins.keyhud.show_mouse_button and (is_click or is_wheel))
  then
    return keyhud.on_key_pressed__orig(k, ...)
  end
  local x = get_stroke(k)
  if x ~= nil then
    for i, key in ipairs(keyhud.last_strokes) do
      if x == key then
        keyhud.last_strokes_time_stamp[i] = -1
        x = nil
        break
      end
    end
  end
  if x ~= nil then
    table.insert(keyhud.last_strokes, x)
    table.insert(keyhud.last_strokes_time_stamp, -1)
  end
  return keyhud.on_key_pressed__orig(k, ...)
end

function keymap.on_key_released(k)
  if config.plugins.keyhud.enabled and #keyhud.last_strokes then
    local x = get_stroke(k)
    for i, key in ipairs(keyhud.last_strokes) do
      if x == key then
        keyhud.last_strokes_time_stamp[i] = system.get_time()
        break
      end
    end
  end
  return keyhud.on_key_released__orig(k)
end


local root_view_on_mouse_pressed = RootView.on_mouse_pressed
function RootView:on_mouse_pressed(button, x, y, clicks, ...)
  local result = root_view_on_mouse_pressed(self, button, x, y, clicks, ...)
  if config.plugins.keyhud.enabled and config.plugins.keyhud.show_mouse_button then
    local click_count = clicks or 1
    click_count = ((click_count - 1) % config.max_clicks) + 1
    local label = mouse_button_labels[button] or string.upper(tostring(button))
    keyhud.mouse_button = string.format("<%d%s>", click_count, label)
    keyhud.mouse_button_name = button
    keyhud.mouse_button_time_stamp = -1
    core.redraw = true
  end
  return result
end


local root_view_on_mouse_released = RootView.on_mouse_released
function RootView:on_mouse_released(button, ...)
  local result = root_view_on_mouse_released(self, button, ...)
  if
    config.plugins.keyhud.enabled
    and config.plugins.keyhud.show_mouse_button
    and keyhud.mouse_button_name == button
  then
    keyhud.mouse_button_time_stamp = system.get_time()
    core.redraw = true
  end
  return result
end


local root_view_on_mouse_wheel = RootView.on_mouse_wheel
function RootView:on_mouse_wheel(delta_y, delta_x, ...)
  local result = root_view_on_mouse_wheel(self, delta_y, delta_x, ...)
  if
    config.plugins.keyhud.enabled
    and config.plugins.keyhud.show_mouse_button
    and delta_y ~= 0
  then
    keyhud.mouse_button = delta_y > 0 and "<SCROLL UP>" or "<SCROLL DOWN>"
    keyhud.mouse_button_name = nil
    keyhud.mouse_button_time_stamp = system.get_time()
    core.redraw = true
  end
  return result
end


local function draw_stroke(font, stroke, x, y, h, align_right)
  local tw = font:get_width(stroke)
  local th = font:get_height()
  local w = math.max(h, tw + 20)
  local box_x = align_right and x - w or x
  renderer.draw_rect(box_x, y - h, w, h, style.keyhud.background)
  renderer.draw_text(
    font, stroke, box_x + w / 2 - tw / 2, y - h / 2 - th / 2,
    style.keyhud.text
  )
  return align_right and box_x - 10 or box_x + w + 10
end


local root_view_draw = RootView.draw
function RootView:draw(...)
  local result = root_view_draw(self, ...)
  if not config.plugins.keyhud.enabled then
    if #keyhud.last_strokes > 0 or keyhud.mouse_button then
      keyhud.clear()
    end
    return result
  end
  local position = config.plugins.keyhud.position
  if position ~= "right" and position ~= "left" then
    core.error("`config.plugins.keyhud.position` can be only `left` or `right`")
    return result
  end

  local now = system.get_time()
  local strokes = {}
  local next_strokes = {}
  local next_timestamps = {}
  for i, stroke in ipairs(keyhud.last_strokes) do
    local timestamp = keyhud.last_strokes_time_stamp[i]
    if timestamp < 0 or now - timestamp < config.plugins.keyhud.max_time then
      table.insert(strokes, stroke)
      table.insert(next_strokes, stroke)
      table.insert(next_timestamps, timestamp)
    end
  end
  keyhud.last_strokes = next_strokes
  keyhud.last_strokes_time_stamp = next_timestamps

  if not config.plugins.keyhud.show_mouse_button then
    clear_mouse_button()
  elseif keyhud.mouse_button then
    local timestamp = keyhud.mouse_button_time_stamp
    if timestamp < 0 or now - timestamp < config.plugins.keyhud.max_time then
      table.insert(strokes, keyhud.mouse_button)
    else
      clear_mouse_button()
    end
  end

  if #strokes == 0 then
    return result
  end

  core.redraw = true
  local font = style.keyhud.font
  local h = font:get_height() + 20
  local y = self.size.y - 10
  if position == "left" then
    local x = 10
    for _, stroke in ipairs(strokes) do
      x = draw_stroke(font, stroke, x, y, h, false)
    end
  else
    local x = self.size.x - 10
    for i = #strokes, 1, -1 do
      x = draw_stroke(font, strokes[i], x, y, h, true)
    end
  end
  return result
end


command.add(nil, {
  ["keyhud:toggle"] = function()
    keyhud.set_enabled(not config.plugins.keyhud.enabled)
    core.log(
      "Key HUD: %s",
      config.plugins.keyhud.enabled and "Enabled" or "Disabled"
    )
  end
})


return keyhud
