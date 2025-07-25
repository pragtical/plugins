-- mod-version:3
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local style = require "core.style"
local keymap = require "core.keymap"
local treeview = require "plugins.treeview"
local DocView = require "core.docview"

config.plugins.centerdoc = common.merge({
  enabled = true,
  zen_mode = false,
  zen_mode_hide_status_bar = true,
  zen_mode_hide_tabs = true,
  zen_mode_hide_line_numbers = true
}, config.plugins.centerdoc)

local draw_line_gutter = DocView.draw_line_gutter
local get_gutter_width = DocView.get_gutter_width


function DocView:draw_line_gutter(line, x, y, width)
  local lh
  if not config.plugins.centerdoc.enabled then
    lh = draw_line_gutter(self, line, x, y, width)
  else
    local real_gutter_width
    if type(config.show_line_numbers) == "boolean" then
      real_gutter_width = config.show_line_numbers
        and self:get_font():get_width(#self.doc.lines)
        or self:get_gutter_width()
    else
      real_gutter_width = self:get_font():get_width(#self.doc.lines)
    end
    local offset = self:get_gutter_width() - real_gutter_width * 2
    offset = offset - style.padding.x / 2
    lh = draw_line_gutter(self, line, x + offset, y, real_gutter_width)
  end
  return lh
end


function DocView:get_gutter_width()
  if not config.plugins.centerdoc.enabled then
    return get_gutter_width(self)
  else
    local real_gutter_width, gutter_padding = get_gutter_width(self)
    local width = real_gutter_width + self:get_font():get_width("n") * config.line_limit
    return math.max((self.size.x - width) / 2, real_gutter_width), gutter_padding
  end
end

---@type system.windowmode
local previous_win_status
---@type boolean
local previous_treeview_status
---@type boolean
local previous_statusbar_status
---@type boolean
local previous_tabs_status
---@type boolean
local previous_line_numbers_status

local function save_previous_status()
  previous_win_status = system.get_window_mode(core.window)
  previous_treeview_status = treeview.visible
  previous_statusbar_status = core.status_view.visible
  previous_tabs_status = config.hide_tabs
  previous_line_numbers_status = config.show_line_numbers
end

local function toggle_zen_mode(enabled)
  config.plugins.centerdoc.zen_mode = enabled

  if config.plugins.centerdoc.zen_mode then
    save_previous_status()

    config.plugins.centerdoc.enabled = true
    if previous_win_status ~= "fullscreen" then
      command.perform "core:toggle-fullscreen"
    end
    treeview.visible = false
    if config.plugins.centerdoc.zen_mode_hide_status_bar then
      core.status_view.visible = false
    end
    if config.plugins.centerdoc.zen_mode_hide_tabs then
      config.hide_tabs = true
    end
    if config.plugins.centerdoc.zen_mode_hide_line_numbers then
      if type(config.show_line_numbers) == "boolean" then
        config.show_line_numbers = false
      end
    end
  else
    config.plugins.centerdoc.enabled = false
    if
      previous_win_status ~= "fullscreen"
      and
      system.get_window_mode(core.window) == "fullscreen"
    then
      command.perform "core:toggle-fullscreen"
    end
    treeview.visible = previous_treeview_status
    if config.plugins.centerdoc.zen_mode_hide_status_bar then
      core.status_view.visible = previous_statusbar_status
    end
    if config.plugins.centerdoc.zen_mode_hide_tabs then
      config.hide_tabs = previous_tabs_status
    end
    if config.plugins.centerdoc.zen_mode_hide_line_numbers then
      config.show_line_numbers = previous_line_numbers_status
    end
  end
end

local on_startup = true
save_previous_status()

-- The config specification used by the settings gui
config.plugins.centerdoc.config_spec = {
  name = "Center Document",
  {
    label = "Enable",
    description = "Activates document centering by default.",
    path = "enabled",
    type = "toggle",
    default = true
  },
  {
    label = "Zen Mode",
    description = "Activates zen mode by default.",
    path = "zen_mode",
    type = "toggle",
    default = false,
    on_apply = function(enabled)
      if on_startup then
        core.add_thread(function()
          save_previous_status()
          toggle_zen_mode(enabled)
        end)
        on_startup = false
      else
        toggle_zen_mode(enabled)
      end
    end
  },
  {
    label = "Hide Status Bar on Zen Mode",
    description = "HIde or show the status bar when using zen mode.",
    path = "zen_mode_hide_status_bar",
    type = "toggle",
    default = true,
    on_apply = function(enabled)
      if config.plugins.centerdoc.zen_mode then
        core.status_view.visible = not enabled
      end
    end
  },
  {
    label = "Hide Tabs on Zen Mode",
    description = "Creates a more inmmersive experience (requires pragtical >= v3.5.3).",
    path = "zen_mode_hide_tabs",
    type = "toggle",
    default = true,
    on_apply = function(enabled)
      if config.plugins.centerdoc.zen_mode then
        config.hide_tabs = enabled
      end
    end
  },
  {
    label = "Hide Line Numbers on Zen Mode",
    description = "Creates a more inmmersive experience (requires pragtical >= v3.7.0).",
    path = "zen_mode_hide_line_numbers",
    type = "toggle",
    default = true,
    on_apply = function(enabled)
      if config.plugins.centerdoc.zen_mode then
        if type(config.show_line_numbers) == "boolean" then
          config.show_line_numbers = enabled
        end
      end
    end
  }
}


command.add(nil, {
  ["center-doc:toggle"] = function()
    config.plugins.centerdoc.enabled = not config.plugins.centerdoc.enabled
  end,
  ["center-doc:zen-mode-toggle"] = function()
    toggle_zen_mode(not config.plugins.centerdoc.zen_mode)
  end,
})

keymap.add { ["ctrl+alt+z"] = "center-doc:zen-mode-toggle" }
