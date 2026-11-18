-- mod-version:3.11
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local DocView = require "core.docview"

config.plugins.smoothcaret = common.merge({
  enabled = true,
  rate = 0.30,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Smooth Caret",
    {
      label = "Enabled",
      description = "Disable or enable the smooth caret animation.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Rate",
      description = "Speed of the animation.",
      path = "rate",
      type = "number",
      default = 0.30,
      min = 0.1,
      max = 1.0,
      step = 0.05
    },
  }
}, config.plugins.smoothcaret)

local docview_update = DocView.update
function DocView:update()
  docview_update(self)

  if not config.plugins.smoothcaret.enabled or self ~= core.active_view
  or not system.window_has_focus(core.window) then
    self.smoothcaret_state = nil
    return
  end

  local state = self.smoothcaret_state
  if not state then
    -- Selection slots retain history; positions resolve carets regardless of draw order.
    state = { carets = {}, lookup = {}, generation = 0 }
    self.smoothcaret_state = state
  end
  local font = self:get_font()
  local size, height, gutter = font:get_size(), self:get_line_height(), self:get_gutter_width()
  local reset = state.doc ~= self.doc or state.count ~= #self.doc.selections
    or state.scroll_x ~= self.scroll.x or state.scroll_y ~= self.scroll.y
    or state.x ~= self.position.x or state.y ~= self.position.y
    or state.width ~= self.size.x or state.height ~= self.size.y
    or state.font ~= font or state.font_size ~= size
    or state.line_height ~= height or state.gutter ~= gutter
  local changed = state.change_id ~= self.doc:get_change_id()
  state.doc, state.count, state.change_id = self.doc, #self.doc.selections, self.doc:get_change_id()
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
  local redraw = false
  local selections = self.doc.selections
  for idx = 1, #selections, 4 do
    local line, col = selections[idx], selections[idx + 1]
    -- Reject off-screen and folded heads before measuring any text.
    if first and last and line >= first and line <= last and self:is_line_visible(line) then
      local row = self:offset_from_position(line, col)
      if row >= minrow and row <= maxrow then
        local c = state.carets[idx]
        local moved = c and (c.line ~= line or c.col ~= col)
        if not c then
          c = {}
          state.carets[idx] = c
        end
        -- Row changes also cover folds and wrapping without a text edit.
        if reset or changed or moved or c.row ~= row or not c.target_x then
          local x, y = self:get_line_screen_position(line, col)
          c.target_x, c.target_y = x + self.scroll.x, y + self.scroll.y
        end
        if reset or not c.x or not moved and (changed or c.row ~= row) then
          c.x, c.y = c.target_x, c.target_y
          c.move_data_x, c.move_data_y = nil, nil
        elseif c.x ~= c.target_x or c.y ~= c.target_y then
          self:move_towards(c, "x", c.target_x, config.plugins.smoothcaret.rate)
          self:move_towards(c, "y", c.target_y, config.plugins.smoothcaret.rate)
        end
        redraw = redraw or c.x ~= c.target_x or c.y ~= c.target_y
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
  if redraw then
    core.blink_start = core.blink_timer
    core.redraw = true
  end
end

local docview_draw_caret = DocView.draw_caret
function DocView:draw_caret(x, y, line, col)
  local state = self.smoothcaret_state
  if config.plugins.smoothcaret.enabled and self == core.active_view and state then
    local columns = state.lookup[line]
    local c = columns and columns[col]
    if c then x, y = c.x - self.scroll.x, c.y - self.scroll.y end
  end
  return docview_draw_caret(self, x, y, line, col)
end
