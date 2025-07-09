-- mod-version:3
--
-- For dictionaries you can use the Hunspell .dic files available on:
-- https://github.com/titoBouzout/Dictionaries
--
local core = require "core"
local style = require "core.style"
local config = require "core.config"
local command = require "core.command"
local common = require "core.common"
local DocView = require "core.docview"
local Highlighter = require "core.doc.highlighter"
local Doc = require "core.doc"
local RootView = require "core.rootview"

local platform_dictionary_file
if PLATFORM == "Windows" then
  platform_dictionary_file = EXEDIR .. "/words.txt"
else
  platform_dictionary_file = "/usr/share/dict/words"
end

config.plugins.spellcheck = common.merge({
  enabled = true,
  files = { "%.txt$", "%.md$", "%.markdown$" },
  dictionary_file = platform_dictionary_file,
  check_comments = false
}, config.plugins.spellcheck)

local last_input_time = 0
local words, word_pattern = nil, "%a+"
local cursor_x, cursor_y = 0, 0
local forced_spellcheck = false
local user_dictionary = USERDIR .. PATHSEP .. "user_dictionary.txt"

local spell_cache = setmetatable({}, { __mode = "k" })
local pos_cache = setmetatable({}, { __mode = "k" })
local font_canary
local font_size_canary


local get_visible_cols_range = DocView.get_visible_cols_range
if not get_visible_cols_range then
  ---Get an estimated range of visible columns. It is an estimate because fonts
  ---and their fallbacks may not be monospaced or may differ in size.
  ---@param self core.docview
  ---@param line integer
  ---@param extra_cols integer Amount of columns to deduce on col1 and include on col2
  ---@return integer col1
  ---@return integer col2
  get_visible_cols_range = function(self, line, extra_cols)
    extra_cols = extra_cols or 100
    local gw = self:get_gutter_width()
    local line_x = self.position.x + gw
    local x = -self.scroll.x + self.position.x + gw

    local non_visible_x = common.clamp(line_x - x, 0, math.huge)
    local char_width = self:get_font():get_width("W")
    local non_visible_chars_left = math.floor(non_visible_x / char_width)
    local visible_chars_right = math.floor((self.size.x - gw) / char_width)
    local line_len = #self.doc.lines[line]

    if non_visible_chars_left > line_len then return 0, 0 end

    return
      math.max(1, non_visible_chars_left - extra_cols),
      math.min(line_len, non_visible_chars_left + visible_chars_right + extra_cols)
  end
end

local function reset_cache(fully)
  for highlighter in pairs(spell_cache) do
    if not fully then
      local cache = spell_cache[highlighter]
      for j=1, #cache do
        cache[j] = false
        pos_cache[highlighter][j] = -1
      end
    else
      spell_cache[highlighter] = nil
      pos_cache[highlighter] = nil
    end
  end
end

local dictionaries_loading = 0
local function load_dictionary()
  local dictionaries = {
    config.plugins.spellcheck.dictionary_file,
    user_dictionary
  }
  local dwords = {}
  for didx, dictionary in ipairs(dictionaries) do
    local file = io.open(dictionary, "r")
    if file then
      file:close()
      dwords[didx] = {}
      dictionaries_loading = dictionaries_loading + 1
      local idx = didx
      core.add_thread(function()
        local i = 0
        for line in io.lines(dictionary) do
          for word in line:ugmatch(word_pattern) do
            dwords[idx][word:ulower()] = true
            break
          end
          i = i + 1
          if i % 1000 == 0 then coroutine.yield() end
        end
        dictionaries_loading = dictionaries_loading - 1
        if dictionaries_loading == 0 then
          words = {}
          for widx, _ in ipairs(dwords) do
            for word, _ in pairs(dwords[widx]) do
              words[word] = true
            end
          end
          reset_cache(true)
          core.redraw = true
        end
        core.log_quiet(
          "Finished loading dictionary file: \"%s\"",
          dictionary
        )
      end)
    end
  end
end


local function matches_any(filename, ptns)
  for _, ptn in ipairs(ptns) do
    if filename:find(ptn) then return true end
  end
end


local function active_word(doc, line, tail)
  local l, c = doc:get_selection()
  return l == line and c == tail
     and doc == core.active_view.doc
     and system.get_time() - last_input_time < 0.5
end


local function compare_arrays(a, b)
  if b == a then return true end
  if not a or not b then return false end
  if #b ~= #a then return false end
  for i=1,#a do
    if b[i] ~= a[i] then return false end
  end
  return true
end


local function check_doc(doc, line)
  if
    not config.plugins.spellcheck.enabled
    or
    not words
    or
    (
      not matches_any(doc.filename or "", config.plugins.spellcheck.files)
      and
      not forced_spellcheck
      and
      (
        not line
        or
        (
          not config.plugins.spellcheck.check_comments
          or
          doc.highlighter:get_line(line).tokens[1] ~= "comment"
        )
      )
    )
  then
    return false
  end
  return true
end

local function reset_cache_line(self, line, n, splice)
  if check_doc(self.doc) or spell_cache[self] then
    if not spell_cache[self] then
      spell_cache[self] = {}
      pos_cache[self] = {}
    end
    if splice then
      common.splice(spell_cache[self], line, n)
      common.splice(pos_cache[self], line, n)
    end
    if n > 0 then
      for i=line, #self.doc.lines do
        if spell_cache[self][i] then spell_cache[self][i] = false pos_cache[self][i] = -1 end
      end
    end
  end
end

--
-- Functions overriding
--
-- Reset cache of current and subsequent lines on the file
local prev_insert_notify = Highlighter.insert_notify
function Highlighter:insert_notify(line, n, ...)
  prev_insert_notify(self, line, n, ...)
  reset_cache_line(self, line, n)
end


-- Reset cache of current and subsequent lines on the file
local prev_remove_notify = Highlighter.remove_notify
function Highlighter:remove_notify(line, n, ...)
  prev_remove_notify(self, line, n, ...)
  reset_cache_line(self, line, n, true)
end


-- Remove changed lines from the cache
local prev_tokenize_line = Highlighter.tokenize_line
function Highlighter:tokenize_line(idx, state, ...)
  local res = prev_tokenize_line(self, idx, state, ...)
  if
    check_doc(self.doc)
    or
    (
      config.plugins.spellcheck.check_comments
      and
      spell_cache[self] and spell_cache[self][idx]
    )
  then
    if not spell_cache[self] then
      spell_cache[self] = {}
      pos_cache[self] = {}
    end
    spell_cache[self][idx] = false
    pos_cache[self][idx] = -1
  end
  return res
end


local root_view_on_mouse_pressed = RootView.on_mouse_pressed
function RootView:on_mouse_pressed(button, x, y, clicks)
  local res = root_view_on_mouse_pressed(self, button, x, y, clicks)
  if button == "right" then
    cursor_x, cursor_y = x, y
  end
  return res
end


local text_input = Doc.text_input
function Doc:text_input(...)
  text_input(self, ...)
  last_input_time = system.get_time()
end


local doc_on_close = Doc.on_close
function Doc:on_close()
  doc_on_close(self)
  if spell_cache[self.highlighter] then
    spell_cache[self.highlighter] = nil
    pos_cache[self.highlighter] = nil
  end
end


local draw_line_text = DocView.draw_line_text
function DocView:draw_line_text(idx, x, y)
  local lh = draw_line_text(self, idx, x, y)

  if not check_doc(self.doc, idx) then return lh end

  if not spell_cache[self.doc.highlighter] then
    spell_cache[self.doc.highlighter] = {}
    pos_cache[self.doc.highlighter] = {}
  end

  if font_canary ~= style.code_font
    or font_size_canary ~= style.code_font:get_size()
    or not compare_arrays(self.wrapped_lines, self.old_wrapped_lines)
  then
    font_canary = style.code_font
    font_size_canary = style.code_font:get_size()
    self.old_wrapped_lines = self.wrapped_lines
    reset_cache()
  end
  if
    dictionaries_loading < 1 and (
      not spell_cache[self.doc.highlighter][idx]
      or pos_cache[self.doc.highlighter][idx] ~= x
    )
  then
    pos_cache[self.doc.highlighter][idx] = x

    local calculated = {}
    local vs, ve = get_visible_cols_range(self, idx, 50)
    local s, e, us, ue = 0, 0, 0, 0
    local text = self.doc.lines[idx]:usub(vs, ve)
    vs = utf8extra.charpos(self.doc.lines[idx], vs)
    ve = utf8extra.charpos(self.doc.lines[idx], ve)

    while true do
      us, ue = text:ufind(word_pattern, ue + 1)
      if not us then break end
      local word = text:usub(us, ue):ulower()
      s = utf8extra.charpos(text, us)
      e = utf8extra.charpos(text, ue)
      if not words[word] and not active_word(self.doc, idx, vs + e) then
        x, y = self:get_line_screen_position(idx, vs + s - 1)
        table.insert(calculated,  x - self.position.x - self:get_gutter_width() + self.scroll.x)
        table.insert(calculated, y - self.position.y + self.scroll.y)
        x, y = self:get_line_screen_position(idx, vs + e)
        table.insert(calculated, x - self.position.x - self:get_gutter_width() + self.scroll.x)
        table.insert(calculated, y - self.position.y + self.scroll.y)
      end
    end

    spell_cache[self.doc.highlighter][idx] = calculated
  end

  if spell_cache[self.doc.highlighter][idx] then
    local color = style.spellcheck_error or style.syntax.keyword2
    local h = math.ceil(1 * SCALE)
    local slh = self:get_line_height() - h
    local pos = spell_cache[self.doc.highlighter][idx]
    local gw = self:get_gutter_width()
    for i=1,#pos,4 do
      local x1, y1, x2, y2 = pos[i], pos[i+1], pos[i+2], pos[i+3]
      renderer.draw_rect(
        (self.position.x + gw + x1) - self.scroll.x,
        (self.position.y + y1 + slh) - self.scroll.y,
        x2 - x1,
        h,
        color
      )
    end
  end
  return lh
end

--
-- The config specification used by the settings gui
--
config.plugins.spellcheck.config_spec = {
  name = "Spell Check",
  {
    label = "Enabled",
    description = "Disable or enable spell checking.",
    path = "enabled",
    type = "toggle",
    default = true,
    on_apply = function()
      reset_cache(true)
    end
  },
  {
    label = "Files",
    description = "List of Lua patterns matching files to spell check.",
    path = "files",
    type = "list_strings",
    default = { "%.txt$", "%.md$", "%.markdown$" }
  },
  {
    label = "Check Comments",
    description = "Check spelling errors on line comments of any file type (experimental).",
    path = "check_comments",
    type = "toggle",
    default = false,
    on_apply = function()
      reset_cache(true)
    end
  },
  {
    label = "Dictionary File",
    description = "Path to a text file that contains a list of dictionary words.",
    path = "dictionary_file",
    type = "file",
    exists = true,
    default = platform_dictionary_file,
    on_apply = function()
      core.add_thread(function()
        load_dictionary()
      end)
    end
  }
}

local function get_valid_utf8_range(line, col, padding)
  local c = line:sub(1, col):ulen(nil, nil, true)
  local s, e = math.max(1, c - padding), math.min(line:ulen(), c + padding)

  local bs = utf8extra.charpos(line, s)
  local be = utf8extra.charpos(line, e)

  while not bs do s = s - 1 bs = utf8extra.charpos(line, s) end
  while not be do e = e + 1 be = utf8extra.charpos(line, e) end

  return bs, be, line:sub(bs, be)
end

--
-- Register Commands and ContextMenu entries
--
local function get_current_word(from_cursor)
  local doc = core.active_view.doc
  local l, c = 0, 0
  if not from_cursor or (cursor_x == 0 and cursor_y == 0) then
    l, c = doc:get_selection()
  else
    l, c = core.active_view:resolve_screen_position(cursor_x, cursor_y)
  end
  local s, e, us, ue = 0, 0, 0, 0
  local ss, se, text = get_valid_utf8_range(doc.lines[l], c, 50)
  while true do
    us, ue = text:ufind(word_pattern, ue + 1)
    if us then
      s = utf8extra.charpos(text, us)
      e = utf8extra.charpos(text, ue)
      local as, ae = ss + s - 1, ss + e
      if c >= as and c <= ae then
        return text:usub(us, ue):ulower(), as, ae - 1
      end
    else
      break
    end
  end
end


local function compare_words(word1, word2)
  local res = 0
  local len1, len2 = word1:ulen(), word2:ulen()
  local wi1, wi2 = 1, 1
  local max_len = math.max(len1, len2)
  while wi1 <= len1 and wi2 <= len2 do
    local b1, b2 = word1:ubyte(wi1), word2:ubyte(wi2)
    if b1 == b2 then
      wi1 = wi1 + 1
      wi2 = wi2 + 1
    else
      local matched = false
      -- Handle insertion/deletion
      if wi1+1 <= len1 and word1:ubyte(wi1+1) == b2 then
        wi1 = wi1 + 1
        matched = true
      elseif wi2+1 <= len2 and word2:ubyte(wi2+1) == b1 then
        wi2 = wi2 + 1
        matched = true
      -- Handle transposition (swap of adjacent characters)
      elseif
        wi1+1 <= len1 and wi2+1 <= len2 and
        word1:ubyte(wi1) == word2:ubyte(wi2+1) and
        word1:ubyte(wi1+1) == word2:ubyte(wi2)
      then
        wi1 = wi1 + 2
        wi2 = wi2 + 2
        matched = true
      end
      if not matched then
        res = res + 1
        wi1 = wi1 + 1
        wi2 = wi2 + 1
      end
    end
  end
  -- prioritize words that start the same
  local starts_same = false
  for i=1, len1 do
    if word1:ubyte(i) == word2:ubyte(i) then
      res = res - 1
      starts_same = true
    else
      if i == 1 then res = res + 1 end
      break
    end
  end
  -- prioritize words that end the same if starts the same
  if starts_same then
    local eidx = 0
    for i=len1, 1 do
      if word1:ubyte(i) == word2:ubyte(len2-eidx) then
        res = res - 1
      else
        if eidx == 0 then res = res + 1 end
        break
      end
      eidx = eidx + 1
    end
  end
  -- Add penalty for leftover characters
  res = res + (len1 - wi1 + 1) + (len2 - wi2 + 1)
  return res
end


local function add_to_dictionary(from_cursor)
  local word = get_current_word(from_cursor)
  if words and words[word] then
    core.error("\"%s\" already exists in the dictionary", word)
    return
  end
  if word then
    local fp = io.open(user_dictionary, "a+")
    if fp then
      fp:write(word .. "\n")
      fp:close()
      words[word] = true
      reset_cache(true)
      core.log("Added \"%s\" to user dictionary", word)
    end
  end
  cursor_x, cursor_y = 0, 0
end

local function spellcheck_replace(dv, from_cursor)
  local word, s, e = get_current_word(from_cursor)

  -- find suggestions
  local suggestions = {}
  local word_len = word:ulen()
  for w in pairs(words or {}) do
    if math.abs(w:ulen() - word_len) <= 2 then
      local diff = compare_words(word, w)
      if (word_len <= 3 and diff < 2) or (word_len > 3 and diff < 2) then
        table.insert(suggestions, { diff = diff, text = w })
      end
    end
  end
  if #suggestions == 0 then
    core.error("Could not find any suggestions for \"%s\"", word)
    return
  end

  -- sort suggestions table and convert to properly-capitalized text
  table.sort(suggestions, function(a, b) return a.diff < b.diff end)
  local doc = dv.doc
  local line = 0
  if not from_cursor then
    line = doc:get_selection()
  else
    line = dv:resolve_screen_position(cursor_x, cursor_y)
  end
  local has_upper = doc.lines[line]:sub(s, s):match("[A-Z]")
  for k, v in pairs(suggestions) do
    if has_upper then
      v.text = v.text:gsub("^.", string.upper)
    end
    suggestions[k] = v.text
  end

  -- select word and init replacement selector
  local label = string.format("Replace \"%s\" With", word)
  doc:set_selection(line, e + 1, line, s)
  core.command_view:enter(label, {
    submit = function(text, item)
      text = item and item.text or text
      doc:replace(function() return text end)
    end,
    suggest = function(text)
      local t = {}
      for _, w in ipairs(suggestions) do
        if w:ulower():ufind(text:ulower(), 1, true) then
          table.insert(t, w)
        end
      end
      return t
    end
  })

  cursor_x, cursor_y = 0, 0
end

command.add("core.docview", {
  ["spell-check:toggle"] = function()
    config.plugins.spellcheck.enabled = not config.plugins.spellcheck.enabled
  end,
  ["spell-check:toggle-forced-checking"] = function()
    forced_spellcheck = not forced_spellcheck
  end,
  ["spell-check:add-to-dictionary"] = function()
    add_to_dictionary()
  end,
  ["spell-check:add-to-dictionary-from-cursor"] = function()
    add_to_dictionary(true)
  end,
  ["spell-check:replace"] = function(dv)
    spellcheck_replace(dv)
  end,
  ["spell-check:replace-on-cursor"] = function(dv)
    spellcheck_replace(dv, true)
  end
})

local contextmenu = require "plugins.contextmenu"
contextmenu:register("core.docview", {
  contextmenu.DIVIDER,
  { text = "View Suggestions",  command = "spell-check:replace-on-cursor" },
  { text = "Add to Dictionary", command = "spell-check:add-to-dictionary-from-cursor" }
})

--
-- Initialize Dictionary on Startup
--
load_dictionary()
