-- mod-version:3.11

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
  max = MAX_LINES,
  exclude = NOOP_EXT,
  style = "block",
  -- The config specification used by the settings gui
  config_spec = {
    name = "Indent Rainbow",
    {
      label = "Style",
      description = "Style of indent rainbow.",
      path = "style",
      type = "selection",
      default = "block",
      values = {
        { "Block", "block" },
        { "Line", "line" },
      },
    },
    {
      label = "Max Lines",
      description = "Maximum lines allowed to enable indent rainbow.",
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

-- exclude large files and non source code
local function is_exclude_document(doc)
  local plugin_config = config.plugins.indentrainbow
  local max = tonumber(plugin_config.max) or MAX_LINES
  if not doc or not doc.lines or #doc.lines > max then
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

local draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(line, x, y)
  if not self:is(DocView) or is_exclude_document(self.doc) then
    return draw_line_text(self, line, x, y)
  end

  local columns = get_indent_columns(self.doc, line)

  if columns > 0 then
    local _, indent_size = self.doc:get_indent_info()
    indent_size = math.max(1, indent_size or 2)

    local line_height = self:get_line_visual_height(line)
    local space_width = self:get_font():get_width(" ")
    local plugin_config = config.plugins.indentrainbow

    -- line
    if plugin_config.style == "line" then
      for i = 0, columns - 1, indent_size do
        local level = math.floor(i / indent_size) + 1
        -- look better with 3px offset
        renderer.draw_rect(math.floor(x + i * space_width) + 3, y, 1, line_height, get_line_color(level))
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

return indentrainbow
