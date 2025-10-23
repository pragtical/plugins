-- mod-version:3 priority:5
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"
local common = require "core.common"
local command = require "core.command"

config.plugins.linenumbers = common.merge({
  show = true,
  relative = false,
  hybrid = false,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Line Numbers",
    {
      label = "Show Numbers",
      description = "Display or hide the line numbers.",
      path = "show",
      type = "toggle",
      default = true
    },
    {
      label = "Relative Line Numbers",
      description = "Display relative line numbers starting from active line.",
      path = "relative",
      type = "toggle",
      default = false
    },
    {
      label = "Hybrid Line Numbers",
      description = "Display hybrid line numbers starting from active line (Overpowers relative line-numbers).",
      path = "hybrid",
      type = "toggle",
      default = false
    }
  }
}, config.plugins.linenumbers)

if type(config.show_line_numbers) == "boolean" then
  table.remove(config.plugins.linenumbers.config_spec, 1)
end

local draw_line_gutter = DocView.draw_line_gutter
local get_gutter_width = DocView.get_gutter_width

function DocView:draw_line_gutter(line, x, y, width)
  local lh = self:get_line_height()
  if
    type(config.show_line_numbers) ~= "boolean"
    and
    not config.plugins.linenumbers.show
  then
    return lh
  end

  if
    not (config.plugins.linenumbers.relative or config.plugins.linenumbers.hybrid)
    or
    (type(config.show_line_numbers) == "boolean" and not config.show_line_numbers)
  then
    return draw_line_gutter(self, line, x, y, width)
  end

  local color = style.line_number

  for _, line1, _, line2 in self.doc:get_selections(true) do
    if line == line1 then
      color = style.line_number2
      break
    end
  end

  local l1 = self.doc:get_selection(false)
  local local_idx = math.abs(line - l1)
  local alignment = "right"
  local x_offset = style.padding.x / 2

  if config.plugins.linenumbers.hybrid and line == l1 then
    local_idx = line
  end

  -- allow other plugins to also draw into the gutter
  draw_line_gutter(self, line, x, y, width)

  -- hide old numbers
  renderer.draw_rect(x + x_offset, y, width + style.padding.x, lh, style.background)

  -- show new number
  common.draw_text(
    self:get_font(),
    color, local_idx, alignment,
    x + x_offset,
    y,
    width + style.padding.x / 2, lh
  )

  return lh
end

if type(config.show_line_numbers) ~= "boolean" then
  command.add(nil, {
    ["line-numbers:toggle"]           = function()
      config.plugins.linenumbers.show = not config.plugins.linenumbers.show
    end,

    ["line-numbers:disable"]          = function()
      config.plugins.linenumbers.show = false
    end,

    ["line-numbers:enable"]           = function()
      config.plugins.linenumbers.show = true
    end
  })
end

command.add(nil, {
  ["relative-line-numbers:toggle"]  = function()
    config.plugins.linenumbers.relative = not config.plugins.linenumbers.relative
  end,

  ["relative-line-numbers:enable"]  = function()
    config.plugins.linenumbers.relative = true
  end,

  ["relative-line-numbers:disable"] = function()
    config.plugins.linenumbers.relative = false
  end,

  ["hybrid-line-numbers:toggle"]    = function()
    config.plugins.linenumbers.hybrid = not config.plugins.linenumbers.hybrid
    if config.plugins.linenumbers.hybrid then
      config.plugins.linenumbers.relative = false -- Disable relative mode when enabling hybrid mode
    end
  end,

  ["hybrid-line-numbers:enable"]    = function()
    config.plugins.linenumbers.hybrid = true
    config.plugins.linenumbers.relative = false
  end,

  ["hybrid-line-numbers:disable"]   = function()
    config.plugins.linenumbers.hybrid = false
  end
})
