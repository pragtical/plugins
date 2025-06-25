-- mod-version:3.1
--
-- Original Code:
-- https://github.com/drmargarido/TodoTreeView
--
-- Copyright: Daniel Margarido <drmargarido@gmail.com>
-- Performance Improvements: Jefferson Gonzalez <jgmdev@gmail.com>
-- License: MIT
--
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local style = require "core.style"
local View = require "core.view"
local Doc = require "core.doc"
local CommandView = require "core.commandview"

---@class config.plugins.todotreeview
---List of tags to search
---@field todo_tags table<integer, string>
---Colors manually assigned to the different tag types
---@field tag_colors table
---Allow customization of todo file color.
---@field todo_file_color table
---List of paths or files to be ignored
---@field ignore_paths table<integer, string>
---Tells if the plugin should start with the nodes expanded
---@field todo_expanded boolean
---The mode used to group the found todos
--- 'tag' mode can be used to group the todos by tags
--- 'file' mode can be used to group the todos by files
--- 'file_tag' mode can be used to group the todos by files and then by tags inside the files
---@field todo_mode "tag" | "file" | "file_tag"
---Default size of the todotreeview pane
---@field treeview_size number
---Used in file mode when the tag and the text are on the same line.
---@field todo_separator string
---Text displayed when the note is empty.
---@field todo_default_text string

---@type plugins.todotreeview
local view

---@type config.plugins.todotreeview
config.plugins.todotreeview = common.merge({
  todo_tags = {"TODO", "BUG", "FIX", "FIXME", "IMPROVEMENT"},
  tag_colors = {
    TODO        = {tag=style.text, tag_hover=style.accent, text=style.text, text_hover=style.accent},
    BUG         = {tag=style.text, tag_hover=style.accent, text=style.text, text_hover=style.accent},
    FIX         = {tag=style.text, tag_hover=style.accent, text=style.text, text_hover=style.accent},
    FIXME       = {tag=style.text, tag_hover=style.accent, text=style.text, text_hover=style.accent},
    IMPROVEMENT = {tag=style.text, tag_hover=style.accent, text=style.text, text_hover=style.accent},
  },
  enable_custom_file_color = false,
  todo_file_color = {
    name=style.text,
    hover=style.accent
  },
  ignore_paths = {},
  todo_expanded = true,
  todo_mode = "tag",
  treeview_size = math.floor(200 * SCALE),
  todo_separator = " - ",
  todo_default_text = "blank",
  config_spec = {
    name = "ToDo Tree View",
    {
      label = "Tags",
      description = "List of todo tags to search for.",
      path = "todo_tags",
      type = "list_strings",
      default = { "TODO", "BUG", "FIX", "FIXME", "IMPROVEMENT" }
    },
    {
      label = "Enable Custom File Colors",
      description = "When enabled uses the custom file name colors given below.",
      path = "enable_custom_file_color",
      type = "toggle",
      default = false
    },
    {
      label = "Filename Color",
      description = "Custom color for file names.",
      path = "todo_file_color.name",
      type = "color",
      default = table.pack(table.unpack(style.text)),
    },
    {
      label = "Filename Hover Color",
      description = "Custom color for file names on hover.",
      path = "todo_file_color.hover",
      type = "color",
      default = table.pack(table.unpack(style.accent)),
    },
    {
      label = "Ignore Path List",
      description = "Paths or files to be ignored, lua patterns can be used.",
      path = "ignore_paths",
      type = "list_strings"
    },
    {
      label = "Items Expanded",
      description = "Tells if todo items should be expanded by default.",
      path = "todo_expanded",
      type = "toggle",
      default = false
    },
    {
      label = "Mode",
      description = "The mode used to group the found todos.",
      path = "todo_mode",
      type = "selection",
      default = "tag",
      values = {
        {"Tag", "tag"},
        {"File", "file"},
        {"File Tag", "file_tag"}
      }
    },
    {
      label = "Pane Size",
      description = "Default size of the todotreeview pane.",
      path = "treeview_size",
      type = "number",
      default = math.floor(200 * SCALE),
      min =  math.floor(200 * SCALE),
      get_value = function(value)
        return math.floor(value / SCALE)
      end,
      set_value = function(value)
        return math.floor(value * SCALE)
      end,
      on_apply = function(value)
        if view.visible then
          view:set_target_size("x", value)
        end
      end
    },
    {
      label = "Hide on Startup",
      description = "Set the default visibility of the todo list.",
      path = "visible",
      type = "toggle",
      default = false,
      on_apply = function(value)
        view.visible = not value
      end
    },
    {
      label = "Todo Separator",
      description = "Only used in file mode when the tag and the text are on the same line.",
      path = "todo_separator",
      type = "string",
      default = "blank"
    },
    {
      label = "Todo Default Text",
      description = "Text displayed when the note is empty.",
      path = "todo_default_text",
      type = "string",
      default = "blank"
    }
  }
}, config.plugins.todotreeview)

---@class plugins.todotreeview:core.view
---@field super core.view
local TodoTreeView = View:extend()

function TodoTreeView:new()
  TodoTreeView.super.new(self)
  self.scrollable = true
  self.focusable = false
  self.visible = true
  self.cache = {}
  self.init_size = true
  self.co_id = 0
  self.current_mode = config.plugins.todotreeview.todo_mode
  self.current_project_dir = ""
  self.scroll_width = 0
  self.scroll_height = 0
  self.scrollable = true
  self.focus_index = 0
  self.filter = ""

  -- Items are generated from cache according to the mode
  self.items = {}
end

local function is_file_ignored(filename)
  for _, path in ipairs(config.plugins.todotreeview.ignore_paths) do
    local s, _ = filename:find(path)
    if s then
      return true
    end
  end

  return false
end

---Current project files iterator.
---@return fun(): system.fileinfo
local function get_project_files()
  local start_time = system.get_time()
  core.log_quiet("TODO View: Started Scanning")
  return coroutine.wrap(function()
    local root = core.root_project().path
    local directories = {""}
    local file_size_limit = config.file_size_limit * 1e6
    local ignore_files = core.get_ignore_file_rules()

    while #directories > 0 do
      for didx, directory in ipairs(directories) do
        local dir_path = ""

        if directory ~= "" then
          dir_path = root .. PATHSEP .. directory
          directory = directory .. PATHSEP
        else
          dir_path = root
        end

        local files = system.list_dir(dir_path)

        if files then
          for _, file in ipairs(files) do
            local info = system.get_file_info(
              dir_path .. PATHSEP .. file
            )

            if
              info and info.size <= file_size_limit and not common.match_ignore_rule(
                directory .. file, info, ignore_files
              )
            then
              if info.type == "dir" then
                table.insert(directories, directory .. file)
              else
                info.filename = common.relative_path(
                  core.root_project().path,
                  dir_path .. PATHSEP .. file
                )
                coroutine.yield(info)
              end
            end
          end
        end
        table.remove(directories, didx)
        break
      end
    end
    core.log_quiet(
      "TODO View: Finished Scanning in %s seconds",
      system.get_time() - start_time
    )
  end)
end

function TodoTreeView:refresh_cache()
  self.current_project_dir = core.root_project().path
  self.cache = {}

  local items = {}
  local old_items = self.items
  local prev_mode = self.current_mode
  local current_mode = config.plugins.todotreeview.todo_mode

  if
    self.updating_cache
    and
    core.threads[self.co_id] and core.threads[self.co_id].todotreeview
  then
    core.threads[self.co_id].cr = coroutine.create(function() end)
  end

  self.updating_cache = true

  self.co_id = core.add_thread(function()
    self.items = items
    self.current_mode = current_mode
    local count = 0
    for item in get_project_files() do
      local ignored = is_file_ignored(item.filename)
      if not ignored and item.type == "file" then
        count = count + 1
        local cached = self:get_cached(item.filename)

        if cached then
          if config.plugins.todotreeview.todo_mode == "file" then
            items[cached.filename] = cached
          elseif config.plugins.todotreeview.todo_mode == "file_tag" then
            local file_t = {}
            file_t.expanded = config.plugins.todotreeview.todo_expanded
            file_t.type = "file"
            file_t.tags = {}
            file_t.todos = {}
            file_t.filename = cached.filename
            file_t.abs_filename = cached.abs_filename
            items[cached.filename] = file_t
            for _, todo in ipairs(cached.todos) do
              local tag = todo.tag
              if not file_t.tags[tag] then
                local tag_t = {}
                tag_t.expanded = config.plugins.todotreeview.todo_expanded
                tag_t.type = "group"
                tag_t.todos = {}
                tag_t.tag = tag
                file_t.tags[tag] = tag_t
              end

              table.insert(file_t.tags[tag].todos, todo)
            end
          else
            for _, todo in ipairs(cached.todos) do
              local tag = todo.tag
              if not items[tag] then
                local t = {}
                t.expanded = config.plugins.todotreeview.todo_expanded
                t.type = "group"
                t.todos = {}
                t.tag = tag
                items[tag] = t
              end

              table.insert(items[tag].todos, todo)
            end
          end
        end
        if count % 100 == 0 then coroutine.yield() end
      end
    end

    -- Copy expanded from old items
    if
      current_mode == prev_mode
      or
      (prev_mode:match("file") and current_mode:match("file"))
    then
      for tag, data in pairs(old_items) do
        if items[tag] then
          items[tag].expanded = data.expanded
        end
      end
    end

    self.current_mode = current_mode
    self.updating_cache = false

    if self.visible then
      core.redraw = true
    end
  end, self)

  core.threads[self.co_id].todotreeview = true
end


local function find_file_todos(t, filename)
  local fp = io.open(filename)
  if not fp then return t end
  local n = 1
  for line in fp:lines() do
    for _, todo_tag in ipairs(config.plugins.todotreeview.todo_tags) do
      -- Add spaces at the start and end of line so the pattern will pick
      -- tags at the start and at the end of lines
      local extended_line = " "..line.." "
      local match_str = "[^a-zA-Z_\"'`]"..todo_tag.."[^\"'a-zA-Z_`]+"
      local s, e = extended_line:find(match_str)
      if s then
        local d = {}
        d.type = "todo"
        d.tag = todo_tag
        d.filename = filename
        d.text = extended_line:sub(e+1)
        if d.text == "" then
          d.text = config.plugins.todotreeview.todo_default_text
        end
        d.line = n
        d.col = s
        table.insert(t, d)
      end
      core.redraw = true
    end
    if n % 100 == 0 then coroutine.yield() end
    n = n + 1
    core.redraw = true
  end
  fp:close()
end


function TodoTreeView:get_cached(filename)
  local t = self.cache[filename]
  if not t then
    t = {}
    t.expanded = config.plugins.todotreeview.todo_expanded
    t.filename = filename
    t.abs_filename = core.project_absolute_path(filename)
    t.type = "file"
    t.todos = {}
    t.tags = {}
    find_file_todos(t.todos, t.abs_filename)
    if #t.todos > 0 then
      self.cache[t.filename] = t
    end
  end
  return self.cache[filename]
end


function TodoTreeView:get_name()
  return "Todo Tree"
end

function TodoTreeView:set_target_size(axis, value)
  if axis == "x" then
    config.plugins.todotreeview.treeview_size = value
    return true
  end
end

function TodoTreeView:get_item_height()
  return style.font:get_height() + style.padding.y
end


function TodoTreeView:update_file(filename)
  self.cache[filename] = nil

  local cached = self:get_cached(filename)

  if config.plugins.todotreeview.todo_mode == "file" then
    local old = self.items[filename]
    self.items[filename] = cached
    if old and cached then
      cached.expanded = old.expanded
    end
  elseif config.plugins.todotreeview.todo_mode == "file_tag" then
    if cached then
      local old = self.items[filename]
      local file_t = {}
      file_t.expanded = old and old.expanded
      file_t.type = "file"
      file_t.tags = {}
      file_t.todos = {}
      file_t.filename = filename
      file_t.abs_filename = cached.abs_filename
      self.items[filename] = file_t
      for _, todo in ipairs(cached.todos) do
        local tag = todo.tag
        if not file_t.tags[tag] then
          local tag_t = {}
          tag_t.expanded = (old and old.tags[tag]) and old.tags[tag].expanded
          tag_t.type = "group"
          tag_t.todos = {}
          tag_t.tag = tag
          file_t.tags[tag] = tag_t
        end

        table.insert(file_t.tags[tag].todos, todo)
      end
    else
      self.items[filename] = nil
    end
  else
    local expanded = {}
    local abs_filename = core.project_absolute_path(filename)

    for tag, item in pairs(self.items) do
      local deleted = 0
      expanded[tag] = item.expanded
      for pos=1, #item.todos do
        local todo = item.todos[pos-deleted]
        if todo.filename == abs_filename then
          table.remove(self.items[tag].todos, pos-deleted)
          deleted = deleted + 1
        end
      end
      if #self.items[tag].todos <= 0 then
        self.items[tag] = nil
      end
    end

    if cached then
      for _, todo in ipairs(cached.todos) do
        local tag = todo.tag
        if not self.items[tag] then
          self.items[tag] = {
            expanded = expanded[tag],
            type = "group",
            todos = {},
            tag = tag
          }
        end

        table.insert(self.items[tag].todos, todo)
      end
    end
  end
end

function TodoTreeView:each_item()
  return coroutine.wrap(function()
    local ox, oy = self:get_content_offset()
    local y = oy + style.padding.y
    local w = self.size.x
    local h = self:get_item_height()

    for _, item in pairs(self.items) do
      if #item.todos > 0 then
        coroutine.yield(item, ox, y, w, h)
        y = y + h

        for _, todo in ipairs(item.todos) do
          if item.expanded then
            local in_todo = string.find(todo.text:lower(), self.filter:lower())
            if #self.filter == 0 or in_todo then
              coroutine.yield(todo, ox, y, w, h)
              y = y + h
            end
          end
        end
      end

      if item.tags then
        local first_tag = true
        for _, tag in pairs(item.tags) do
          if first_tag then
            coroutine.yield(item, ox, y, w, h)
            y = y + h
            first_tag = false
          end
          if item.expanded then
            coroutine.yield(tag, ox, y, w, h)
            y = y + h

            for _, todo in ipairs(tag.todos) do
              if item.expanded and tag.expanded then
                local in_todo = string.find(todo.text:lower(), self.filter:lower())
                if #self.filter == 0 or in_todo then
                  coroutine.yield(todo, ox, y, w, h)
                  y = y + h
                end
              end
            end
          end
        end
      end

    end
  end)
end


function TodoTreeView:on_mouse_moved(px, py, ...)
  if not self.visible then return end
  if TodoTreeView.super.on_mouse_moved(self, px, py, ...) then
    -- mouse movement handled by the View (scrollbar)
    self.hovered_item = nil
    return true
  end
  self.hovered_item = nil
  for item, x,y,w,h in self:each_item() do
    if px >= self.position.x and py > y and px <= self.position.x + self.size.x and py <= y + h then
      self.hovered_item = item
      break
    end
  end
end

function TodoTreeView:goto_hovered_item()
  if not self.hovered_item then
    return
  end

  if self.hovered_item.type == "group" or self.hovered_item.type == "file" then
    return
  end

  core.try(function()
    local i = self.hovered_item
    local dv = core.root_view:open_doc(core.open_doc(i.filename))
    core.root_view.root_node:update_layout()
    dv.doc:set_selection(i.line, i.col)
    dv:scroll_to_line(i.line, false, true)
  end)
end

function TodoTreeView:on_mouse_pressed(button, x, y, clicks)
  if not self.visible then return end
  if TodoTreeView.super.on_mouse_pressed(self, button, x, y, clicks) then
    -- mouse pressed handled by the View (scrollbar)
    return true
  end
  if not self.hovered_item then
    return
  elseif self.hovered_item.type == "file"
    or self.hovered_item.type == "group" then
    self.hovered_item.expanded = not self.hovered_item.expanded
  else
    self:goto_hovered_item()
  end
end


function TodoTreeView:update()
  if not self.visible and self.size.x == 0 then return end
  self.scroll.to.y = math.max(0, self.scroll.to.y)

  -- update width
  local dest = self.visible and config.plugins.todotreeview.treeview_size or 0
  if self.init_size then
    self.size.x = dest
    self.init_size = false
  else
    self:move_towards(self.size, "x", dest)
  end

  TodoTreeView.super.update(self)
end


function TodoTreeView:draw()
  if not self.visible and self.size.x == 0 then return end
  self:draw_background(style.background2)

  --local h = self:get_item_height()
  local icon_width = style.icon_font:get_width("D")
  local spacing = style.font:get_width(" ") * 2
  local root_depth = 0

  local total_items = 0
  local new_scroll_width = 0
  local ox = math.abs(self:get_content_offset())
  for item, x,y,w,h in self:each_item() do
    total_items = total_items + 1
    local text_color = style.text
    local tag_color = style.text
    local file_color = config.plugins.todotreeview.enable_custom_file_color and config.plugins.todotreeview.todo_file_color.name or style.text
    if config.plugins.todotreeview.tag_colors[item.tag] then
      text_color = config.plugins.todotreeview.tag_colors[item.tag].text or style.text
      tag_color = config.plugins.todotreeview.tag_colors[item.tag].tag or style.text
    end

    -- hovered item background
    if item == self.hovered_item then
      renderer.draw_rect(self.position.x, y, self.size.y, h, style.line_highlight)
      text_color = style.accent
      tag_color = style.accent
      file_color = config.plugins.todotreeview.enable_custom_file_color and config.plugins.todotreeview.todo_file_color.hover or style.accent
      if config.plugins.todotreeview.tag_colors[item.tag] then
        text_color = config.plugins.todotreeview.tag_colors[item.tag].text_hover or style.accent
        tag_color = config.plugins.todotreeview.tag_colors[item.tag].tag_hover or style.accent
      end
    end

    -- icons
    local item_depth = 0
    x = x + (item_depth - root_depth) * style.padding.x + style.padding.x
    if item.type == "file" then
      local icon1 = item.expanded and "-" or "+"
      common.draw_text(style.icon_font, file_color, icon1, nil, x, y, 0, h)
      x = x + style.padding.x
      common.draw_text(style.icon_font, file_color, "f", nil, x, y, 0, h)
      x = x + icon_width
    elseif item.type == "group" then
      if self.current_mode == "file_tag" then
        x = x + style.padding.x * 0.75
      end

      local icon1 = item.expanded and "-" or "+"
      common.draw_text(style.icon_font, tag_color, icon1, nil, x, y, 0, h)
      x = x + icon_width / 2
    else
      if self.current_mode == "tag" then
        x = x + style.padding.x
      else
        x = x + style.padding.x * 1.5
      end
      common.draw_text(style.icon_font, text_color, "i", nil, x, y, 0, h)
      x = x + icon_width
    end

    -- text
    x = x + spacing
    local sw = 0
    if item.type == "file" then
      sw = common.draw_text(style.font, file_color, item.filename, nil, x, y, 0, h)
    elseif item.type == "group" then
      sw = common.draw_text(style.font, tag_color, item.tag, nil, x, y, 0, h)
    else
      if self.current_mode == "file" then
        common.draw_text(style.font, tag_color, item.tag, nil, x, y, 0, h)
        x = x + style.font:get_width(item.tag)
        sw = common.draw_text(style.font, text_color, config.plugins.todotreeview.todo_separator..item.text, nil, x, y, 0, h)
      else
        sw = common.draw_text(style.font, text_color, item.text, nil, x, y, 0, h)
        if self.current_mode ~= "file_tag" then
          sw = common.draw_text(style.font, style.dim, "(" .. item.filename .. ")", nil, sw, y, 0, h)
        end
      end
    end
    new_scroll_width = math.max(new_scroll_width, sw - ox)
  end
  self.scroll_width = new_scroll_width
  self.scroll_height = total_items * self:get_item_height() + (spacing * 2)
  self:draw_scrollbar()
end

function TodoTreeView:get_scrollable_size()
  return self.scroll_height
end

function TodoTreeView:get_h_scrollable_size()
  local  _, _, v_scroll_w = self.v_scrollbar:get_thumb_rect()
  return self.scroll_width + (
    self.size.x > self.scroll_width + v_scroll_w and 0 or style.padding.x
  )
end

function TodoTreeView:get_item_by_index(index)
  local i = 0
  for item in self:each_item() do
    if index == i then
      return item
    end
    i = i + 1
  end
  return nil
end

function TodoTreeView:get_hovered_parent_file_tag()
  local file_parent = nil
  local file_parent_index = 0
  local group_parent = nil
  local group_parent_index = 0
  local i = 0
  for item in self:each_item() do
    if item.type == "file" then
      file_parent = item
      file_parent_index = i
    end
    if item.type == "group" then
      group_parent = item
      group_parent_index = i
    end
    if i == self.focus_index then
      if item.type == "file" or item.type == "group" then
        return file_parent, file_parent_index
      else
        return group_parent, group_parent_index
      end
    end
    i = i + 1
  end
  return nil, 0
end

function TodoTreeView:get_hovered_parent()
  local parent = nil
  local parent_index = 0
  local i = 0
  for item in self:each_item() do
    if item.type == "group" or item.type == "file" then
      parent = item
      parent_index = i
    end
    if i == self.focus_index then
      return parent, parent_index
    end
    i = i + 1
  end
  return nil, 0
end

function TodoTreeView:update_scroll_position()
  local h = self:get_item_height()
  local _, min_y, _, max_y = self:get_content_bounds()
  local start_row = math.floor(min_y / h)
  local end_row = math.floor(max_y / h)
  if self.focus_index < start_row then
    self.scroll.to.y = self.focus_index * h
  end
  if self.focus_index + 1 > end_row then
    self.scroll.to.y = (self.focus_index * h) - self.size.y + h
  end
end

-- initialize a todo view and insert it on the right
---@type plugins.todotreeview
view = TodoTreeView()
local node = core.root_view:get_active_node()
view.size.x = config.plugins.todotreeview.treeview_size
node:split("right", view, {x=true}, true)

-- monitor mode or project dir changes
local last_mode = config.plugins.todotreeview.todo_mode
core.add_thread(function()
  while true do
    if
      core.root_project().path ~= view.current_project_dir
      or
      last_mode ~= config.plugins.todotreeview.todo_mode
    then
      last_mode = config.plugins.todotreeview.todo_mode
      view:refresh_cache()
    end
    coroutine.yield(5)
  end
end)

-- update todo tags on file save
local doc_save = Doc.save
function Doc:save(...)
  local res = doc_save(self, ...)
  if self.filename then
    core.add_thread(function()
      view:update_file(self.filename)
    end)
  end
  return res
end

-- remove from cached files
local os_remove = os.remove
function os.remove(filename)
  local file = common.relative_path(view.current_project_dir, filename)
  if view.cache[file] then
    core.add_thread(function()
      view.cache[file] = nil
      if config.plugins.todotreeview.todo_mode == "file" then
        view.items[file] = nil
      else
        local recursed = 0
        for tag, item in pairs(view.items) do
          local deleted = 0
          for pos=1, #item.todos do
            local todo = item.todos[pos-deleted]
            recursed = recursed + 1
            if todo.filename == file then
              table.remove(view.items[tag].todos, pos-deleted)
              deleted = deleted + 1
            end
            if recursed % 1000 == 0 then coroutine.yield() end
          end
          if #view.items[tag].todos <= 0 then
            view.items[tag] = nil
          end
        end
      end
    end)
  end
  return os_remove(filename)
end

core.status_view:add_item({
  predicate = function()
    return #view.filter > 0 and core.active_view and not core.active_view:is(CommandView)
  end,
  name = "todotreeview:filter",
  alignment = core.status_view.Item.RIGHT,
  get_item = function()
    return {
      style.text,
      string.format("Filter: %s", view.filter)
    }
  end,
  position = 1,
  tooltip = "Todos filtered by",
  separator = core.status_view.separator2
})

-- register commands and keymap
local previous_view = nil
command.add(nil, {
  ["todotreeview:toggle"] = function()
    view.visible = not view.visible
  end,

  ["todotreeview:expand-items"] = function()
    for _, item in pairs(view.items) do
      item.expanded = true
    end
  end,

  ["todotreeview:hide-items"] = function()
    for _, item in pairs(view.items) do
      item.expanded = false
    end
  end,

  ["todotreeview:refresh"] = function()
    view:refresh_cache()
  end,

  ["todotreeview:toggle-focus"] = function()
    if not core.active_view:is(TodoTreeView) then
      previous_view = core.active_view
      core.set_active_view(view)
      view.hovered_item = view:get_item_by_index(view.focus_index)
    else
      command.perform("todotreeview:release-focus")
    end
  end,

  ["todotreeview:filter-notes"] = function()
    local todo_view_focus = core.active_view:is(TodoTreeView)
    local previous_filter = view.filter
    local submit = function(text)
      view.filter = text
      if todo_view_focus then
        view.focus_index = 0
        view.hovered_item = view:get_item_by_index(view.focus_index)
        view:update_scroll_position()
      end
    end
    local suggest = function(text)
      view.filter = text
    end
    local cancel = function(explicit)
      view.filter = previous_filter
    end
    core.command_view:enter("Filter Notes", {
      text = view.filter,
      submit = submit,
      suggest = suggest,
      cancel = cancel
    })
  end,
})

command.add(
  function()
    return core.active_view:is(TodoTreeView)
  end, {
  ["todotreeview:previous"] = function()
    if view.focus_index > 0 then
      view.focus_index = view.focus_index - 1
      view.hovered_item = view:get_item_by_index(view.focus_index)
      view:update_scroll_position()
    end
  end,

  ["todotreeview:next"] = function()
    local next_index = view.focus_index + 1
    local next_item = view:get_item_by_index(next_index)
    if next_item then
      view.focus_index = next_index
      view.hovered_item = next_item
      view:update_scroll_position()
    end
  end,

  ["todotreeview:collapse"] = function()
    if not view.hovered_item then
      return
    end

    if view.hovered_item.type == "file" then
      view.hovered_item.expanded = false
    else
      if view.hovered_item.type == "group" and view.hovered_item.expanded then
        view.hovered_item.expanded = false
      else
        if config.plugins.todotreeview.todo_mode == "file_tag" then
          view.hovered_item, view.focus_index = view:get_hovered_parent_file_tag()
        else
          view.hovered_item, view.focus_index = view:get_hovered_parent()
        end

        view:update_scroll_position()
      end
    end
  end,

  ["todotreeview:expand"] = function()
    if not view.hovered_item then
      return
    end

    if view.hovered_item.type == "file" or view.hovered_item.type == "group" then
      if view.hovered_item.expanded then
        command.perform("todotreeview:next")
      else
        view.hovered_item.expanded = true
      end
    end
  end,

  ["todotreeview:open"] = function()
    if not view.hovered_item then
      return
    end

    view:goto_hovered_item()
    view.hovered_item = nil
  end,

  ["todotreeview:release-focus"] = function()
    core.set_active_view(
      previous_view or core.root_view:get_primary_node().active_view
    )
    view.hovered_item = nil
  end,
})

keymap.add { ["ctrl+shift+t"] = "todotreeview:toggle" }
keymap.add { ["ctrl+shift+e"] = "todotreeview:expand-items" }
keymap.add { ["ctrl+shift+h"] = "todotreeview:hide-items" }
keymap.add { ["ctrl+shift+b"] = "todotreeview:filter-notes" }
keymap.add { ["up"] = "todotreeview:previous" }
keymap.add { ["down"] = "todotreeview:next" }
keymap.add { ["left"] = "todotreeview:collapse" }
keymap.add { ["right"] = "todotreeview:expand" }
keymap.add { ["return"] = "todotreeview:open" }
keymap.add { ["escape"] = "todotreeview:release-focus" }
