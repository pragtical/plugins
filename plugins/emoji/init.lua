-- mod-version:3
-- Emoji autocomplete, map :emoji_name to its emoji character.

local core = require("core")
local json = require("core.json")
local RootView = require("core.rootview")
local autocomplete = require("plugins.autocomplete")

local function load_emoji_data()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  local dir = source:match("^(.*[/\\])") or ""

  local file, err = io.open(dir .. "emoji.json", "r")
  if not file then
    core.warn("emoji: cannot open emoji.json: %s", tostring(err))
    return {}
  end

  local text = file:read("*a")
  file:close()

  local ok, data = pcall(json.decode, text)
  if not ok or type(data) ~= "table" then
    core.warn("emoji: cannot decode emoji.json")
    return {}
  end
  return data
end

local entries = load_emoji_data()
local emoji_items = {}
local registered = {}

local function add_keyword(keyword, emoji)
  if type(keyword) ~= "string" or keyword == "" or registered[keyword] then
    return
  end
  registered[keyword] = true
  -- put emoji in text to render it correctly
  emoji_items[keyword .. "  " .. emoji] = {
    onselect = function()
      local view = core.active_view
      local doc = view and view.doc
      if not doc then
        return false
      end
      local line, col = doc:get_selection()
      local before_cursor = (doc.lines[line] or ""):sub(1, col - 1)
      local typed_keyword = before_cursor:match(":([%w_]+)$")
      if not typed_keyword then
        return false
      end
      local start_col = col - #typed_keyword - 1
      doc:remove(line, start_col, line, col)
      doc:text_input(emoji)
      return true
    end,
  }
end

-- register description first, then fallback to aliases
for _, entry in ipairs(entries) do
  if entry.emoji then
    add_keyword(entry.description, entry.emoji)

    for _, alias in ipairs(entry.aliases or {}) do
      add_keyword(alias, entry.emoji)
    end
  end
end

local original_on_text_input = RootView.on_text_input

RootView.on_text_input = function(self, ...)
  original_on_text_input(self, ...)

  local view = core.active_view
  local doc = view and view.doc
  if not doc then
    return
  end

  local line, col = doc:get_selection()
  local before_cursor = (doc.lines[line] or ""):sub(1, col - 1)
  if before_cursor:match(":([%w_]+)$") then
    autocomplete.complete({
      name = "emoji",
      items = emoji_items,
    })
  end
end
