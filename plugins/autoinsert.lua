-- mod-version:3.1
local core = require "core"
local translate = require "core.doc.translate"
local config = require "core.config"
local common = require "core.common"
local DocView = require "core.docview"
local command = require "core.command"
local keymap = require "core.keymap"


config.plugins.autoinsert = common.merge({
  map = {
    ["["] = "]",
    ["{"] = "}",
    ["("] = ")",
    ['"'] = '"',
    ["'"] = "'",
    ["`"] = "`",
  }
}, config.plugins.autoinsert)


-- @param chr stirng
-- @return boolean
local function is_closer(chr)
  for _, v in pairs(config.plugins.autoinsert.map) do
    if v == chr then
      return true
    end
  end
  return false
end


-- @param text stirng
-- @param chr stirng
-- @return number
local function count_char(text, chr)
  local count = 0
  for _ in text:gmatch(chr) do
    count = count + 1
  end
  return count
end


-- @param dv DocView
-- @param idx number
-- @param text string
-- @param mapping string
-- @return boolean
local function on_text_input_cursor(dv, idx, text, mapping)
  local l1, c1, l2, c2 = dv.doc:get_selection_idx(idx, true)
  local is_selection_empty = not (l1 ~= l2 or c1 ~= c2)

  -- wrap selection if we have a selection
  if mapping and not is_selection_empty then
    dv.doc:insert(l2, c2, mapping)
    dv.doc:insert(l1, c1, text)
    dv.doc:set_selections(idx, l1, c1 + 1, l2, c2 + 1, true)

    return true
  end

  -- no selections, check char next to cursor
  local chr = dv.doc:get_char(l1, c1)

  -- skip inserting closing text if already there,
  -- instead just move the cursor to the right of the chr
  if text == chr and is_closer(chr) then
    dv.doc:move_to_cursor(idx, 1)
    return true
  end

  -- don't insert closing quote if we have a non-even number on this line
  if text == mapping and count_char(dv.doc.lines[l1], text) % 2 == 1 then
    return false
  end

  -- auto insert closing bracket
  -- checks that character next to the cursor is:
  -- either whitespace (%s) or the mapped closer character.
  -- and it's not a double quote character ('"')
  if mapping and (chr:find("%s") or is_closer(chr) and chr ~= '"') then
    dv.doc:insert(l1, c1, text)
    dv.doc:insert(l2, c2 + 1, mapping)
    -- move inside the bracket pair:
    dv.doc:move_to_cursor(idx, 1)
    return true
  end

  return false
end


-- save the original on_text_input to call it later
local on_text_input = DocView.on_text_input

function DocView:on_text_input(text)
  local mapping = config.plugins.autoinsert.map[text]

  -- prevents plugin from operating on `CommandView`
  if getmetatable(self) ~= DocView then
    return on_text_input(self, text)
  end

  -- call auto insert on every selection
  for idx in self.doc:get_selections() do
    local inserted = on_text_input_cursor(self, idx, text, mapping)

    -- operate normally on the cursor when nothing was inserted
    if not inserted then
      self.doc:text_input(text, idx)
    end
  end
end

-- this deletes the matching pair when backspacing the opening one
-- @param doc DocView.doc
-- @param idx number
local function delete_matching_pair(doc, idx)
  local l1, c1, l2, c2 = doc:get_selection_idx(idx, true)

  -- skip backspace if at the beginning of the line
  if c1 <= 1 then
    return
  end

  -- only do it if there's nothing selected for the cursor
  local is_selection_empty = not (l1 ~= l2 or c1 ~= c2)
  if not is_selection_empty then
    return
  end

  -- check if the character to the right of the one being deleted
  -- is the expected matching pair
  local chr = doc:get_char(l1, c1)
  local mapped = config.plugins.autoinsert.map[doc:get_char(l1, c1 - 1)]
  if mapped and mapped == chr then
    -- delete 1 more character
    doc:remove(l1, c1, l2, c2 + 1)
  end
end

-- @param doc DocView.doc
local function on_backspace(doc)
  for idx in doc:get_selections() do
    delete_matching_pair(doc, idx)
  end
  -- execute the backspace normally
  command.perform "doc:backspace"
end

-- need this because the doc:backspace already operates on all cursors,
-- we only want to do it on a single cursor
local function perform_backspace_cursor(doc, idx)
  local _, indent_size = doc:get_indent_info()
  local line1, col1, line2, col2 = doc:get_selection(idx, true)
  if line1 == line2 and col1 == col2 then
    local text = doc:get_text(line1, 1, line1, col1)
    if #text >= indent_size and text:find("^ *$") then
      doc:delete_to_cursor(idx, 0, -indent_size)
      return
    end
  end
  doc:delete_to_cursor(idx, translate.previous_char)
end

-- @param doc DocView.doc
local function on_delete_to_previous_word_start(doc)
  for idx in doc:get_selections() do
    local le, ce = translate.previous_word_start(
      doc, doc:get_selection_idx(idx, true))
    ce = ce + 1 -- dont over delete
    repeat
      local l, c = doc:get_selection_idx(idx, true)

      -- delete character and matching pair if any
      -- we dont call on_backspace because that already operates on every cursor.
      delete_matching_pair(doc, idx)
      perform_backspace_cursor(doc, idx)
    until l <= le and c <= ce
  end
end


-- @param doc DocView.doc
local function on_delete_to_start_of_line(doc)
  for idx in doc:get_selections() do
    local le, ce = translate.start_of_line(
      doc, doc:get_selection_idx(idx, true))
    ce = ce + 1 -- dont over delete
    repeat
      local l, c = doc:get_selection_idx(idx, true)

      -- delete character and matching pair if any
      -- we dont call on_backspace because that already operates on every cursor.
      delete_matching_pair(doc, idx)
      perform_backspace_cursor(doc, idx)
    until l <= le and c <= ce
  end
end


local function predicate()
  return core.active_view:is(DocView), core.active_view.doc
end


command.add(predicate, {
  ["autoinsert:backspace"] = on_backspace,
  ["autoinsert:delete-to-previous-word-start"] = on_delete_to_previous_word_start,
  ["autoinsert:delete-to-start-of-line"] = on_delete_to_start_of_line,
})

keymap.add {
  ["backspace"]            = "autoinsert:backspace",
  ["ctrl+backspace"]       = "autoinsert:delete-to-previous-word-start",
  ["ctrl+shift+backspace"] = "autoinsert:delete-to-start-of-line",
}

