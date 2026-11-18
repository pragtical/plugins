-- mod-version:3.11
-- Freeze first row, just like Excel

local core = require("core")
local DocView = require("core.docview")
local style = require("core.style")
local command = require("core.command")

local FreezeRow = {
  enabled = false,
}

local function redraw()
  core.redraw = true
end

local old_draw_overlay = DocView.draw_overlay

function DocView:draw_overlay(...)
  local result = old_draw_overlay(self, ...)
  if not FreezeRow.enabled or not self.doc or #self.doc.lines == 0 then
    return result
  end
  local line_height = self:get_line_height()
  local view_x, view_y = self.position.x, self.position.y
  local view_w, view_h = self.size.x, self.size.y
  local old_clip_rect = core.clip_rect_stack[#core.clip_rect_stack]
  renderer.set_clip_rect(view_x, view_y, view_w, view_h)

  -- Redraw the first row at the top of the view.
  renderer.draw_rect(view_x, view_y, view_w, line_height, style.background)
  renderer.set_clip_rect(view_x, view_y, view_w, line_height)
  local gutter_width, gutter_padding = self:get_gutter_width()
  self:draw_line_gutter(1, view_x, view_y, gutter_padding and gutter_width - gutter_padding or gutter_width)
  self:draw_line_text(1, self:get_line_screen_position(1), view_y)
  renderer.set_clip_rect(view_x, view_y, view_w, view_h)
  renderer.draw_rect(view_x, view_y + line_height, view_w, style.divider_size, style.divider)
  -- Restore clipping
  renderer.set_clip_rect(table.unpack(old_clip_rect))
  return result
end

-- Command Palette
command.add(function()
  return true
end, {
  ["freeze-row:toggle"] = function()
    FreezeRow.enabled = not FreezeRow.enabled
    redraw()
  end,
})

return FreezeRow
