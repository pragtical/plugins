-- mod-version:3.1
-- Read books in status bar, with boss key and mouse wheel support.

local core = require("core")
local common = require("core.common")
local config = require("core.config")
local style = require("core.style")
local StatusView = require("core.statusview")
local command = require("core.command")
local keymap = require("core.keymap")

local PATH = ""
local LIMIT = 10
local NEWLINE = " "

config.plugins.thief_book = common.merge({
  path = PATH,
  page_length = LIMIT,
  separator = NEWLINE,
  cjk = false,

  config_spec = {
    name = "Thief Book",
    {
      label = "Path",
      description = "Absolute path to the txt file.",
      path = "path",
      type = "string",
      default = PATH,
    },
    {
      label = "CJK",
      description = "Count UTF-8 characters (true) or words (false)",
      path = "cjk",
      type = "toggle",
      default = false,
    },
    {
      label = "Page length",
      description = "words (default) or UTF-8 characters per page.",
      path = "page_length",
      type = "number",
      default = LIMIT,
      min = 3,
      max = 120,
    },
    {
      label = "Newline",
      description = "String to indicate newline",
      path = "separator",
      type = "string",
      default = NEWLINE,
    },
  },
}, config.plugins.thief_book)

local state = {
  path = nil,
  pages = { "" },
  page = 1,
  error = nil,
  boss_key = false,
  cached_cjk = nil,
  cached_page_length = nil,
  cached_separator = nil,
}

local function decode_separator(separator)
  separator = tostring(separator or NEWLINE)
  separator = separator:gsub("\\r", "\r")
  separator = separator:gsub("\\n", "\n")
  separator = separator:gsub("\\t", "\t")
  return separator
end

local function utf8_char_size(byte)
  if byte < 0x80 then
    return 1
  end
  if byte < 0xE0 then
    return 2
  end
  if byte < 0xF0 then
    return 3
  end
  return 4
end

local function make_pages(text, page_length, cjk)
  local pages = {}
  local current = {}
  local count = 0

  page_length = math.max(1, math.floor(tonumber(page_length) or LIMIT))

  if cjk then
    local byte_index = 1

    while byte_index <= #text do
      local char_size = utf8_char_size(text:byte(byte_index))
      local character = text:sub(byte_index, byte_index + char_size - 1)

      current[#current + 1] = character
      count = count + 1
      byte_index = byte_index + char_size

      if count >= page_length then
        pages[#pages + 1] = table.concat(current)
        current = {}
        count = 0
      end
    end
  else
    -- words
    for whitespace, word in text:gmatch("(%s*)(%S+)") do
      if count >= page_length then
        pages[#pages + 1] = table.concat(current)
        current = {}
        count = 0
      end

      current[#current + 1] = whitespace
      current[#current + 1] = word
      count = count + 1
    end

    -- keep trailing space
    local trailing_whitespace = text:match("(%s+)$")
    if trailing_whitespace then
      current[#current + 1] = trailing_whitespace
    end
  end

  if #current > 0 or #pages == 0 then
    pages[#pages + 1] = table.concat(current)
  end

  return pages
end

local function load_book()
  local plugin_config = config.plugins.thief_book
  local path = tostring(plugin_config.path or "")
  local page_length = tonumber(plugin_config.page_length) or LIMIT
  local separator = plugin_config.separator
  local cjk = plugin_config.cjk == true

  state.path = path
  state.page = 1
  state.error = nil
  -- always cache to avoid unnecessary retry on failure
  state.cached_page_length = page_length
  state.cached_separator = separator
  state.cached_cjk = cjk

  if path == "" then
    state.pages = { "Path not set" }
    return
  end

  local file, err = io.open(path, "rb")
  if not file then
    state.pages = { "Cannot open file: " .. tostring(err) }
    state.error = err
    return
  end

  local text = file:read("*a") or ""
  file:close()

  -- unify separator
  text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
  text = text:gsub("\n", decode_separator(separator))

  state.pages = make_pages(text, page_length, cjk)
end

local function ensure_book_loaded()
  local plugin_config = config.plugins.thief_book
  local path = tostring(plugin_config.path or "")
  local page_length = tonumber(plugin_config.page_length) or LIMIT
  local separator = plugin_config.separator
  local cjk = plugin_config.cjk == true
  if
    state.path ~= path
    or state.cached_page_length ~= page_length
    or state.cached_separator ~= separator
    or state.cached_cjk ~= cjk
  then
    load_book()
  end
end

local function previous_page()
  ensure_book_loaded()
  if state.boss_key then
    return
  end

  state.page = state.page - 1
  if state.page < 1 then
    state.page = #state.pages
  end
end

local function next_page()
  ensure_book_loaded()
  if state.boss_key then
    return
  end

  state.page = state.page + 1
  if state.page > #state.pages then
    state.page = 1
  end
end

local function toggle_boss_key()
  state.boss_key = not state.boss_key
end

local function goto_page()
  ensure_book_loaded()
  if state.boss_key then
    return
  end
  core.command_view:enter("Go to page", {
    submit = function(text)
      local page = tonumber(text)
      if not page then
        return
      end
      page = math.floor(page)
      state.page = math.max(1, math.min(page, #state.pages))
    end,
  })
end

command.add(nil, {
  ["thief-book:prev-page"] = previous_page,
  ["thief-book:next-page"] = next_page,
  ["thief-book:goto-page"] = goto_page,
  ["thief-book:toggle-boss-key"] = toggle_boss_key,
  ["thief-book:reload"] = function()
    state.path = nil
    load_book()
  end,
})

keymap.add({
  ["ctrl+m"] = "thief-book:toggle-boss-key",
  ["ctrl+alt+,"] = "thief-book:prev-page",
  ["ctrl+alt+."] = "thief-book:next-page",
  -- ["ctrl+alt+/"] = "thief-book:goto-page",
})

core.status_view:add_item({
  name = "status:thief-book",
  alignment = StatusView.Item.LEFT,
  position = -1,
  tooltip = "Thief Book: Ctrl+Alt+, PgUp; Ctrl+Alt+. PgDn; Ctrl+M Boss",
  separator = core.status_view.separator2,

  get_item = function()
    -- hide in command view
    if core.active_view == core.command_view then
      return { style.text, "" }
    end
    -- hide when the boss comes
    if state.boss_key then
      return { style.text, "" }
    end

    ensure_book_loaded()

    local text = state.pages[state.page] or ""
    return {
      style.text,
      text,
      style.dim,
      ("  [%d/%d]"):format(state.page, #state.pages),
    }
  end,
})

local status_view = core.status_view
local old_on_mouse_wheel = status_view.on_mouse_wheel
function status_view:on_mouse_wheel(y, x)
  if y > 0 then
    previous_page()
    return true
  elseif y < 0 then
    next_page()
    return true
  end
  if old_on_mouse_wheel then
    return old_on_mouse_wheel(self, y, x)
  end
end

return state
