-- mod-version:3
-- Matrix digital rain, adapted from the Pragtical promotional demo.
-- @license MIT
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"
local renderer = require "renderer"
local configure_screensaver

---@class config.plugins.matrix
---@field screensaver boolean Start exclusive fullscreen rain after inactivity
---@field idle_minutes number Idle timeout in minutes, with a minimum of one
---@field color renderer.color Base color used to generate the rain palette
---@field font_size number Character size before UI scaling
---@field speed number Animation speed multiplier
config.plugins.matrix = common.merge({
  screensaver = true,
  idle_minutes = 1,
  color = { 9, 230, 55, 255 },
  font_size = 18,
  speed = 1,
  config_spec = {
    name = "Matrix",
    {
      label = "Screensaver", path = "screensaver", type = "toggle",
      default = true,
      description = "Show fullscreen Matrix after keyboard and mouse inactivity.",
      on_apply = function(enabled) configure_screensaver(enabled) end
    },
    {
      label = "Idle Minutes", path = "idle_minutes", type = "number",
      default = 1, min = 1, step = 1,
      description = "Minutes of inactivity before starting the screensaver (minimum: 1)."
    },
    {
      label = "Rain Color", path = "color", type = "color",
      default = { 9, 230, 55, 255 },
      description = "Base color for the trails and their bright leading characters."
    },
    {
      label = "Font Size", path = "font_size", type = "number",
      default = 18, min = 8, max = 48,
      description = "Character size before applying the editor's UI scale."
    },
    {
      label = "Speed", path = "speed", type = "number",
      default = 1, min = 0.1, max = 5, step = 0.1,
      description = "Multiplier for the falling characters' speed."
    }
  }
}, config.plugins.matrix)

local alphabet = {}
for character in ("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ$:+-*/<>{}[]"):gmatch(".") do
  alphabet[#alphabet + 1] = character
end

local background = { 3, 10, 8 }
local head_color = {}
local tail_colors = {}
local palette_color = {}

---Regenerate shared trail colors only when RGBA components actually change.
local function update_palette()
  local color = config.plugins.matrix.color
  local alpha = color[4] or 255
  if palette_color[1] == color[1] and palette_color[2] == color[2]
    and palette_color[3] == color[3] and palette_color[4] == alpha
  then return end
  for channel = 1, 3 do
    palette_color[channel] = color[channel]
    head_color[channel] = math.floor(204 + color[channel] * 0.2)
  end
  palette_color[4], head_color[4] = alpha, alpha
  for length = 14, 31 do
    local colors = {}
    for index = 1, length do
      local brightness = (1 - index / (length + 1)) ^ 1.4
      colors[index] = {
        math.floor(color[1] * brightness), math.floor(color[2] * brightness),
        math.floor(color[3] * brightness), alpha
      }
    end
    tail_colors[length] = colors
  end
  core.redraw = true
end

---@class plugins.matrix
local matrix = {}

---@type {view:plugins.matrix.view, automatic:boolean?, root:core.rootview, draw:function?, restore_window:boolean}?
local fullscreen
local last_activity = system.get_time()

---Animated digital rain displayed in a tab or over the entire editor.
---@class plugins.matrix.view : core.view
---@overload fun():plugins.matrix.view
---@field elapsed number Active animation time in seconds
---@field last_update number Monotonic timestamp of the previous update
---@field paused boolean Whether the animation is paused
---@field font renderer.font Scaled copy of the editor's code font
---@field font_source renderer.font Code font used to create the current copy
---@field font_size number Current font size in pixels
---@field column_width number Horizontal distance between character streams
---@field row_height number Vertical distance between characters
---@field columns table[] Cached stream properties for the visible width
local MatrixView = View:extend()
MatrixView.context = "session"

---Initialize independent animation state without changing the shared random seed.
function MatrixView:new()
  MatrixView.super.new(self)
  self.elapsed = 0
  self.last_update = system.get_time()
  self.paused = false
  self.columns = {}
  self:update_font()
  update_palette()
end

---Name shown in the tab strip and window title.
---@return string
function MatrixView:get_name()
  return "Matrix"
end

---Refresh font metrics when the configured size, UI scale, or code font changes.
function MatrixView:update_font()
  local size = config.plugins.matrix.font_size * SCALE
  if self.font_source ~= style.code_font or self.font_size ~= size then
    self.font = style.code_font:copy(size)
    self.font_source, self.font_size = style.code_font, size
    self.column_width = math.ceil(self.font:get_width("M") * 1.15)
    self.row_height = math.ceil(self.font:get_height())
  end
end

---Advance only while visible and focused; do not replay time spent in another tab.
function MatrixView:update()
  MatrixView.super.update(self)
  self:update_font()
  update_palette()
  local now = system.get_time()
  local delta = math.min(now - self.last_update, 0.1)
  self.last_update = now
  if self.paused or not system.window_has_focus(core.window) then return end
  self.elapsed = self.elapsed + delta * config.plugins.matrix.speed
  core.redraw = true
end

---Restore normal drawing before a fullscreen tab is closed or its session ends.
---@param do_close function Continuation supplied by the editor
function MatrixView:try_close(do_close)
  if fullscreen and fullscreen.view == self then matrix.exit_fullscreen() end
  do_close()
end

---Draw rain in the tab bounds, or in explicit fullscreen bounds without changing layout.
---@param x? number Left edge in pixels
---@param y? number Top edge in pixels
---@param w? number Width in pixels
---@param h? number Height in pixels
function MatrixView:draw(x, y, w, h)
  x, y = x or self.position.x, y or self.position.y
  w, h = w or self.size.x, h or self.size.y
  renderer.draw_rect(x, y, w, h, background)
  core.push_clip_rect(x, y, w, h)
  local time, row_height = self.elapsed, self.row_height
  local tick = math.floor(time * 5)
  for i = 1, math.ceil(w / self.column_width) do
    local column = self.columns[i]
    if not column then
      column = {
        speed = 95 + (i * 43 % 200), offset = (i * 149) % 1100,
        tail = 14 + (i * 7 % 18)
      }
      self.columns[i] = column
    end
    local cx = x + (i - 1) * self.column_width
    local head = (time * column.speed * SCALE + column.offset * SCALE)
      % (h + column.tail * row_height)
    local colors = tail_colors[column.tail]
    for j = 0, column.tail do
      local py = y + head - j * row_height
      if py > y - row_height and py < y + h then
        local index = (i * 19 + j * 13 + tick) % #alphabet + 1
        renderer.draw_text(self.font, alphabet[index], cx, py,
          j == 0 and head_color or colors[j])
      end
    end
  end
  if self.paused then
    local text = "Paused · Space to resume"
    local padding = style.padding.x
    local height = style.font:get_height() + style.padding.y * 2
    renderer.draw_rect(x, y + h - height, w, height, background)
    renderer.draw_text(style.font, text, x + padding, y + h - height + style.padding.y,
      head_color)
  end
  core.pop_clip_rect()
end

matrix.MatrixView = MatrixView

---Open a new, independent Matrix tab in the active document pane.
---@return plugins.matrix.view
function matrix.open()
  local view = MatrixView()
  core.root_view:get_active_node_default():add_view(view)
  return view
end

---Restore editor drawing and the window mode used before entering fullscreen.
function matrix.exit_fullscreen()
  if not fullscreen then return end
  local state = fullscreen
  fullscreen = nil
  last_activity = system.get_time()
  state.root.draw = state.draw
  if state.restore_window and system.get_window_mode(core.window) == "fullscreen" then
    command.perform("core:toggle-fullscreen")
  end
  state.view.last_update = system.get_time()
  core.redraw = true
end

local activity_events = {
  keypressed = true, keyreleased = true, mouseleft = true,
  textinput = true, textediting = true, mousemoved = true, mousepressed = true,
  mousereleased = true, mousewheel = true, touchpressed = true,
  touchreleased = true, touchmoved = true
}

---Enter native fullscreen and replace RootView drawing with rain.
---@param view plugins.matrix.view Rain to draw
---@param automatic? boolean Dismiss on mouse activity as well as keyboard input
local function enter_fullscreen(view, automatic)
  local root = core.root_view
  fullscreen = {
    view = view, automatic = automatic, root = root, draw = rawget(root, "draw"),
    restore_window = system.get_window_mode(core.window) ~= "fullscreen"
  }
  if fullscreen.restore_window then command.perform("core:toggle-fullscreen") end
  root.draw = function(self)
    -- Discard deferred UI draws instead of queuing them while the editor is hidden.
    for i = #self.deferred_draws, 1, -1 do self.deferred_draws[i] = nil end
    if automatic then view:update() end
    local width, height = core.window:get_size()
    view:draw(0, 0, width, height)
  end
  core.redraw = true
end

---Toggle exclusive drawing of the current tab; any key restores normal drawing.
---@param view plugins.matrix.view Currently shown Matrix tab
function matrix.toggle_fullscreen(view)
  if fullscreen then matrix.exit_fullscreen(); return end
  enter_fullscreen(view)
end

---Open a new Matrix tab and immediately enter its exclusive fullscreen mode.
---@return plugins.matrix.view
function matrix.open_fullscreen()
  if fullscreen then return fullscreen.view end
  local view = matrix.open()
  matrix.toggle_fullscreen(view)
  return view
end

command.add(nil, {
  ["matrix:open"] = matrix.open,
  ["matrix:open-fullscreen"] = matrix.open_fullscreen
})

command.add(MatrixView, {
  ["matrix:toggle-fullscreen"] = matrix.toggle_fullscreen,
  ["matrix:toggle-pause"] = function(view)
    view.paused = not view.paused
    view.last_update = system.get_time()
    core.redraw = true
  end
})

keymap.add {
  ["space"] = "matrix:toggle-pause",
  ["f11"] = "matrix:toggle-fullscreen"
}

-- Track only user input; repaint, resize and search/network events do not reset idle time.
local on_event = core.on_event
local discard_text_input = false
core.on_event = function(event, ...)
  if event == "keypressed" or event == "mousepressed" then discard_text_input = false end
  if event == "textinput" and discard_text_input then
    discard_text_input = false
    return true
  end
  if config.plugins.matrix.screensaver and command.map["matrix:open"].perform == matrix.open
    and (activity_events[event] or event == "focuslost")
  then
    last_activity = system.get_time()
  end
  if fullscreen then
    if event == "keypressed" or fullscreen.automatic and activity_events[event] then
      matrix.exit_fullscreen()
      discard_text_input = event == "keypressed"
      if event ~= "keyreleased" then return true end
    elseif activity_events[event] and event ~= "keyreleased" then
      return true
    elseif event == "quit" or event == "filedropped" or event == "focuslost" then
      matrix.exit_fullscreen()
    end
  end
  return on_event(event, ...)
end

---Remove the idle coroutine when disabled, or create exactly one when enabled.
---@param enabled boolean Whether automatic screensaver mode is requested
configure_screensaver = function(enabled)
  if not enabled then
    core.threads[matrix] = nil
    if fullscreen and fullscreen.automatic then matrix.exit_fullscreen() end
    return
  end
  if core.threads[matrix] then return end
  last_activity = system.get_time()
  -- A sleeping coroutine requests no redraws and performs no work between checks.
  core.add_thread(function()
    local had_focus = system.window_has_focus(core.window)
    while config.plugins.matrix.screensaver
      and command.map["matrix:open"].perform == matrix.open
    do
      local now = system.get_time()
      local focused = system.window_has_focus(core.window)
      if not focused or not had_focus then last_activity = now end
      had_focus = focused
      if fullscreen then
        if fullscreen.automatic and not focused then matrix.exit_fullscreen() end
      elseif focused
        and now - last_activity >= math.max(1, config.plugins.matrix.idle_minutes) * 60
      then
        -- Keep the current view and its focus; no automatic tab is added.
        enter_fullscreen(MatrixView(), true)
      end
      coroutine.yield(3)
    end
    -- Also handle disabling through a direct Lua config assignment.
    if fullscreen and fullscreen.automatic then matrix.exit_fullscreen() end
  end, matrix)
end

configure_screensaver(config.plugins.matrix.screensaver)

return matrix
