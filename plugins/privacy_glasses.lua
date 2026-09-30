-- mod-version:3.11

local common = require("core.common")
local command = require("core.command")
local config = require("core.config")
local DocView = require("core.docview")
local style = require("core.style")

local privacy_glasses = {}
local MASK_ALPHA = 184

local function get_theme_mask_color()
  local bg = style.background or { 0, 0, 0, 255 }
  return { bg[1], bg[2], bg[3], MASK_ALPHA }
end

config.plugins.privacy_glasses = common.merge({
  enabled = false,
  color = get_theme_mask_color(),

  config_spec = {
    name = "Privacy Glasses",
    {
      label = "Enabled",
      description = "Enable Privacy Glasses by default",
      path = "enabled",
      type = "toggle",
      default = false,
    },
    {
      label = "Color",
      description = "Mask color and opacity",
      path = "color",
      type = "color",
      default = get_theme_mask_color(),
    },
  },
}, config.plugins.privacy_glasses)

local function get_active_line(doc)
  if not doc or type(doc.get_selections) ~= "function" then
    return nil
  end

  local active_line
  for _, _, _, line2 in doc:get_selections() do
    active_line = line2
  end
  return active_line
end

local cached_color_string
local cached_color

-- https://pragtical.dev/docs/api/core.common#color
local function get_color()
  local value = config.plugins.privacy_glasses.color
  -- RGBA in setting, rgba(r, g, b, a)
  if type(value) == "table" then
    return value
  end
  -- Hex color in config, #rrggbbaa
  if type(value) == "string" then
    if value ~= cached_color_string then
      cached_color_string = value
      cached_color = { common.color(value) }
    end
    return cached_color
  end
  -- fallback
  return get_theme_mask_color()
end

-- add blurry mask on inactive lines
local original_draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(line, x, y, ...)
  local result = original_draw_line_text(self, line, x, y, ...)

  local plugin_config = config.plugins.privacy_glasses
  if not plugin_config.enabled or not self.doc or not line then
    return result
  end

  if line ~= get_active_line(self.doc) then
    local line_height = self:get_line_visual_height(line)

    renderer.draw_rect(
      math.floor(self.position.x),
      math.floor(y),
      math.ceil(self.size.x),
      math.ceil(line_height),
      get_color()
    )
  end

  return result
end

command.add(nil, {
  ["privacy-glasses:toggle"] = function()
    config.plugins.privacy_glasses.enabled = not config.plugins.privacy_glasses.enabled
  end,
})

return privacy_glasses
