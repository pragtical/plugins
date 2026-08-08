-- mod-version:3
--------------------------------------------------------------------------------
-- Plugin: Occurrences Highlight & Scrollbar Markers
-- Description: VS Code-style occurrences highlight and scrollbar track indicators
--------------------------------------------------------------------------------

local core = require "core"
local config = require "core.config"
local style = require "core.style"
local command = require "core.command"
local DocView = require "core.docview"

-- Safe Plugin Configurations
config.plugins.occurrences = config.plugins.occurrences or {}
local opts = config.plugins.occurrences

if opts.enabled == nil then opts.enabled = true end
if opts.highlight_word_under_caret == nil then opts.highlight_word_under_caret = true end
if opts.match_whole_word == nil then opts.match_whole_word = true end
if opts.case_sensitive == nil then opts.case_sensitive = true end
if opts.min_length == nil then opts.min_length = 2 end
if opts.show_scrollbar_markers == nil then opts.show_scrollbar_markers = true end
-- Text highlight color (RGBA translucent blue)
if opts.color == nil then opts.color = { 80, 160, 240, 70 } end
-- Scrollbar marker color (RGBA bright amber/orange, VS Code style)
if opts.marker_color == nil then opts.marker_color = { 255, 170, 40, 230 } end

-- Calculate character pixel offset using Font:get_width
local function get_column_x(docview, line, col)
  local font = docview:get_font()
  local line_text = (docview.doc and docview.doc.lines[line]) or ""
  if font and font.get_width then
    return font:get_width(line_text:sub(1, col - 1))
  end
  return 0
end

-- Extract word under caret
local function get_word_at_caret(doc, line, col)
  local line_text = doc.lines[line]
  if not line_text then return nil end

  line_text = line_text:gsub("\r?\n$", "")

  if col > #line_text or not line_text:sub(col, col):match("[%w_]") then
    if col > 1 and line_text:sub(col - 1, col - 1):match("[%w_]") then
      col = col - 1
    else
      return nil
    end
  end

  local s = col
  while s > 1 and line_text:sub(s - 1, s - 1):match("[%w_]") do
    s = s - 1
  end

  local e = col
  while e <= #line_text and line_text:sub(e, e):match("[%w_]") do
    e = e + 1
  end

  if s < e then
    return line_text:sub(s, e - 1)
  end
  return nil
end

-- Determine target word or selection
local function get_target_string(doc)
  local line1, col1, line2, col2 = doc:get_selection()
  if line1 > line2 or (line1 == line2 and col1 > col2) then
    line1, col1, line2, col2 = line2, col2, line1, col1
  end

  local is_selection = (line1 ~= line2) or (col1 ~= col2)

  if is_selection then
    if line1 == line2 then
      local line_text = doc.lines[line1]
      if line_text then
        return line_text:sub(col1, col2 - 1)
      end
    end
  elseif opts.highlight_word_under_caret then
    return get_word_at_caret(doc, line1, col1)
  end

  return nil
end

-- Search entire file for occurrence locations
local function search_occurrences(doc, target)
  if not target or #target < opts.min_length then return nil end
  if not target:match("[%w_]") then return nil end

  local is_case = opts.case_sensitive
  local is_whole = opts.match_whole_word
  local needle = is_case and target or target:lower()
  local results = {}

  for i, line_text in ipairs(doc.lines) do
    local haystack = is_case and line_text or line_text:lower()
    local start_pos = 1

    while start_pos <= #haystack do
      local s, e = haystack:find(needle, start_pos, true)
      if not s then break end

      local valid = true
      if is_whole then
        local prev_char = s > 1 and line_text:sub(s - 1, s - 1) or ""
        local next_char = e < #line_text and line_text:sub(e + 1, e + 1) or ""
        if prev_char:match("[%w_]") or next_char:match("[%w_]") then
          valid = false
        end
      end

      if valid then
        results[i] = results[i] or {}
        table.insert(results[i], { col1 = s, col2 = e + 1 })
      end

      start_pos = s + 1
    end
  end

  return results
end

-- Cache search results per render frame to keep rendering ultra-fast
local function get_occurrences_cached(dv)
  if not opts.enabled or not dv.doc then return nil end

  local doc = dv.doc
  local line1, col1, line2, col2 = doc:get_selection()
  local change_id = doc.get_change_id and doc:get_change_id() or #doc.lines

  if dv.occurrences_cache
     and dv.occurrences_cache.doc == doc
     and dv.occurrences_cache.change_id == change_id
     and dv.occurrences_cache.line1 == line1
     and dv.occurrences_cache.col1 == col1
     and dv.occurrences_cache.line2 == line2
     and dv.occurrences_cache.col2 == col2 then
    return dv.occurrences_cache.results
  end

  local target = get_target_string(doc)
  local results = search_occurrences(doc, target)

  dv.occurrences_cache = {
    doc = doc,
    change_id = change_id,
    line1 = line1,
    col1 = col1,
    line2 = line2,
    col2 = col2,
    results = results
  }

  return results
end

-- 1. Draw text inline highlights
local draw_line_body = DocView.draw_line_body

function DocView:draw_line_body(line, x, y)
  if draw_line_body then
    draw_line_body(self, line, x, y)
  end

  core.try(function()
    local matches = get_occurrences_cached(self)
    if matches and matches[line] then
      local lh = self:get_line_height()

      for _, match in ipairs(matches[line]) do
        local x1 = x + get_column_x(self, line, match.col1)
        local x2 = x + get_column_x(self, line, match.col2)
        local w = x2 - x1

        if w > 0 then
          renderer.draw_rect(x1, y, w, lh, opts.color)
        end
      end
    end
  end)
end

-- 2. Draw scrollbar indicators/markers on the scrollbar track
local draw = DocView.draw

function DocView:draw()
  if draw then
    draw(self)
  end

  core.try(function()
    if not opts.enabled or not opts.show_scrollbar_markers or not self.doc then return end

    local matches = get_occurrences_cached(self)
    if not matches or next(matches) == nil then return end

    local total_lines = #self.doc.lines
    if total_lines <= 0 then return end

    local lh = self:get_line_height()
    local total_h = self.get_scrollable_size and self:get_scrollable_size() or (total_lines * lh)
    if total_h <= 0 then total_h = total_lines * lh end

    local view_h = self.size.y
    local view_y = self.position.y
    local sb_w = (style and style.scrollbar_size) or 10
    local sb_x = self.position.x + self.size.x - sb_w
    local marker_h = 3
    local marker_color = opts.marker_color or { 255, 170, 40, 230 }

    for line_num, _ in pairs(matches) do
      local line_y = (line_num - 1) * lh
      local ratio = line_y / total_h
      local my = view_y + math.floor(ratio * (view_h - marker_h))

      renderer.draw_rect(sb_x, my, sb_w, marker_h, marker_color)
    end
  end)
end

-- Register command palette options
command.add("core.docview", {
  ["occurrences:toggle"] = function()
    opts.enabled = not opts.enabled
  end,
  ["occurrences:toggle-markers"] = function()
    opts.show_scrollbar_markers = not opts.show_scrollbar_markers
  end
})

-- core.log("[Occurrences] Plugin with Scrollbar Markers loaded successfully.")
