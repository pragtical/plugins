-- mod-version:3
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

---@class config.plugins.todotreeview
---List of tags to search
---@field todo_tags table<integer, string>
---List of paths or files to be ignored
---@field ignore_paths table<integer, string>
---Tells if the plugin should start with the nodes expanded
---@field todo_expanded boolean
---The mode used to group the found todos
---@field todo_mode "tag" | "file"
---Default size of the todotreeview pane
---@field treeview_size number

---@type plugins.todotreeview
local view

---@type config.plugins.todotreeview
config.plugins.todotreeview = common.merge({
  todo_tags = {"TODO", "BUG", "FIX", "FIXME", "IMPROVEMENT"},
  ignore_paths = {},
  todo_expanded = true,
  todo_mode = "tag",
  treeview_size = math.floor(200 * SCALE),
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
        {"File", "file"}
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
  self.current_project_dir = ""

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
    local root = core.project_dir
    local directories = {""}

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
              info and not common.match_pattern(
                directory .. file, config.ignore_files
              )
            then
              if info.type == "dir" then
                table.insert(directories, directory .. file)
              else
                info.filename = common.relative_path(
                  core.project_dir,
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
  self.current_project_dir = core.project_dir
  self.items = {}
  self.cache = {}

  local items = {}
  if not next(self.items) then
    items = self.items
  end
  self.updating_cache = true

  core.add_thread(function()
    local count = 0
    for item in get_project_files() do
      local ignored = is_file_ignored(item.filename)
      if not ignored and item.type == "file" then
        count = count + 1
        local cached = self:get_cached(item.filename)

        if cached then
          if config.plugins.todotreeview.todo_mode == "file" then
            items[cached.filename] = cached
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
    if config.plugins.todotreeview.todo_mode == "tag" and next(self.items) then
      for tag, data in pairs(self.items) do
        if items[tag] then
          items[tag].expanded = data.expanded
        end
      end
    end

    self.items = items
    self.updating_cache = false

    if self.visible then
      core.redraw = true
    end
  end, self)
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
        d.tag = todo_tag
        d.filename = filename
        d.text = extended_line:sub(e+1)
        if d.text == "" then
          d.text = "blank"
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
    t.abs_filename = system.absolute_path(filename)
    t.type = "file"
    t.todos = {}
    find_file_todos(t.todos, t.filename)
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
  else
    for tag, item in pairs(self.items) do
      local deleted = 0
      for pos=1, #item.todos do
        local todo = item.todos[pos-deleted]
        if todo.filename == filename then
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
            expanded = config.plugins.todotreeview.todo_expanded,
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
            coroutine.yield(todo, ox, y, w, h)
            y = y + h
          end
        end
      end
    end
  end)
end


function TodoTreeView:on_mouse_moved(px, py)
  if not self.visible then return end
  self.hovered_item = nil
  for item, x,y,w,h in self:each_item() do
    if px > x and py > y and px <= x + w and py <= y + h then
      self.hovered_item = item
      break
    end
  end
end


function TodoTreeView:on_mouse_pressed(button, x, y)
  if not self.visible then return end
  if not self.hovered_item then
    return
  elseif self.hovered_item.type == "file"
    or self.hovered_item.type == "group" then
    self.hovered_item.expanded = not self.hovered_item.expanded
  else
    core.try(function()
      local i = self.hovered_item
      local dv = core.root_view:open_doc(core.open_doc(i.filename))
      core.root_view.root_node:update_layout()
      dv.doc:set_selection(i.line, i.col)
      dv:scroll_to_line(i.line, false, true)
    end)
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

  for item, x,y,w,h in self:each_item() do
    local color = style.text

    -- hovered item background
    if item == self.hovered_item then
      renderer.draw_rect(x, y, w, h, style.line_highlight)
      color = style.accent
    end

    -- icons
    local item_depth = 0
    x = x + (item_depth - root_depth) * style.padding.x + style.padding.x
    if item.type == "file" then
      local icon1 = item.expanded and "-" or "+"
      common.draw_text(style.icon_font, color, icon1, nil, x, y, 0, h)
      x = x + style.padding.x
      common.draw_text(style.icon_font, color, "f", nil, x, y, 0, h)
      x = x + icon_width
    elseif item.type == "group" then
      local icon1 = item.expanded and "-" or ">"
      common.draw_text(style.icon_font, color, icon1, nil, x, y, 0, h)
      x = x + icon_width / 2
    else
      if config.plugins.todotreeview.todo_mode == "tag" then
        x = x + style.padding.x
      else
        x = x + style.padding.x * 1.5
      end
      common.draw_text(style.icon_font, color, "i", nil, x, y, 0, h)
      x = x + icon_width
    end

    -- text
    x = x + spacing
    if item.type == "file" then
      common.draw_text(style.font, color, item.filename, nil, x, y, 0, h)
    elseif item.type == "group" then
      common.draw_text(style.font, color, item.tag, nil, x, y, 0, h)
    else
      if config.plugins.todotreeview.todo_mode == "file" then
        common.draw_text(style.font, color, item.tag.." - "..(item.text or ""), nil, x, y, 0, h)
      else
        local fx = common.draw_text(style.font, color, item.text, nil, x, y, 0, h)
        common.draw_text(style.font, style.dim, "(" .. item.filename .. ")", nil, fx, y, 0, h)
      end
    end
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
    if not view.updating_cache then
      if
        core.project_dir ~= view.current_project_dir
        or
        last_mode ~= config.plugins.todotreeview.todo_mode
      then
        last_mode = config.plugins.todotreeview.todo_mode
        view:refresh_cache()
      end
    end
    coroutine.yield(5)
  end
end)

-- update todo tags on file save
local doc_save = Doc.save
function Doc:save(...)
  local res = doc_save(self, ...)
  if self.filename then
    view.updating_cache = true
    core.add_thread(function()
      view:update_file(self.filename)
      view.updating_cache = false
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

-- register commands and keymap
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
})

keymap.add { ["ctrl+shift+t"] = "todotreeview:toggle" }
keymap.add { ["ctrl+shift+e"] = "todotreeview:expand-items" }
keymap.add { ["ctrl+shift+h"] = "todotreeview:hide-items" }

