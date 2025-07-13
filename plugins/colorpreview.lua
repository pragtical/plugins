-- mod-version:3
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local DocView = require "core.docview"
local ColorPicker = require "widget.colorpicker"


config.plugins.colorpreview = common.merge({
  enabled = true,
  mode = "background",
  -- The config specification used by the settings gui
  config_spec = {
    name = "Color Preview",
    {
      label = "Enable",
      description = "Enable or disable the color preview feature.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Preview Mode",
      description = "The method used to preview the color.",
      path = "mode",
      type = "selection",
      default = "background",
      values = {
        { "Background", "background" },
        { "Underline", "underline" }
      },
    }
  }
}, config.plugins.colorpreview)

local white = { common.color "#ffffff" }
local black = { common.color "#000000" }
local tmp = {}

---Supported color formats
local color_patterns = {
  { pattern = "#(%x%x)(%x%x)(%x%x)(%x%x)%f[%W]", type = "html" },
  { pattern = "#(%x%x)(%x%x)(%x%x)%f[%W]", type = "html" },
  { pattern = "#(%x)(%x)(%x)%f[%W]", type = "html", nibble = true },
  { pattern = "rgba?%(%s*(%d+)%D+(%d+)%D+(%d+)[%s,]-([%.%d]-)%s-%)", type = "rgb" },
  { pattern = "hsla?%(%s*(%d+)%D+(%d+)%%%D+(%d+)%%[%s,]-([%.%d]-)%s-%)", type = "hsl" }
}

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

local function draw_color_previews(self, line, x, y)
  local vcol1, vcol2 = get_visible_cols_range(self, line, 50)
  if vcol1 == 0 or vcol2 == 1 then return end
  ---@type string
  local text = self.doc.lines[line]:sub(vcol1, vcol2)
  local text_len = #text
  local ccol, col1, col2 = 1, 0, 0
  local c1, c2, c3, c4
  repeat
    for _, pattern in ipairs(color_patterns) do
      _, col2 = text:find("^%s*", ccol) -- skip spaces for faster checking
      if col2 then ccol = col2 + 1 end

      col1, col2, c1, c2, c3, c4 = text:find("^"..pattern.pattern, ccol)
      if col1 and col2 then
        if pattern.nibble then
          c1 = c1 .. c1
          c2 = c2 .. c3
          c3 = c3 .. c3
        end

        local base = pattern.type == "html" and 16 or 10
        c1, c2, c3 = tonumber(c1, base), tonumber(c2, base), tonumber(c3, base)

        c4 = tonumber(c4 or "", base)
        if c4 ~= nil then
          if pattern.type == "rgb" then
            c4 = c4 * 0xff
          end
        elseif pattern.type ~= "hsl" then
          c4 = 0xff
        else
          c4 = 1
        end

        if pattern.type == "hsl" then
          local rgba = ColorPicker.hsl_to_rgb(c1 / 360, c2 / 100, c3 / 100, c4)
          c1, c2, c3, c4 = table.unpack(rgba)
        end

        local x1 = x + self:get_col_x_offset(line, vcol1 + col1 - 1)
        local x2 = x + self:get_col_x_offset(line, vcol1 + col2)
        local oy = self:get_line_text_y_offset()

        tmp[1], tmp[2], tmp[3], tmp[4] = c1, c2, c3, c4

        local l1, _, l2, _ = self.doc:get_selection(true)
        local mode = config.plugins.colorpreview.mode

        if mode == "underline" then
          local line_y = y + self:get_line_height()
          local line_h = math.ceil(4 * SCALE)
          renderer.draw_rect(x1, line_y - line_h, x2 - x1, line_h, tmp)
        elseif not (self.doc:has_selection() and line >= l1 and line <= l2) then
          local text_color = math.max(c1, c2, c3) < 128 and white or black
          renderer.draw_rect(x1, y, x2 - x1, self:get_line_height(), tmp)
          renderer.draw_text(self:get_font(), text:sub(col1, col2), x1, y + oy, text_color)
        end

        ccol = col2 + 1
        break
      end
    end
    ccol = ccol + 1
    if ccol < text_len then col1 = 0 end
  until not col1
end


local draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(line, x, y)
  local lh = draw_line_text(self, line, x, y)
  if config.plugins.colorpreview.enabled then
    draw_color_previews(self, line, x, y)
  end
  return lh
end

command.add(nil, {
  ["color-preview:toggle"] = function()
    config.plugins.colorpreview.enabled = not config.plugins.colorpreview.enabled
    core.log(
      "Color Preview: %s",
      config.plugins.colorpreview.enabled and "Enabled" or "Disabled"
    )
  end,

  ["color-preview:toggle-mode"] = function()
    if config.plugins.colorpreview.mode == "background" then
      config.plugins.colorpreview.mode = "underline"
    else
      config.plugins.colorpreview.mode = "background"
    end
    core.log(
      "Color Preview Mode: %s",
      config.plugins.colorpreview.mode == "underline"
        and "Underline" or "Background"
    )
  end
})
