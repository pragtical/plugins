-- mod-version:3
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local ColorPickerDialog = require "widget.colorpickerdialog"

---Supported color formats
local color_patterns = {
  { pattern = "#%x%x%x%x%x%x%x%x", type = "html" },
  { pattern = "#%x%x%x%x%x%x", type = "html" },
  { pattern = "#%x%x%x", type = "html" },
  { pattern = "rgba?%(%s*(%d+)%D+(%d+)%D+(%d+)[%s,]-([%.%d]-)%s-%)", type = "rgb" },
  { pattern = "hsla?%(%s*(%d+)%D+(%d+)%%%D+(%d+)%%[%s,]-([%.%d]-)%s-%)", type = "hsl" }
}

---Get color information from given cursor position.
---@param doc core.doc
---@param line integer
---@param col integer
---@param text string
---@return string color
---@return "html" | "html_opacity" | "rgb" type
---@return table<integer,integer> selection
local function get_color_type(doc, line, col)
  local col1, col2 = 1, 1
  ---@type string
  local text = doc.lines[line]
  local ccol = 1
  repeat
    for _, pattern in ipairs(color_patterns) do
      col1, col2 = text:find(pattern.pattern, ccol)
      if col1 and col2 then
        if col >= col1 and col <= col2+1 then
          return
            doc:get_text(line, col1, line, col2+1),
            pattern.type,
            {line, col1, line, col2+1}
        else
          ccol = ccol + 1
          break
        end
      end
    end
  until not col1
  return "", "html", {line, col, line, col}
end

command.add("core.docview!", {
  ["color-picker:open"] = function(dv)
    ---@type core.doc
    local doc = dv.doc
    local color, type, selection = get_color_type(doc, doc:get_selection(true))
    doc:set_selection(table.unpack(selection))

    ---@type widget.colorpickerdialog
    local picker = ColorPickerDialog(nil, color)
    function picker:on_apply(c)
      local value
      local no_opacity = c[4] >= 255
      if type == "html" then
        if no_opacity then
          value = string.format("#%02X%02X%02X", c[1], c[2], c[3])
        else
          value = string.format("#%02X%02X%02X%02X", c[1], c[2], c[3], c[4])
        end
      elseif type == "rgb" then
        if no_opacity then
          value = string.format("rgb(%d, %d, %d)", c[1], c[2], c[3])
        else
          value = string.format("rgba(%d, %d, %d, %.2f)", c[1], c[2], c[3], c[4]/255)
        end
      elseif type == "hsl" then
        local c = self.picker.rgb_to_hsl(c)
        if no_opacity then
          value = string.format("hsl(%d, %d%%, %d%%)", c[1]*360, c[2]*100, c[3]*100)
        else
          value = string.format("hsla(%d, %d%%, %d%%, %.2f)", c[1]*360, c[2]*100, c[3]*100, c[4])
        end
      end
      doc:text_input(value)
    end
    local on_close = picker.on_close
    function picker:on_close()
      on_close(self)
      core.set_active_view(dv)
    end
    picker:show()
    picker:centered()
  end,
})

keymap.add {
  ["ctrl+alt+k"] = "color-picker:open"
}
