-- mod-version:3
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"

---@class config.plugins.guttercolor
---@field enabled boolean
---@field gutter_background boolean
---@field gutter_custom_color boolean
---@field gutter_color renderer.color
---@field selection_background boolean
---@field selection_custom_color boolean
---@field selection_color renderer.color
config.plugins.guttercolor = common.merge({
  enabled = true,
  gutter_background = true,
  gutter_custom_color = false,
  gutter_color = style.line_highlight,
  selection_background = true,
  selection_custom_color = false,
  selection_color = style.selection,
  config_spec = {
    name = "Gutter Color",
    {
      label = "Enabled",
      description = "Enable custom gutter background drawing.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Gutter Background",
      description = "Draw a background behind the gutter.",
      path = "gutter_background",
      type = "toggle",
      default = true
    },
    {
      label = "Custom Gutter Color",
      description = "Use a custom gutter color.",
      path = "gutter_custom_color",
      type = "toggle",
      default = true
    },
    {
      label = "Gutter Color",
      description = "Custom color used for the gutter background.",
      path = "gutter_color",
      type = "color",
      default = style.line_highlight
    },
    {
      label = "Selection Background",
      description = "Use text selection color as gutter background on selected lines.",
      path = "selection_background",
      type = "toggle",
      default = true
    },
    {
      label = "Custom Selection Color",
      description = "Use a custom text selection color.",
      path = "selection_custom_color",
      type = "toggle",
      default = true
    },
    {
      label = "Selection Color",
      description = "Custom color used for selected lines gutter background.",
      path = "selection_color",
      type = "color",
      default = style.selection
    }
  }
}, config.plugins.guttercolor)


---@param self core.docview
---@param line integer
---@return renderer.color? color
local function get_gutter_color(self, line)
  local conf = config.plugins.guttercolor
  if not conf.enabled or not config.show_line_numbers then return nil end
  local line_is_selected = false
  for _, line1, _, line2 in self.doc:get_selections(true) do
    if line >= line1 and line <= line2 then line_is_selected = true break end
  end
  if conf.selection_background and line_is_selected then
    return conf.selection_custom_color and conf.selection_color or style.selection
  end
  if conf.gutter_background then
    return conf.gutter_custom_color and conf.gutter_color or style.line_highlight
  end
  return nil
end

local draw_line_gutter = DocView.draw_line_gutter
function DocView:draw_line_gutter(line, x, y, width)
  local color = get_gutter_color(self, line)
  if not color then return draw_line_gutter(self, line, x, y, width) end
  local lh = self:get_line_height()
  local lx = x + style.padding.x
  local gw, gp = self:get_gutter_width()
  renderer.draw_rect(lx-gp/2, y, gw, lh, color)
  return draw_line_gutter(self, line, x, y, width)
end

command.add(nil, {
  ["gutter-color:toggle"] = function()
    config.plugins.guttercolor.enabled = not config.plugins.guttercolor.enabled
  end,
  ["gutter-color:toggle-background"] = function()
    config.plugins.guttercolor.gutter_background =
      not config.plugins.guttercolor.gutter_background
  end,
  ["gutter-color:toggle-selection"] = function()
    config.plugins.guttercolor.selection_background =
      not config.plugins.guttercolor.selection_background
  end
})
