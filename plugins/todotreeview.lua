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
---Amount of worker threads used for project-wide TODO scans.
---@field threading_workers integer

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
  threading_workers = math.ceil(thread.get_cpu_count() / 2) + 1,
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
      label = "Workers",
      description = "The maximum amount of threads to create per scan.",
      path = "threading_workers",
      type = "number",
      default = math.ceil(thread.get_cpu_count() / 2) + 1,
      min = 1
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
  self.current_mode = config.plugins.todotreeview.todo_mode
  self.current_project_dir = ""
  self.scan = nil
  self.file_updates = {}
  self.scroll_width = 0
  self.scroll_height = 0
  self.scrollable = true
  self.focus_index = 0
  self.filter = ""

  -- Items are generated from cache according to the mode
  self.items = {}
end

local threaded_scan_id = 0
local threaded_update_id = 0

local function todo_scan_thread(tid, options)
  local commons = require "core.common"
  local result_channel = thread.get_channel("todotree_results" .. tid)
  local status_channel = thread.get_channel("todotree_status" .. tid)
  local stop_channel = thread.get_channel("todotree_stop" .. tid)
  local filename_channels = {}
  local workers_list = {}
  local workers = options.workers or 1

  local function todo_worker_thread(tid, id, options)
    local function parse_file_todos(abs_filename, tags, default_text)
      local todos = {}
      local fp = io.open(abs_filename)
      if not fp then return todos end
      local n = 1
      for line in fp:lines() do
        for _, todo_tag in ipairs(tags or {}) do
          local extended_line = " " .. line .. " "
          local match_str = "[^a-zA-Z_\"'`]" .. todo_tag .. "[^\"'a-zA-Z_`]+"
          local s, e = extended_line:find(match_str)
          if s then
            local text = extended_line:sub(e + 1)
            table.insert(todos, {
              type = "todo",
              tag = todo_tag,
              filename = abs_filename,
              text = text ~= "" and text or default_text,
              line = n,
              col = s
            })
          end
        end
        n = n + 1
      end
      fp:close()
      return todos
    end

    local filename_channel = thread.get_channel("todotree_fname" .. tid .. id)
    local result_channel = thread.get_channel("todotree_results" .. tid)
    local stop_channel = thread.get_channel("todotree_stop" .. tid)
    local job = filename_channel:wait()
    while job ~= "{{stop}}" do
      if stop_channel:first() == "stop" then break end
      result_channel:push({
        filename = job.filename,
        abs_filename = job.abs_filename,
        todos = parse_file_todos(
          job.abs_filename,
          options.todo_tags,
          options.todo_default_text
        )
      })
      filename_channel:pop()
      job = filename_channel:wait()
    end
    filename_channel:clear()
    return 0
  end

  for id = 1, workers do
    filename_channels[id] = thread.get_channel("todotree_fname" .. tid .. id)
    local worker, err = thread.create(
      "todowrk" .. tid .. id,
      todo_worker_thread,
      tid,
      id,
      options
    )
    if not worker then
      status_channel:clear()
      status_channel:push({
        error = err or "unknown error"
      })
      for worker_id = 1, id - 1 do
        filename_channels[worker_id]:push("{{stop}}")
      end
      for _, worker_thread in ipairs(workers_list) do
        if worker_thread then worker_thread:wait() end
      end
      return 1
    end
    workers_list[id] = worker
  end

  local function is_ignored(filename, info)
    if commons.match_ignore_rule(filename, info, options.ignore_files or {}) then
      return true
    end
    for _, pattern in ipairs(options.ignore_paths or {}) do
      if filename:find(pattern) then
        return true
      end
    end
    return false
  end

  local count = 0
  local current_worker = 1
  local directories = {""}
  while #directories > 0 and stop_channel:first() ~= "stop" do
    for didx, directory in ipairs(directories) do
      local dir_path
      local rel_prefix
      if directory ~= "" then
        dir_path = options.root .. options.pathsep .. directory
        rel_prefix = directory .. options.pathsep
      else
        dir_path = options.root
        rel_prefix = ""
      end

      local files = system.list_dir(dir_path)
      if files then
        for _, file in ipairs(files) do
          if stop_channel:first() == "stop" then break end
          local rel_filename = rel_prefix .. file
          local abs_filename = dir_path .. options.pathsep .. file
          local info = system.get_file_info(abs_filename)
          if info and not is_ignored(rel_filename, info) then
            if info.type == "dir" then
              table.insert(directories, rel_filename)
            elseif info.type == "file" and info.size <= options.file_size_limit then
              count = count + 1
              filename_channels[current_worker]:push({
                filename = rel_filename,
                abs_filename = abs_filename
              })
              current_worker = current_worker + 1
              if current_worker > workers then current_worker = 1 end
              if count % 100 == 0 then
                status_channel:clear()
                status_channel:push(count)
              end
            end
          end
        end
      end
      table.remove(directories, didx)
      break
    end
  end

  for id = 1, workers do
    filename_channels[id]:push("{{stop}}")
  end
  for _, worker in ipairs(workers_list) do
    if worker then worker:wait() end
  end

  if stop_channel:first() == "stop" then
    result_channel:clear()
    status_channel:clear()
  else
    status_channel:clear()
    status_channel:push("finished")
  end
  return 0
end

local function todo_file_thread(tid, options)
  local function parse_file_todos(abs_filename, tags, default_text)
    local todos = {}
    local fp = io.open(abs_filename)
    if not fp then return todos end
    local n = 1
    for line in fp:lines() do
      for _, todo_tag in ipairs(tags or {}) do
        local extended_line = " " .. line .. " "
        local match_str = "[^a-zA-Z_\"'`]" .. todo_tag .. "[^\"'a-zA-Z_`]+"
        local s, e = extended_line:find(match_str)
        if s then
          local text = extended_line:sub(e + 1)
          table.insert(todos, {
            type = "todo",
            tag = todo_tag,
            filename = abs_filename,
            text = text ~= "" and text or default_text,
            line = n,
            col = s
          })
        end
      end
      n = n + 1
    end
    fp:close()
    return todos
  end

  local result_channel = thread.get_channel("todotree_update_results" .. tid)
  local status_channel = thread.get_channel("todotree_update_status" .. tid)
  result_channel:push({
    filename = options.filename,
    abs_filename = options.abs_filename,
    todos = parse_file_todos(
      options.abs_filename,
      options.todo_tags,
      options.todo_default_text
    )
  })
  status_channel:push("finished")
  return 0
end

local function make_cached_file(result)
  if not result or #result.todos == 0 then return nil end
  return {
    expanded = config.plugins.todotreeview.todo_expanded,
    filename = result.filename,
    abs_filename = result.abs_filename,
    type = "file",
    todos = result.todos,
    tags = {}
  }
end

local function add_cached_to_items(items, cached, mode, old)
  if not cached then return end
  if mode == "file" then
    items[cached.filename] = cached
    if old and old[cached.filename] then
      cached.expanded = old[cached.filename].expanded
    end
  elseif mode == "file_tag" then
    local old_file = old and old[cached.filename]
    local file_t = {
      expanded = old_file and old_file.expanded or config.plugins.todotreeview.todo_expanded,
      type = "file",
      tags = {},
      todos = {},
      filename = cached.filename,
      abs_filename = cached.abs_filename
    }
    items[cached.filename] = file_t
    for _, todo in ipairs(cached.todos) do
      local tag = todo.tag
      if not file_t.tags[tag] then
        file_t.tags[tag] = {
          expanded = old_file and old_file.tags and old_file.tags[tag]
            and old_file.tags[tag].expanded
            or config.plugins.todotreeview.todo_expanded,
          type = "group",
          todos = {},
          tag = tag
        }
      end
      table.insert(file_t.tags[tag].todos, todo)
    end
  else
    for _, todo in ipairs(cached.todos) do
      local tag = todo.tag
      if not items[tag] then
        items[tag] = {
          expanded = old and old[tag] and old[tag].expanded
            or config.plugins.todotreeview.todo_expanded,
          type = "group",
          todos = {},
          tag = tag
        }
      end
      table.insert(items[tag].todos, todo)
    end
  end
end

local function remove_file_from_items(
  items, filename, abs_filename, mode, yield_every
)
  if mode == "file" or mode == "file_tag" then
    items[filename] = nil
    return
  end
  local recursed = 0
  for tag, item in pairs(items) do
    local deleted = 0
    for pos = 1, #item.todos do
      local todo = item.todos[pos - deleted]
      recursed = recursed + 1
      if todo.filename == abs_filename then
        table.remove(item.todos, pos - deleted)
        deleted = deleted + 1
      end
      if yield_every and recursed % yield_every == 0 then coroutine.yield() end
    end
    if #item.todos <= 0 then
      items[tag] = nil
    end
  end
end

local function drain_scan_results(self, result_channel, items, old_items, mode)
  local found = false
  local result = result_channel:first()
  while result do
    local cached = make_cached_file(result)
    if cached then
      self.cache[cached.filename] = cached
      add_cached_to_items(items, cached, mode, old_items)
    end
    result_channel:pop()
    found = true
    result = result_channel:first()
  end
  return found
end

function TodoTreeView:stop_scan()
  if self.scan then
    self.scan.stop_channel:push("stop")
  end
end

function TodoTreeView:refresh_cache()
  self:stop_scan()

  local project_dir = core.root_project().path
  local old_items = self.items
  local prev_mode = self.current_mode
  local current_mode = config.plugins.todotreeview.todo_mode
  local workers = math.max(
    1,
    math.floor(config.plugins.todotreeview.threading_workers or 1)
  )
  local ignore_files = core.get_ignore_file_rules()
  if not next(ignore_files) then ignore_files = nil end
  local ignore_paths = config.plugins.todotreeview.ignore_paths
  if not ignore_paths or not next(ignore_paths) then ignore_paths = nil end
  local todo_tags = config.plugins.todotreeview.todo_tags
  if not todo_tags or not next(todo_tags) then todo_tags = nil end

  threaded_scan_id = threaded_scan_id + 1
  local tid = threaded_scan_id
  local result_channel = thread.get_channel("todotree_results" .. tid)
  local status_channel = thread.get_channel("todotree_status" .. tid)
  local stop_channel = thread.get_channel("todotree_stop" .. tid)
  local items = {}

  self.current_project_dir = project_dir
  self.current_mode = current_mode
  self.cache = {}
  self.items = items
  self.updating_cache = true

  core.log_quiet("TODO View: Started Scanning")
  local start_time = system.get_time()
  local scan_thread, err = thread.create(
    "todoscan" .. tid,
    todo_scan_thread,
    tid,
    {
      root = project_dir,
      pathsep = PATHSEP,
      file_size_limit = config.file_size_limit * 1e6,
      ignore_files = ignore_files,
      ignore_paths = ignore_paths,
      todo_tags = todo_tags,
      todo_default_text = config.plugins.todotreeview.todo_default_text,
      workers = workers
    }
  )

  if not scan_thread then
    self.updating_cache = false
    core.error("Could not start TODO scanner: %s", err or "unknown error")
    return
  end

  local scan = {
    id = tid,
    thread = scan_thread,
    stop_channel = stop_channel
  }
  self.scan = scan

  core.add_thread(function()
    local status = status_channel:first()
    while
      self.scan == scan
      and status ~= "finished"
      and type(status) ~= "table"
    do
      if drain_scan_results(self, result_channel, items, old_items, current_mode) then
        core.redraw = true
      end
      coroutine.yield()
      status = status_channel:first()
    end

    if self.scan == scan and type(status) == "table" then
      self.updating_cache = false
      self.scan = nil
      core.error("TODO View: %s", status.error or "Scan failed")
    elseif self.scan == scan then
      drain_scan_results(self, result_channel, items, old_items, current_mode)
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
      self.updating_cache = false
      self.scan = nil
      core.log_quiet(
        "TODO View: Finished Scanning in %s seconds",
        system.get_time() - start_time
      )
      core.redraw = true
    end

    scan_thread:wait()
    result_channel:clear()
    status_channel:clear()
    stop_channel:clear()
  end)
end


function TodoTreeView:get_cached(filename)
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
  if self.updating_cache then return end

  local abs_filename = core.project_absolute_path(filename)
  threaded_update_id = threaded_update_id + 1
  local tid = threaded_update_id
  local result_channel = thread.get_channel("todotree_update_results" .. tid)
  local status_channel = thread.get_channel("todotree_update_status" .. tid)
  local todo_tags = config.plugins.todotreeview.todo_tags
  if not todo_tags or not next(todo_tags) then todo_tags = nil end
  local update_thread, err = thread.create(
    "todofile" .. tid,
    todo_file_thread,
    tid,
    {
      filename = filename,
      abs_filename = abs_filename,
      todo_tags = todo_tags,
      todo_default_text = config.plugins.todotreeview.todo_default_text
    }
  )

  if not update_thread then
    core.error("Could not start TODO file scan: %s", err or "unknown error")
    return
  end

  self.file_updates[filename] = tid

  core.add_thread(function()
    while status_channel:first() ~= "finished" do
      coroutine.yield()
    end

    local result = result_channel:first()
    result_channel:clear()
    status_channel:clear()
    update_thread:wait()

    if self.file_updates[filename] ~= tid then
      return
    end
    self.file_updates[filename] = nil
    if self.updating_cache then return end

    local mode = config.plugins.todotreeview.todo_mode
    local old_items = {}
    if mode == "file" or mode == "file_tag" then
      old_items[filename] = self.items[filename]
    else
      for tag, item in pairs(self.items) do
        old_items[tag] = { expanded = item.expanded }
      end
    end
    remove_file_from_items(self.items, filename, abs_filename, mode)
    self.cache[filename] = nil
    local cached = make_cached_file(result)
    if cached then
      self.cache[filename] = cached
      add_cached_to_items(self.items, cached, mode, old_items)
    end

    core.redraw = true
  end)
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
    view:update_file(self.filename)
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
      remove_file_from_items(
        view.items,
        file,
        core.project_absolute_path(file),
        config.plugins.todotreeview.todo_mode,
        1000
      )
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
