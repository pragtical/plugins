-- mod-version:3.1
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

local caret_idx = 1

local docview_update = DocView.update
function DocView:update()
  docview_update(self)

  if not config.plugins.smoothcaret.enabled or self ~= core.active_view then
    return
  end

  local redraw_caret = false
  local minline, maxline = self:get_visible_line_range()

  -- We need to keep track of all the carets
  if not self.carets then
    self.carets = { }
  end
  -- and we need the list of visible ones that `DocView:draw_caret` will use in succession
  self.visible_carets = { }

  local idx, v_idx = 1, 1
  for _, line, col in self.doc:get_selections() do
    local x, y = self:get_line_screen_position(line, col)
    -- Keep the position relative to the whole View
    -- This way scrolling won't animate the caret
    x = x + self.scroll.x
    y = y + self.scroll.y

    local c = self.carets[idx]

    if not c then
      self.carets[idx] = {
        line = line, col = col,
        current = { x = x, y = y },
        target = { x = x, y = y }
      }
      c = self.carets[idx]
    elseif c.line ~= line or c.col ~= col then
      c.line, c.col = line, col
      c.complete = false
    end

    c.target.x = x
    c.target.y = y

    -- Check if the number of carets changed or caret animation is complete
    if self.last_n_selections ~= #self.doc.selections or c.complete then
      -- Don't animate when there are new carets or animation is complete
      c.current.x = x
      c.current.y = y
    else
      self:move_towards(c.current, "x", c.target.x, config.plugins.smoothcaret.rate)
      self:move_towards(c.current, "y", c.target.y, config.plugins.smoothcaret.rate)
      if c.current.x ~= c.target.x or c.current.y ~= c.target.y then
        if not c.complete then redraw_caret = true end
      else
        c.complete = true
      end
    end

    -- Keep track of visible carets
    if line >= minline and line <= maxline then
      self.visible_carets[v_idx] = self.carets[idx]
      v_idx = v_idx + 1
    end
    idx = idx + 1
  end
  self.last_n_selections = #self.doc.selections

  -- Remove unused carets to avoid animating new ones when they are added
  for i = idx, #self.carets do
    self.carets[i] = nil
  end

  if redraw_caret then
    core.blink_start = core.blink_timer
    core.redraw = true
  end

  -- This is used by `DocView:draw_caret` to keep track of the current caret
  caret_idx = 1
end

local docview_draw_caret = DocView.draw_caret
function DocView:draw_caret(x, y, line, col)
  if not config.plugins.smoothcaret.enabled or self ~= core.active_view then
    docview_draw_caret(self, x, y, line, col)
    return
  end

  local c = self.visible_carets[caret_idx] or { current = { x = x, y = y } }
  docview_draw_caret(
    self, c.current.x - self.scroll.x, c.current.y - self.scroll.y, line, col
  )

  caret_idx = caret_idx + 1
end
