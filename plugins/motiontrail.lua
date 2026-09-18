-- mod-version:3.11
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local style = require "core.style"
local DocView = require "core.docview"

config.plugins.motiontrail = common.merge({
  enabled = true,
  steps = 50,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Motion Trail",
    {
      label = "Enabled",
      description = "Disable or enable the caret motion trail effect.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Steps",
      description = "Amount of trail steps to generate on caret movement.",
      path = "steps",
      type = "number",
      default = 50,
      min = 10,
      max = 100
    },
  }
}, config.plugins.motiontrail)

local function get_caret_size(dv, line, col, custom)
  local w = style.caret_width
  local h = dv:get_line_height()
  local shape = custom and custom.shape
  local underline = dv.doc.overwrite or shape == "underline"
  if underline or shape == "block" then
    w = dv:get_font():get_width(dv.doc:get_char(line, col))
    if custom and not dv.doc.overwrite then w = math.ceil(w) end
  end
  return w, underline and style.caret_width * 2 or h, underline and h or 0
end

local dv_update = DocView.update
function DocView:update()
  dv_update(self)
  if not config.plugins.motiontrail.enabled or self ~= core.active_view
  or not system.window_has_focus(core.window) then
    self.motiontrail_state = nil
    return
  end

  local state = self.motiontrail_state
  if not state then
    -- Selection slots retain history; positions resolve carets regardless of draw order.
    state = { carets = {}, lookup = {}, generation = 0 }
    self.motiontrail_state = state
  end
  local font = self:get_font()
  local size, height, gutter = font:get_size(), self:get_line_height(), self:get_gutter_width()
  local reset = state.doc ~= self.doc or state.count ~= #self.doc.selections
    or state.scroll_x ~= self.scroll.x or state.scroll_y ~= self.scroll.y
    or state.x ~= self.position.x or state.y ~= self.position.y
    or state.width ~= self.size.x or state.height ~= self.size.y
    or state.font ~= font or state.font_size ~= size
    or state.line_height ~= height or state.gutter ~= gutter
  state.doc, state.count = self.doc, #self.doc.selections
  state.scroll_x, state.scroll_y = self.scroll.x, self.scroll.y
  state.x, state.y = self.position.x, self.position.y
  state.width, state.height = self.size.x, self.size.y
  state.font, state.font_size, state.line_height, state.gutter = font, size, height, gutter
  state.generation = state.generation + 1
  for _, c in pairs(state.carets) do
    state.lookup[c.line][c.col] = nil
  end

  local minrow, maxrow = self:get_visible_line_range()
  local first, last = self:position_from_offset(minrow), self:position_from_offset(maxrow)
  local selections = self.doc.selections
  for idx = 1, #selections, 4 do
    local line, col = selections[idx], selections[idx + 1]
    if first and last and line >= first and line <= last and self:is_line_visible(line) then
      local row = self:offset_from_position(line, col)
      if row >= minrow and row <= maxrow then
        local c = state.carets[idx]
        if not c then c = {}; state.carets[idx] = c end
        local moved = c.line ~= line or c.col ~= col
        if reset or not moved and c.row ~= row then
          c.x, c.y, c.moving = nil, nil, false
        elseif moved then
          c.moving = true
        end
        c.line, c.col, c.row, c.generation = line, col, row, state.generation
        local columns = state.lookup[line]
        if not columns then columns = {}; state.lookup[line] = columns end
        columns[col] = c
      end
    end
  end
  for idx, c in pairs(state.carets) do
    if c.generation ~= state.generation then state.carets[idx] = nil end
  end
  for line, columns in pairs(state.lookup) do
    if not next(columns) then state.lookup[line] = nil end
  end
end

-- Match renderer.draw_rect's pixel quantization before combining opaque
-- rectangles. Keep translucent samples separate to preserve their blending.
local function grid(value)
  return (math.modf(value + 0.5))
end

local function draw_pixels(x1, y1, x2, y2, color)
  if x1 < 0 then x1 = x1 - 0.5 end
  if y1 < 0 then y1 = y1 - 0.5 end
  if x2 < 0 then x2 = x2 - 0.5 end
  if y2 < 0 then y2 = y2 - 0.5 end
  renderer.draw_rect(x1, y1, x2 - x1, y2 - y1, color)
end

local function draw_trail(x, y, previous_x, previous_y, w, h, color)
  local opaque = (color[4] or 255) == 255
  local left, top, right, bottom
  local last_x = x
  for i = 0, 1, 1 / config.plugins.motiontrail.steps do
    local ix, iy = common.lerp(x, previous_x, i), common.lerp(y, previous_y, i)
    local iw = math.max(w, math.ceil(math.abs(ix - last_x)))
    if not opaque then
      renderer.draw_rect(ix, iy, iw, h, color)
    else
      local x1, y1, x2, y2 = grid(ix), grid(iy), grid(ix + iw), grid(iy + h)
      if left and (
        top == y1 and bottom == y2 and x1 <= right and x2 >= left
        or left == x1 and right == x2 and y1 <= bottom and y2 >= top
      ) then
        left, top = math.min(left, x1), math.min(top, y1)
        right, bottom = math.max(right, x2), math.max(bottom, y2)
      else
        if left then draw_pixels(left, top, right, bottom, color) end
        left, top, right, bottom = x1, y1, x2, y2
      end
    end
    last_x = ix
  end
  if left then draw_pixels(left, top, right, bottom, color) end
end

local dv_draw_caret = DocView.draw_caret
function DocView:draw_caret(x, y, line, col)
  local state = self.motiontrail_state
  if config.plugins.motiontrail.enabled and self == core.active_view and state then
    local columns = state.lookup[line]
    local c = columns and columns[col]
    if c then
      if c.x and c.moving and (c.x ~= x or c.y ~= y) then
        local custom = package.loaded["plugins.custom_caret"] and config.plugins.custom_caret
        local w, h, offset = get_caret_size(self, line, col, custom)
        local color = custom and custom.custom_color and custom.caret_color or style.caret
        draw_trail(x, y + offset, c.x, c.y + offset, w, h, color)
        core.redraw = true
      elseif c.x == x and c.y == y then
        c.moving = false
      end
      c.x, c.y = x, y
    end
  end
  return dv_draw_caret(self, x, y, line, col)
end
