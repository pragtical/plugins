-- mod-version:3.11

local core = require("core")
local command = require("core.command")
local common = require("core.common")
local DocView = require("core.docview")
local config = require("core.config")
local style = require("core.style")

local indentrainbow = {}
local MAX_LINES = 3000
local NOOP_EXT = {
  "log",
  "md",
  "nfo",
  "rmd",
  "rst",
}

config.plugins.indentrainbow = common.merge({
  enabled = true,
  max = MAX_LINES,
  exclude = NOOP_EXT,
  style = "line",
  highlight = true,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Indent Rainbow",
    {
      label = "Enable",
      description = "Toggle the drawing of rainbow indentation guides.",
      path = "enabled",
      type = "toggle",
      default = true,
    },
    {
      label = "Style",
      description = "Style of indent rainbow.",
      path = "style",
      type = "selection",
      default = "line",
      values = {
        { "Block", "block" },
        { "Line", "line" },
      },
    },
    {
      label = "Highlight Line",
      description = "Highlight the current indentation guide in line style.",
      path = "highlight",
      type = "toggle",
      default = true,
    },
    {
      label = "Max Lines",
      description = "Maximum distance from the visible lines for active indentation highlighting.",
      path = "max",
      type = "number",
      default = MAX_LINES,
      min = 50,
      max = 100000,
    },
    {
      label = "Exclude",
      description = "File extensions to disable indent rainbow.",
      path = "exclude",
      type = "LIST_STRINGS",
      default = NOOP_EXT,
    },
  },
}, config.plugins.indentrainbow)

local block_palette = {
  { common.color("#7fff7f16") },
  { common.color("#ff7fff16") },
  { common.color("#4fecec16") },
  { common.color("#d62c2c16") },
  { common.color("#ffff4016") },
}

local line_palette = {
  "string",
  "keyword",
  "function",
  "number",
  "keyword2",
}

local function get_block_color(level)
  return block_palette[(level - 1) % #block_palette + 1]
end

local function get_line_color(level)
  local name = line_palette[(level - 1) % #line_palette + 1]
  local color = style.syntax and style.syntax[name]
  color = color or style[name]
  -- fallback
  return color or style.guide or style.selection
end

-- exclude non source code
local function is_exclude_document(doc)
  local plugin_config = config.plugins.indentrainbow
  if not doc or not doc.lines then
    return true
  end

  local filename = doc.filename
  if type(filename) ~= "string" or filename == "" then
    return true
  end

  local ext = filename:match("%.([^%.]+)$")
  if not ext then
    return true
  end

  ext = ext:lower()

  local exclude_exts = plugin_config.exclude
  if type(exclude_exts) == "table" then
    for _, exclude_ext in ipairs(exclude_exts) do
      if type(exclude_ext) == "string" and ext == exclude_ext:lower() then
        return true
      end
    end
  end
  return false
end

local function get_indent_columns(doc, line)
  if not doc or not doc.lines then
    return 0
  end

  local text = doc.lines[line]
  if not text then
    return 0
  end

  local whitespace = text:match("^[ \t]*") or ""
  if #whitespace == 0 then
    return 0
  end

  local _, indent_size = doc:get_indent_info()
  indent_size = math.max(1, indent_size or 2)

  local columns = 0
  for i = 1, #whitespace do
    if whitespace:byte(i) == 9 then
      columns = columns + indent_size
    else
      columns = columns + 1
    end
  end
  return columns
end

local function get_neighbor_indent_columns(doc, line, direction)
  local text = doc.lines[line]
  while text and #text > 1 and text:find("^%s*$") do
    line = line + direction
    text = doc.lines[line]
  end
  return text and #text > 1 and get_indent_columns(doc, line) or -1
end

local function get_line_indent_columns(doc, line)
  local text = doc.lines[line]
  if not text then return -1 end
  if text:find("^%s*\n") then
    return math.max(
      get_neighbor_indent_columns(doc, line - 1, -1),
      get_neighbor_indent_columns(doc, line + 1, 1)
    )
  end
  return get_indent_columns(doc, line)
end

local docview_update = DocView.update
function DocView:update()
  docview_update(self)

  self.indentrainbow_indents = nil
  self.indentrainbow_indent_active = nil
  local plugin_config = config.plugins.indentrainbow
  if not plugin_config.enabled or not self:is(DocView) or plugin_config.style ~= "line"
    or is_exclude_document(self.doc) then
    return
  end

  local indents, active = {}, {}
  self.indentrainbow_indents = indents
  self.indentrainbow_indent_active = active
  local function get_indent(line)
    if line < 1 or line > #self.doc.lines then return -1 end
    if indents[line] == nil then
      indents[line] = get_line_indent_columns(self.doc, line)
    end
    return indents[line]
  end

  local minline, maxline = self:get_visible_line_range()
  for _, line in self:each_visible_line() do
    if line and line >= 1 and line <= #self.doc.lines then get_indent(line) end
  end
  if not plugin_config.highlight then return end

  local max_distance = math.max(0, tonumber(plugin_config.max) or MAX_LINES)
  local _, indent_size = self.doc:get_indent_info()
  indent_size = math.max(1, indent_size or 2)
  for _, line in self.doc:get_selections() do
    local offset = self:offset_from_position(line, 1)
    if offset
      and (offset > minline or minline - offset < max_distance)
      and (offset < maxline or offset - maxline < max_distance) then
      local level = get_indent(line)
      local top, bottom
      if not active[line] or active[line] > level then
        -- Match indentguide's block header/footer and visible-row traversal.
        if get_indent(line + 1) > level and get_indent(line + 1) <= level + indent_size then
          top = true
          level = get_indent(line + 1)
        elseif get_indent(line - 1) > level and get_indent(line - 1) <= level + indent_size then
          bottom = true
          level = get_indent(line - 1)
        end

        active[line] = level
        local stop_level = math.max(0, level - indent_size)
        local offset_i = offset - 1
        if offset_i >= minline and not top then
          repeat
            local i = self:position_from_offset(offset_i)
            if not i then break end
            if get_indent(i) <= stop_level then break end
            active[i] = level
            offset_i = offset_i - 1
          until offset_i < minline
        end
        offset_i = offset + 1
        if offset_i <= maxline and not bottom then
          repeat
            local i = self:position_from_offset(offset_i)
            if not i then break end
            if get_indent(i) <= stop_level then break end
            active[i] = level
            offset_i = offset_i + 1
          until offset_i > maxline
        end
      end
    end
  end
end

local draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(line, x, y)
  local plugin_config = config.plugins.indentrainbow
  if not plugin_config.enabled or not self:is(DocView) or is_exclude_document(self.doc) then
    return draw_line_text(self, line, x, y)
  end

  local columns
  if plugin_config.style == "line" then
    columns = self.indentrainbow_indents and self.indentrainbow_indents[line]
    if columns == nil then columns = get_line_indent_columns(self.doc, line) end
  else
    columns = get_indent_columns(self.doc, line)
  end

  if columns > 0 then
    local _, indent_size = self.doc:get_indent_info()
    indent_size = math.max(1, indent_size or 2)

    local line_height = self:get_line_visual_height(line)
    local space_width = self:get_font():get_width(" ")

    -- line
    if plugin_config.style == "line" then
      local width = math.max(1, SCALE)
      local active_level = plugin_config.highlight and self.indentrainbow_indent_active
        and self.indentrainbow_indent_active[line] or -1
      for i = 0, columns - 1, indent_size do
        local level = math.floor(i / indent_size) + 1
        local color = get_line_color(level)
        if i < active_level and i + indent_size >= active_level then
          color = style.guide_highlight or style.accent
        end
        renderer.draw_rect(
          math.ceil(x + i * space_width), y, width, line_height, color
        )
      end
    -- block
    else
      for i = 0, columns - 1, indent_size do
        local level = math.floor(i / indent_size) + 1
        local width = math.min(indent_size, columns - i)

        renderer.draw_rect(
          math.floor(x + i * space_width),
          y,
          math.max(1, math.ceil(width * space_width)),
          line_height,
          get_block_color(level)
        )
      end
    end
  end

  return draw_line_text(self, line, x, y)
end

command.add(nil, {
  ["indent-rainbow:toggle"] = function()
    config.plugins.indentrainbow.enabled = not config.plugins.indentrainbow.enabled
    core.log(
      "Indent Rainbow: %s",
      config.plugins.indentrainbow.enabled and "Enabled" or "Disabled"
    )
  end,

  ["indent-rainbow:toggle-highlight"] = function()
    config.plugins.indentrainbow.highlight = not config.plugins.indentrainbow.highlight
    core.log(
      "Indent Rainbow Highlight: %s",
      config.plugins.indentrainbow.highlight and "Enabled" or "Disabled"
    )
  end,
})

return indentrainbow
