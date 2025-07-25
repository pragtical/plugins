-- mod-version:3
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local style = require "core.style"
local DocView = require "core.docview"

config.plugins.indentguide = common.merge({
  enabled = true,
  highlight = true,
  highlight_distance = 3000,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Indent Guide",
    {
      label = "Enable",
      description = "Toggle the drawing of indentation indicator lines.",
      path = "enabled",
      type = "toggle",
      default = true
    },
    {
      label = "Highlight Line",
      description = "Toggle the highlight of the curent indentation indicator lines.",
      path = "highlight",
      type = "toggle",
      default = true
    },
    {
      label = "Maximum Highlight Distance",
      description = "A high value can cause performance issues on documents with tens of thousands of lines.",
      path = "highlight_distance",
      type = "number",
      min = 100,
      default = 3000
    }
  }
}, config.plugins.indentguide)

local indentguide = {}

function indentguide.get_line_spaces(doc, line, dir)
  local _, indent_size = doc:get_indent_info()
  local text = doc.lines[line]
  if not text or #text == 1 then
    return -1
  end
  local s, e = text:find("^%s*")
  if e == #text then
    return indentguide.get_line_spaces(doc, line + dir, dir)
  end
  local n = 0
  for _,b in pairs({text:byte(s, e)}) do
    n = n + (b == 9 and indent_size or 1)
  end
  return n
end


function indentguide.get_line_indent_guide_spaces(doc, line)
  if doc.lines[line]:find("^%s*\n") then
    return math.max(
      indentguide.get_line_spaces(doc, line - 1, -1),
      indentguide.get_line_spaces(doc, line + 1,  1))
  end
  return indentguide.get_line_spaces(doc, line)
end


local docview_update = DocView.update
function DocView:update()
  docview_update(self)

  if not config.plugins.indentguide.enabled or not self:is(DocView) then
    return
  end

  local function get_indent(line)
    if line < 1 or line > #self.doc.lines then return -1 end
    if not self.indentguide_indents[line] then
      self.indentguide_indents[line] = indentguide.get_line_indent_guide_spaces(self.doc, line)
    end
    return self.indentguide_indents[line]
  end

  self.indentguide_indents = {}
  self.indentguide_indent_active = {}

  local minline, maxline = self:get_visible_line_range()
  for i = minline, maxline do
    self.indentguide_indents[i] = indentguide.get_line_indent_guide_spaces(self.doc, i)
  end

  if not config.plugins.indentguide.highlight then
    return
  end

  local max_distance = config.plugins.indentguide.highlight_distance

  local _, indent_size = self.doc:get_indent_info(self.doc)
  for _,line in self.doc:get_selections() do
    if
      (line > minline or minline-line < max_distance)
      and
      (line < maxline or line-maxline < max_distance)
    then
      local lvl = get_indent(line)
      local top, bottom

      if not self.indentguide_indent_active[line]
      or self.indentguide_indent_active[line] > lvl then

        -- check if we're the header or the footer of a block
        if get_indent(line + 1) > lvl and get_indent(line + 1) <= lvl + indent_size then
          top = true
          lvl = get_indent(line + 1)
        elseif get_indent(line - 1) > lvl and get_indent(line - 1) <= lvl + indent_size then
          bottom = true
          lvl = get_indent(line - 1)
        end

        self.indentguide_indent_active[line] = lvl

        -- check if the lines before the current are part of the block
        local i = line - 1
        if i > 0 and not top then
          repeat
            if get_indent(i) <= lvl - indent_size then break end
            self.indentguide_indent_active[i] = lvl
            i = i - 1
          until i < minline
        end
        -- check if the lines after the current are part of the block
        i = line + 1
        if i <= #self.doc.lines and not bottom then
          repeat
            if get_indent(i) <= lvl - indent_size then break end
            self.indentguide_indent_active[i] = lvl
            i = i + 1
          until i > maxline
        end
      end
    end
  end
end


function indentguide.get_width()
  return math.max(1, SCALE)
end


local draw_line_text = DocView.draw_line_text
function DocView:draw_line_text(line, x, y)
  if config.plugins.indentguide.enabled and self:is(DocView) then
    local spaces = self.indentguide_indents[line] or -1
    local _, indent_size = self.doc:get_indent_info()
    local w = indentguide.get_width()
    local h = self:get_line_height()
    local font = self:get_font()
    local space_sz = font:get_width(" ")
    for i = 0, spaces - 1, indent_size do
      local color = style.guide or style.selection
      local active_lvl = self.indentguide_indent_active[line] or -1
      if i < active_lvl and i + indent_size >= active_lvl then
        color = style.guide_highlight or style.accent
      end
      local sw = space_sz * i
      renderer.draw_rect(math.ceil(x + sw), y, w, h, color)
    end
  end
  return draw_line_text(self, line, x, y)
end


command.add(nil, {
  ["indent-guide:toggle"] = function()
    config.plugins.indentguide.enabled = not config.plugins.indentguide.enabled
    core.log(
      "Indent Guide: %s",
      config.plugins.indentguide.enabled and "Enabled" or "Disabled"
    )
  end,

  ["indent-guide:toggle-highlight"] = function()
    config.plugins.indentguide.highlight = not config.plugins.indentguide.highlight
    core.log(
      "Indent Guide Highlight: %s",
      config.plugins.indentguide.highlight and "Enabled" or "Disabled"
    )
  end
})

return indentguide
