-- mod-version:3
local core = require "core"
local config = require "core.config"
local command = require "core.command"
local common = require "core.common"
local DocView = require "core.docview"

config.plugins.autowrap = common.merge({
  enabled = false,
  files = { "%.md$", "%.txt$" },
  -- The config specification used by the settings gui
  config_spec = {
    name = "Auto Wrap",
    {
      label = "Enable",
      description = "Activates text auto wrapping by default.",
      path = "enabled",
      type = "toggle",
      default = false
    },
    {
      label = "Files",
      description = "List of Lua patterns matching files to auto wrap.",
      path = "files",
      type = "list_strings",
      default = { "%.md$", "%.txt$" },
    }
  }
}, config.plugins.autowrap)


local function get_prefix(text)
  -- Continue indentation and reflow-style prefixes, but not bare punctuation.
  local prefix = text:match("^[^%w\n%[%](){}`'\"\128-\255]*")
  if not prefix:find("[\t ]$") then
    prefix = text:match("^[\t ]*")
  end
  return prefix
end


local function find_break(text, start_col, width, fill_long_words)
  if width < 1 or #text - start_col <= width then return end
  local boundary = text:uoffset(width + 1, start_col)
  if not boundary or boundary >= #text then return end

  -- Prefer a word boundary; split long words without creating empty lines.
  local space = text:sub(start_col, boundary):match("()[\t ]+[^\t ]*$")
  if space then
    local split = start_col + space - 1
    local _, last = text:find("^[\t ]+", split)
    if fill_long_words and last + 1 < boundary then
      local word_end = text:find("%s", last + 1) or #text
      local word_limit = text:uoffset(width + 1, last + 1)
      if word_limit and word_limit < word_end then
        return boundary, boundary
      end
    end
    return split, last + 1
  end
  return boundary, boundary
end


local function wrap_paragraph(text, limit)
  local prefix = get_prefix(text)
  local start_col, width = #prefix + 1, limit - #prefix
  local input = text .. "\n"
  local split, next_col = find_break(input, start_col, width, true)
  if not split then return text end

  local lines = {}
  repeat
    lines[#lines + 1] = prefix .. input:sub(start_col, split - 1)
    start_col = next_col
    split, next_col = find_break(input, start_col, width, true)
  until not split
  lines[#lines + 1] = prefix .. input:sub(start_col, -2)
  return table.concat(lines, "\n")
end


local function wrap_text(text, limit)
  return (text:gsub("[^\n]+", function(line)
    return wrap_paragraph(line, limit)
  end))
end


local function reflow_text(text, limit)
  if limit < 1 then return text end
  local output, paragraph = {}, {}
  local prefix, fence
  local function flush()
    if #paragraph > 0 then
      output[#output + 1] = wrap_paragraph(prefix .. table.concat(paragraph, " "), limit)
      paragraph = {}
    end
  end

  for line in (text .. "\n"):gmatch("(.-)\n") do
    local fence_start = line:match("^[\t ]*(```+)") or line:match("^[\t ]*(~~~+)")
    if fence then
      output[#output + 1] = line
      if line:find("^[\t ]*" .. fence .. fence:sub(1, 1) .. "*[\t ]*$") then
        fence = nil
      end
    elseif fence_start then
      flush()
      output[#output + 1] = line
      fence = fence_start
    elseif line:find("^[\t ]*$") then
      flush()
      output[#output + 1] = line
    else
      local line_prefix = get_prefix(line)
      if line_prefix ~= prefix or line:find("^[\t ]*[-*+]%s")
        or line:find("^[\t ]*%d+[.)]%s") then
        flush()
      end
      prefix = line_prefix
      paragraph[#paragraph + 1] = line:sub(#prefix + 1):gsub("[\t ]+$", "")
    end
  end
  flush()
  return table.concat(output, "\n")
end


local on_text_input = DocView.on_text_input

DocView.on_text_input = function(self, ...)
  on_text_input(self, ...)

  if not config.plugins.autowrap.enabled then return end
  local doc = self.doc
  if doc.binary or #doc.selections > 4 then return end

  local line, col = doc:get_selection()
  local text = doc.lines[line]
  local limit = config.line_limit
  if limit < 1 or col ~= #text or col - 1 <= limit then return end

  -- early-exit if the filename does not match a file type pattern
  local filename = doc.filename or ""
  local matched = false
  for _, ptn in ipairs(config.plugins.autowrap.files) do
    if filename:match(ptn) then
      matched = true
      break
    end
  end
  if not matched then return end

  local prefix = get_prefix(text)
  local width = limit - #prefix
  local split, next_col = find_break(text, #prefix + 1, width)
  while split do
    if split ~= next_col then
      doc:remove(line, split, line, next_col)
    end
    doc:insert(line, split, "\n" .. prefix)
    line, col = line + 1, #prefix + col - next_col + 1
    doc:set_selection(line, col)
    text = doc.lines[line]
    split, next_col = find_break(text, #prefix + 1, width)
  end
end

command.add(function()
  local view = core.active_view
  return view:is(DocView) and not view.doc.binary, view
end, {
  ["auto-wrap:wrap"] = function(dv)
    dv.doc:replace(function(text)
      return wrap_text(text, config.line_limit)
    end)
  end,
  ["auto-wrap:reflow"] = function(dv)
    dv.doc:replace(function(text)
      return reflow_text(text, config.line_limit)
    end)
  end
})

command.add(nil, {
  ["auto-wrap:toggle"] = function()
    config.plugins.autowrap.enabled = not config.plugins.autowrap.enabled
    if config.plugins.autowrap.enabled then
      core.log("Auto wrap: on")
    else
      core.log("Auto wrap: off")
    end
  end
})
