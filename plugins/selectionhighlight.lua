-- mod-version:3
local common = require "core.common"
local style = require "core.style"
local DocView = require "core.docview"

-- originally written by luveti

local get_visible_cols_range = DocView.get_visible_cols_range
if not get_visible_cols_range then
  ---Get an estimated range of visible columns. It is an estimate because fonts
  ---and their fallbacks may not be monospaced or may differ in size.
  ---@param self core.docview
  ---@param line integer
  ---@param extra_cols integer Amount of columns to deduce on col1 and include on col2
  ---@return integer col1
  ---@return integer col2
  get_visible_cols_range = function(self, line, extra_cols)
    extra_cols = extra_cols or 100
    local gw = self:get_gutter_width()
    local line_x = self.position.x + gw
    local x = -self.scroll.x + self.position.x + gw

    local non_visible_x = common.clamp(line_x - x, 0, math.huge)
    local char_width = self:get_font():get_width("W")
    local non_visible_chars_left = math.floor(non_visible_x / char_width)
    local visible_chars_right = math.floor((self.size.x - gw) / char_width)
    local line_len = #self.doc.lines[line]

    if non_visible_chars_left > line_len then return 0, 0 end

    return
      math.max(1, non_visible_chars_left - extra_cols),
      math.min(line_len, non_visible_chars_left + visible_chars_right + extra_cols)
  end
end

local function draw_box(x, y, w, h, color)
  local r = renderer.draw_rect
  local s = math.ceil(SCALE)
  r(x, y, w, s, color)
  r(x, y + h - s, w, s, color)
  r(x, y + s, s, h - s * 2, color)
  r(x + w - s, y + s, s, h - s * 2, color)
end


local draw_line_body = DocView.draw_line_body

function DocView:draw_line_body(line, x, y)
  local line_height = draw_line_body(self, line, x, y)
  local line1, col1, line2, col2 = self.doc:get_selection(true)
  if line1 == line2 and col1 ~= col2 then
    local selection = self.doc:get_text(line1, col1, line2, col2)
    if not selection:match("^%s+$") then
      local lh = self:get_line_height()
      local selected_text = self.doc.lines[line1]:sub(col1, col2 - 1)
      local vcol1, vcol2 = get_visible_cols_range(self, line, 300)
      local current_line_text = self.doc.lines[line]:sub(vcol1, vcol2)
      local last_col = 1
      if vcol1 == 0 or vcol2 == 1 then goto return_value end
      while true do
        local start_col, end_col = current_line_text:find(
          selected_text, last_col, true
        )
        if start_col == nil then break end
        -- don't draw box around the selection
        if line ~= line1 or start_col ~= col1 then
          local x1 = x + self:get_col_x_offset(line, vcol1 + start_col - 1)
          local x2 = x + self:get_col_x_offset(line, vcol1 + end_col)
          local color = style.selectionhighlight or style.syntax.comment
          draw_box(x1, y, x2 - x1, lh, color)
        end
        last_col = end_col + 1
      end
    end
  end
  ::return_value::
  return line_height
end
