-- mod-version:3.8
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local storage = require "core.storage"
local style = require "core.style"
local View = require "core.view"

config.plugins.snake = common.merge({
  columns = 28, rows = 20, speed = 8,
  initial_length = config.snake_length or 6,
  wrap = config.snake_wall_die ~= true,
  config_spec = {
    name = "Snake",
    { label = "Starting Speed", path = "speed", type = "NUMBER",
      default = 8, min = 3, max = 14,
      description = "Cells per second at the beginning of a new game." },
    { label = "Wrap Edges", path = "wrap", type = "TOGGLE", default = true }
  }
}, config.plugins.snake)

local colors = {
  background = { 20, 23, 26, 255 }, board = { 27, 32, 35, 255 },
  tile = { 31, 37, 40, 255 }, edge = { 63, 75, 79, 255 },
  text = { 234, 241, 237, 255 }, muted = { 143, 162, 162, 255 },
  mint = { 150, 239, 195, 255 }, tail = { 57, 153, 131, 255 },
  fruit = { 255, 111, 126, 255 }, shine = { 255, 198, 183, 255 },
  leaf = { 204, 226, 142, 255 }, button = { 39, 48, 51, 255 },
  hover = { 55, 69, 72, 255 }, shade = { 15, 19, 22, 190 }
}
local vectors = {
  left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 }
}
local records = storage.load("snake", "records")
if type(records) ~= "table" then records = {} end
for _, mode in ipairs({ "wrap", "walls" }) do
  local value = tonumber(records[mode]) or 0
  records[mode] = value >= 0 and value < math.huge and math.floor(value) or 0
end

local function rect(x, y, w, h, color)
  if w > 0 and h > 0 then
    renderer.draw_rect(math.floor(x), math.floor(y), math.ceil(w), math.ceil(h), color)
  end
end

local function contains(box, x, y)
  return x >= box.x and y >= box.y and x < box.x + box.w and y < box.y + box.h
end

local function text(font, value, x, y, color, align)
  if align == "center" then x = x - font:get_width(value) / 2
  elseif align == "right" then x = x - font:get_width(value) end
  renderer.draw_text(font, value, math.floor(x), math.floor(y), color)
end

local SnakeView = View:extend()
SnakeView.context = "session"

function SnakeView:new(options)
  SnakeView.super.new(self)
  local cfg = common.merge(config.plugins.snake, options or {})
  self.columns = math.floor(common.clamp(tonumber(cfg.columns) or 28, 8, 60))
  self.rows = math.floor(common.clamp(tonumber(cfg.rows) or 20, 8, 40))
  self.base_speed = common.clamp(tonumber(cfg.speed) or 8, 3, 14)
  self.initial_length = math.floor(common.clamp(tonumber(cfg.initial_length) or 6, 3, self.columns - 2))
  self.mode = cfg.wrap and "wrap" or "walls"
  self.seed = (math.floor(tonumber(cfg.seed) or system.get_time() * 1000000) % 2147483646) + 1
  self.buttons, self.particles = {}, {}
  self:reset()
  core.add_thread(function()
    while not self.closed do
      if not core.root_view.root_node:get_node_for_view(self) then break end
      if self.state == "running" then
        if core.active_view ~= self then self:toggle_pause() end
        core.redraw = true
      end
      if core.root_view.touched_view ~= self then self.touch = nil end
      coroutine.yield(1 / 60)
    end
  end, self)
end

function SnakeView:get_name() return "Snake" end
function SnakeView:supports_text_input() return false end

function SnakeView:random()
  -- Private Park-Miller generator: do not reseed the editor's Lua RNG.
  self.seed = (self.seed * 16807) % 2147483647
  return self.seed / 2147483647
end

function SnakeView:reset()
  self.state, self.score, self.level = "ready", 0, 1
  self.direction, self.turns = "right", {}
  self.accumulator, self.clock = 0, 0
  self.last_time = system.get_time()
  self.snake, self.previous, self.particles = {}, nil, {}
  local head = math.max(self.initial_length - 1, math.floor(self.columns / 2))
  for i = 1, self.initial_length do
    self.snake[i] = { x = head - i + 1, y = math.floor(self.rows / 2) }
  end
  self:spawn_food()
  core.redraw = true
end

function SnakeView:spawn_food()
  local occupied, free = {}, {}
  for _, part in ipairs(self.snake) do occupied[part.y * self.columns + part.x] = true end
  for y = 0, self.rows - 1 do
    for x = 0, self.columns - 1 do
      if not occupied[y * self.columns + x] then free[#free + 1] = { x = x, y = y } end
    end
  end
  self.food = free[math.floor(self:random() * #free) + 1]
  if not self.food then self.state = "won" end
end

function SnakeView:interval()
  return 1 / math.min(18, self.base_speed + self.level - 1)
end

function SnakeView:save_best()
  if self.score > records[self.mode] then
    records[self.mode] = self.score
    storage.save("snake", "records", records)
  end
end

function SnakeView:turn(direction)
  if not vectors[direction] or self.state == "paused" or self.state == "over" or self.state == "won" then return end
  local old = vectors[self.turns[#self.turns] or self.direction]
  local next_direction = vectors[direction]
  if old[1] + next_direction[1] == 0 and old[2] + next_direction[2] == 0 then return end
  if self.state == "ready" then self:toggle_pause() end
  if direction ~= (self.turns[#self.turns] or self.direction) and #self.turns < 2 then
    self.turns[#self.turns + 1] = direction
  end
end

function SnakeView:toggle_pause()
  if self.state == "over" or self.state == "won" then self:reset() end
  self.state = self.state == "running" and "paused" or "running"
  self.last_time, self.accumulator = system.get_time(), 0
  self.previous, self.turns = nil, {}
  core.redraw = true
end

function SnakeView:set_mode(mode)
  if mode == self.mode or self.state == "running" then return end
  self.mode = mode
  self:reset()
end

function SnakeView:step()
  if self.state ~= "running" then return end
  self.direction = table.remove(self.turns, 1) or self.direction
  local direction, head = vectors[self.direction], self.snake[1]
  local x, y = head.x + direction[1], head.y + direction[2]
  if self.mode == "wrap" then
    x, y = x % self.columns, y % self.rows
  elseif x < 0 or y < 0 or x >= self.columns or y >= self.rows then
    self.state, self.previous = "over", nil
    core.redraw = true
    return
  end
  local eating = self.food and x == self.food.x and y == self.food.y
  -- The old tail vacates its cell on a non-growing move.
  for i = 1, #self.snake - (eating and 0 or 1) do
    if self.snake[i].x == x and self.snake[i].y == y then
      self.state, self.previous = "over", nil
      core.redraw = true
      return
    end
  end
  self.previous = self.snake
  local body = { { x = x, y = y } }
  for i = 1, #self.snake - (eating and 0 or 1) do body[#body + 1] = self.snake[i] end
  self.snake = body
  if eating then
    self.score = self.score + 10
    self.level = 1 + math.floor(self.score / 50)
    self:save_best()
    for i = 1, 8 do
      local angle = i * math.pi / 4
      self.particles[#self.particles + 1] = {
        x = x + .5, y = y + .5, vx = math.cos(angle) * 3,
        vy = math.sin(angle) * 3, life = .4
      }
    end
    self:spawn_food()
  end
  core.redraw = true
end

function SnakeView:advance(dt)
  if self.state ~= "running" then return end
  dt = common.clamp(dt, 0, .25)
  self.clock = self.clock + dt
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.life, p.x, p.y = p.life - dt, p.x + p.vx * dt, p.y + p.vy * dt
    if p.life <= 0 then table.remove(self.particles, i) end
  end
  self.accumulator = self.accumulator + dt
  while self.state == "running" and self.accumulator + 1e-9 >= self:interval() do
    self.accumulator = math.max(0, self.accumulator - self:interval())
    self:step()
  end
end

function SnakeView:update()
  SnakeView.super.update(self)
  local now = system.get_time()
  local dt = now - self.last_time
  self.last_time = now
  if core.active_view ~= self or not system.window_has_focus(core.window)
    or self.size.x < 240 * SCALE or self.size.y < 220 * SCALE then
    if self.state == "running" then self:toggle_pause() end
    return
  end
  self:advance(dt)
end

function SnakeView:try_close(close)
  self.closed = true
  core.threads[self] = nil
  close()
end

function SnakeView:layout()
  local s, x, y, w, h = SCALE, self.position.x, self.position.y, self.size.x, self.size.y
  local pad = 12 * s
  local cell = math.floor(math.min((w - pad * 2) / self.columns, (h - 120 * s) / self.rows, 32 * s))
  local bw, bh = self.columns * cell, self.rows * cell
  self.board = { x = math.floor(x + (w - bw) / 2), y = math.floor(y + 64 * s + (h - 120 * s - bh) / 2), w = bw, h = bh, cell = cell }
  local fy, height = y + h - 44 * s, 32 * s
  local label = ({ ready = "Play", running = "Pause", paused = "Resume", over = "Retry", won = "Play again" })[self.state]
  self.buttons = {
    { id = "wrap", label = "Wrap", x = x + pad, y = fy, w = 52 * s, h = height, disabled = self.state == "running" },
    { id = "walls", label = "Walls", x = x + pad + 52 * s, y = fy, w = 52 * s, h = height, disabled = self.state == "running" },
    { id = "play", label = label, x = x + w - pad - 78 * s, y = fy, w = 78 * s, h = height }
  }
  if self.state == "running" or self.state == "paused" then
    if w < 300 * s then
      table.remove(self.buttons, 1)
      table.remove(self.buttons, 1)
    end
    self.buttons[#self.buttons + 1] = { id = "restart", label = "Restart", x = x + w - pad - 148 * s, y = fy, w = 64 * s, h = height }
  end
  return self.board
end

function SnakeView:on_mouse_moved(x, y)
  self.mouse = { x = x, y = y }
  self.cursor = "arrow"
  for _, button in ipairs(self.buttons) do
    if not button.disabled and contains(button, x, y) then self.cursor = "hand" end
  end
  core.redraw = true
end

function SnakeView:on_mouse_left()
  self.mouse = nil
  self.cursor = "arrow"
  core.redraw = true
end

function SnakeView:on_mouse_pressed(button, x, y)
  if button ~= "left" then return false end
  for _, item in ipairs(self.buttons) do
    if contains(item, x, y) then
      if not item.disabled then
        if item.id == "play" then self:toggle_pause()
        elseif item.id == "restart" then self:reset()
        else self:set_mode(item.id) end
      end
      return true
    end
  end
  return true
end

function SnakeView:on_touch_moved(x, y, dx, dy, id)
  local now = system.get_time()
  if not self.touch or self.touch.id ~= id or now - self.touch.time > .2 then
    self.touch = { dx = 0, dy = 0, id = id }
  end
  local touch = self.touch
  touch.dx, touch.dy, touch.time = touch.dx + dx, touch.dy + dy, now
  if math.max(math.abs(touch.dx), math.abs(touch.dy)) < 16 * SCALE then return end
  self:turn(math.abs(touch.dx) > math.abs(touch.dy)
    and (touch.dx > 0 and "right" or "left") or (touch.dy > 0 and "down" or "up"))
  touch.dx, touch.dy = 0, 0
end

function SnakeView:on_mouse_wheel() return true end

function SnakeView:draw_piece(x, y, cell, color, head)
  local inset = math.max(1, math.floor(cell * .08))
  local size = cell - inset * 2
  rect(x + inset, y + inset, size, size, color)
  if not head or cell < 6 then return end
  local eye = math.max(1, math.floor(cell * .11))
  local dx, dy = vectors[self.direction][1], vectors[self.direction][2]
  for _, side in ipairs({ -1, 1 }) do
    local ex = x + cell * (.5 + dx * .23 + dy * side * .22)
    local ey = y + cell * (.5 + dy * .23 + dx * side * .22)
    rect(ex - eye / 2, ey - eye / 2, eye, eye, colors.background)
  end
end

function SnakeView:draw()
  self:draw_background(colors.background)
  core.push_clip_rect(self.position.x, self.position.y, self.size.x, self.size.y)
  if not self.fonts or self.font_scale ~= SCALE or self.source_font ~= style.font then
    self.fonts = { title = style.font:copy(22 * SCALE), body = style.font:copy(14 * SCALE), small = style.font:copy(11 * SCALE), number = style.code_font:copy(22 * SCALE) }
    self.font_scale, self.source_font = SCALE, style.font
  end
  local f, s = self.fonts, SCALE
  local x, y, w, h = self.position.x, self.position.y, self.size.x, self.size.y
  if w < 240 * s or h < 220 * s then
    self.buttons = {}
    text(f.body, "Snake", x + w / 2, y + h / 2 - f.body:get_height() / 2, colors.mint, "center")
    core.pop_clip_rect()
    return
  end
  local b = self:layout()
  local pad, title_x = 12 * s, x + 12 * s
  if w >= 440 * s then
    for i, p in ipairs({ {0, 2}, {1, 2}, {2, 2}, {2, 1}, {2, 0}, {3, 0} }) do
      rect(title_x + p[1] * 6 * s, y + 17 * s + p[2] * 6 * s, 5 * s, 5 * s, i == 6 and colors.mint or colors.tail)
    end
    title_x = title_x + 38 * s
  end
  text(f.title, "SNAKE", title_x, y + 10 * s, colors.text)
  text(f.small, "LEVEL " .. self.level, title_x, y + 36 * s, colors.muted)
  for i, data in ipairs({ { "SCORE", self.score }, { "BEST", records[self.mode] } }) do
    local tx = x + w - pad - (2 - i) * 76 * s
    text(f.small, data[1], tx, y + 9 * s, colors.muted, "right")
    text(f.number, string.format("%03d", data[2]), tx, y + 23 * s, i == 1 and colors.mint or colors.text, "right")
  end
  rect(b.x - 2, b.y - 2, b.w + 4, b.h + 4, self.mode == "walls" and colors.fruit or colors.edge)
  rect(b.x, b.y, b.w, b.h, colors.board)
  core.push_clip_rect(b.x, b.y, b.w, b.h)
  for row = 0, self.rows - 1 do
    for col = row % 2, self.columns - 1, 2 do
      rect(b.x + col * b.cell, b.y + row * b.cell, b.cell, b.cell, colors.tile)
    end
  end
  if self.food then
    local pulse = self.state == "running" and math.sin(self.clock * 5) * .025 or 0
    local fx, fy, unit = b.x + (self.food.x + .5) * b.cell, b.y + (self.food.y + .5) * b.cell, b.cell
    rect(fx - unit * (.28 + pulse), fy - unit * .2, unit * (.56 + pulse * 2), unit * .5, colors.fruit)
    rect(fx - unit * .18, fy - unit * .3, unit * .36, unit * .7, colors.fruit)
    rect(fx + unit * .02, fy - unit * .45, unit * .22, unit * .13, colors.leaf)
    rect(fx - unit * .19, fy - unit * .13, unit * .1, unit * .15, colors.shine)
  end
  local alpha = self.state == "running" and common.clamp(self.accumulator / self:interval(), 0, 1) or 1
  for i = #self.snake, 1, -1 do
    local part = self.snake[i]
    local previous = self.previous and (self.previous[i] or self.previous[#self.previous]) or part
    local dx, dy = part.x - previous.x, part.y - previous.y
    if math.abs(dx) > 1 then dx = dx > 0 and -1 or 1 end
    if math.abs(dy) > 1 then dy = dy > 0 and -1 or 1 end
    local px, py = (previous.x + dx * alpha) % self.columns, (previous.y + dy * alpha) % self.rows
    local color = common.lerp(colors.mint, colors.tail, (i - 1) / math.max(1, #self.snake))
    if self.state == "over" and i == 1 then color = colors.fruit end
    self:draw_piece(b.x + px * b.cell, b.y + py * b.cell, b.cell, color, i == 1)
    if px > self.columns - 1 then self:draw_piece(b.x + (px - self.columns) * b.cell, b.y + py * b.cell, b.cell, color, i == 1) end
    if py > self.rows - 1 then self:draw_piece(b.x + px * b.cell, b.y + (py - self.rows) * b.cell, b.cell, color, i == 1) end
  end
  for _, p in ipairs(self.particles) do
    local size = math.max(1, b.cell * .12 * p.life / .4)
    rect(b.x + p.x * b.cell - size / 2, b.y + p.y * b.cell - size / 2, size, size, colors.shine)
  end
  if self.state ~= "running" then
    rect(b.x, b.y, b.w, b.h, colors.shade)
    local message = ({ ready = "Ready", paused = "Paused", over = "Game over", won = "Board clear" })[self.state]
    text(f.title, message, b.x + b.w / 2, b.y + b.h / 2 - f.title:get_height() / 2, colors.text, "center")
  end
  core.pop_clip_rect()
  if #self.buttons == 2 then
    text(f.small, self.mode:upper(), x + pad, y + h - 34 * s, colors.muted)
  end
  for _, item in ipairs(self.buttons) do
    local selected = item.id == self.mode or item.id == "play"
    local hovered = self.mouse and contains(item, self.mouse.x, self.mouse.y) and not item.disabled
    rect(item.x, item.y, item.w, item.h, selected and colors.mint or hovered and colors.hover or colors.button)
    local color = selected and colors.background or item.disabled and colors.muted or colors.text
    text(f.body, item.label, item.x + item.w / 2, item.y + (item.h - f.body:get_height()) / 2, color, "center")
  end
  core.pop_clip_rect()
end

command.add(nil, {
  ["snake:open"] = function()
    core.root_view:get_active_node_default():add_view(SnakeView())
  end
})
command.add(SnakeView, {
  ["snake:up"] = function(view) view:turn("up") end,
  ["snake:down"] = function(view) view:turn("down") end,
  ["snake:left"] = function(view) view:turn("left") end,
  ["snake:right"] = function(view) view:turn("right") end,
  ["snake:pause"] = function(view) view:toggle_pause() end,
  ["snake:restart"] = function(view) view:reset() end,
  ["snake:escape"] = function(view)
    if view.state == "running" then view:toggle_pause() end
  end
})
keymap.add {
  ["up"] = "snake:up", ["w"] = "snake:up",
  ["down"] = "snake:down", ["s"] = "snake:down",
  ["left"] = "snake:left", ["a"] = "snake:left",
  ["right"] = "snake:right", ["d"] = "snake:right",
  ["space"] = "snake:pause", ["return"] = "snake:pause",
  ["p"] = "snake:pause", ["r"] = "snake:restart", ["escape"] = "snake:escape"
}

return SnakeView
