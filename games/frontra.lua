-- mod-version:3
-- frontra: a basic Contra NES-like game for Pragtical

local core = require "core"
local style = require "core.style"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local View = require "core.view"
local keymap = require "core.keymap"

config.plugins.frontra = common.merge({
  player_speed = 200,
  bullet_speed = 400,
  enemy_speed = 80,
  jump_velocity = -400,
  gravity = 900,
  fire_rate = 0.2,
  enemy_spawn_interval = 1.5,
  boss_health = 20,
  level_length = 4000,
  scroll_speed = 60,
  weapon_drop_chance = 0.25,
}, config.plugins.frontra)

local cfg = config.plugins.frontra

-- Base colors
local C = {
  player       = { common.color "#00ccff" },
  player_gun   = { common.color "#ffcc00" },
  bullet       = { common.color "#ffffff" },
  platform     = { common.color "#556655" },
  ground       = { common.color "#334433" },
  sky          = { common.color "#1a1a2e" },
  mountain     = { common.color "#2a2a3e" },
  star         = { common.color "#ffffff" },
  health_bar   = { common.color "#00ff00" },
  health_bg    = { common.color "#440000" },
  game_over    = { common.color "#ff0000" },
  win_text     = { common.color "#00ff00" },
  hud_text     = { common.color "#ffffff" },
  laser        = { common.color "#ff3333" },
  bomb_color   = { common.color "#ff9620" },
  rocket       = { common.color "#ff33ff" },
  wave_color   = { common.color "#33ffcc" },
  pickup_bg    = { common.color "#333333" },
}

-- Weapon definitions
local weapons = {
  default = {
    name = "Bullet",
    fire_rate = 0.2,
    ammo = -1,
    projectile = "bullet",
  },
  laser = {
    name = "Laser",
    fire_rate = 0.10,
    ammo = 100,
    projectile = "laser",
  },
  triple = {
    name = "Triple",
    fire_rate = 0.30,
    ammo = 50,
    projectile = "triple",
  },
  bomb = {
    name = "Bomb",
    fire_rate = 0.50,
    ammo = 15,
    projectile = "bomb",
  },
  homing = {
    name = "Homing",
    fire_rate = 0.40,
    ammo = 20,
    projectile = "homing",
  },
  wave = {
    name = "Wave",
    fire_rate = 0.80,
    ammo = 8,
    projectile = "wave",
  },
}

local weapon_drop_list = { "laser", "triple", "bomb", "homing", "wave" }

-- Random color generator for enemies/boss per level
local function random_level_color()
  local r = math.random(100, 255)
  local g = math.random(100, 255)
  local b = math.random(100, 255)
  return { common.color(string.format("#%02x%02x%02x", r, g, b)) }
end

local function random_eye_color(body_color)
  -- Generate a color that contrasts well with the body
  if body_color then
    -- Use complementary-ish approach: pick a hue opposite to the body
    local r, g, b = body_color[1], body_color[2], body_color[3]
    -- Brightness of body
    local brightness = (r + g + b) / 3
    if brightness > 150 then
      -- Body is bright, use dark eyes
      return { common.color(string.format("#%02x%02x%02x",
        math.floor(r * 0.3), math.floor(g * 0.3), math.floor(b * 0.3))) }
    else
      -- Body is dark, use bright white-ish eyes
      return { common.color(string.format("#%02x%02x%02x",
        math.min(255, math.floor(r + 150)),
        math.min(255, math.floor(g + 150)),
        math.min(255, math.floor(b + 150)))) }
    end
  end
  -- Fallback: always very bright
  return { common.color(string.format("#%02x%02x%02x",
    math.random(200, 255), math.random(200, 255), math.random(200, 255))) }
end

-- Parallax stars
local stars = {}
for i = 1, 60 do
  stars[i] = {
    x = math.random(),
    y = math.random(),
    size = math.random(1, 3),
    speed = 0.2 + math.random() * 0.3,
  }
end

-- Parallax mountains
local mountains = {}
for i = 1, 8 do
  mountains[i] = {
    x = i * 0.125,
    h = 0.15 + math.random() * 0.2,
    w = 0.1 + math.random() * 0.15,
  }
end

-- Level platforms (x = world x, y = fraction of screen height from ground up, w = width)
local platforms = {
  { x = 200,  y = 0.65, w = 120 },
  { x = 500,  y = 0.55, w = 100 },
  { x = 750,  y = 0.60, w = 80 },
  { x = 1000, y = 0.50, w = 100 },
  { x = 1300, y = 0.55, w = 90 },
  { x = 1600, y = 0.45, w = 110 },
  { x = 1900, y = 0.50, w = 80 },
  { x = 2200, y = 0.40, w = 100 },
  { x = 2500, y = 0.50, w = 90 },
  { x = 2800, y = 0.45, w = 80 },
  { x = 3100, y = 0.55, w = 100 },
  { x = 3400, y = 0.50, w = 120 },
}

-- Enemy spawn points (world x, y fraction from ground up)
-- More densely packed, especially near the boss area
local enemy_spawns = {
  { x = 300,  y = 0.70 },
  { x = 500,  y = 0.60 },
  { x = 700,  y = 0.55 },
  { x = 900,  y = 0.65 },
  { x = 1100, y = 0.50 },
  { x = 1300, y = 0.55 },
  { x = 1500, y = 0.60 },
  { x = 1700, y = 0.45 },
  { x = 1900, y = 0.50 },
  { x = 2100, y = 0.55 },
  { x = 2300, y = 0.50 },
  { x = 2500, y = 0.45 },
  { x = 2700, y = 0.55 },
  { x = 2900, y = 0.60 },
  { x = 3100, y = 0.55 },
  { x = 3300, y = 0.50 },
  { x = 3500, y = 0.55 },
}

-- Story slides for intro
local story_slides = {
  "The planet Xytheris was a beacon\nof peace and progress.",
  "Then the Oblivian Empire attacked,\nseeking total control.",
  "Their bot armies annihilated\nthe civilization in days.",
  "Only one survivor escaped:\nFrontran, the last warrior.",
  "To survive, eliminate all bots.\nReach the Main Frame.\nDestroy it.",
}

local BOSS_X = cfg.level_length - 400

-- Map key releases to their corresponding input flags
local release_map = {
  left  = "left",
  right = "right",
  up    = "jump",
  z     = "shoot",
  space = "shoot",
}

---@class FrontraView
local FrontraView = View:extend()

-- Hook key release to stop input flags when FrontraView is active.
-- The base keymap.on_key_released only handles modifier keys (ctrl,
-- alt, etc.), so non-modifier releases (arrows, Z, space) would
-- otherwise be silently dropped.
-- Must be defined after FrontraView so the class reference exists.
local orig_key_released = keymap.on_key_released
function keymap.on_key_released(k, ...)
  if core.active_view then
    local view_type = core.active_view
    if type(view_type.is) == "function" and view_type:is(FrontraView) then
      local flag = release_map[k]
      if flag then
        core.active_view.input[flag] = false
        return true
      end
    end
  end
  return orig_key_released(k, ...)
end

function FrontraView:new()
  FrontraView.super.new(self)
  self.finished = false
  self.paused = false
  self.won = false
  self.game_over = false

  -- Scale factor computed from view size (updated in update())
  self.scale = 1

  -- Input state (set by commands)
  self.input = {
    left  = false,
    right = false,
    jump  = false,
    shoot = false,
  }

  -- Player
  self.player = {
    x = 80, y = 0, w = 16, h = 24,
    vx = 0, vy = 0,
    on_ground = false,
    facing = 1,
    shoot_timer = 0,
    anim_frame = 0, anim_timer = 0,
    hp = 10, max_hp = 10,
    invincible = 0,
    weapon = "default",
    weapon_ammo = -1,
  }

  -- Game objects
  self.bullets = {}
  self.enemies = {}
  self.enemy_bullets = {}
  self.particles = {}
  self.fireworks = {}
  self.pickups = {}
  self.lasers = {}
  self.bombs = {}
  self.rockets = {}
  self.waves = {}

  -- Level state
  self.level = 1
  self.level_scroll = 0
  self.boss_spawned = false
  self.boss = nil
  self.main_frame = nil
  self.main_frame_spawned = false
  self.game_complete = false
  self.final_warning_timer = nil
  self.score = 0
  self.elapsed = 0
  self.spawn_timer = 0
  self.spawn_index = 1
  self.max_simultaneous_enemies = 2
  self.continuous_spawn = false -- true after fixed spawns are exhausted

  -- Level colors (regenerated on level up)
  self:generate_level_colors()

  -- Intro state
  self.intro = {
    phase = "logo",
    timer = 0,
    presented_alpha = 0,
    logo_alpha = 0,
    pragtical_alpha = 0,
    story_alpha = 0,
    story_slide = 1,
    start_timer = 0,
    player_x = 0,  -- for start screen player animation
  }

  -- Game loop
  self.thread = core.add_thread(function()
    while not self.finished do
      self:step()
      core.redraw = true
      coroutine.yield(1 / 60)
    end
  end)
end

function FrontraView:generate_level_colors()
  self.level_enemy_color = random_level_color()
  self.level_enemy_bullet_color = random_level_color()
  self.level_boss_color = random_level_color()
  self.level_boss_eye_color = random_eye_color(self.level_boss_color)
end

function FrontraView:get_name()
  return "Frontra"
end

function FrontraView:get_scale()
  return self.scale
end

function FrontraView:update()
  -- Compute scale based on view size (reference: 800x600)
  FrontraView.super.update(self)
  self.scale = math.min(self.size.x / 800, self.size.y / 600)
  self.scale = math.max(0.3, math.min(self.scale, 3))
end

function FrontraView:get_ground_y()
  return self.size.y * 0.78
end

function FrontraView:get_platform_rect(p)
  local gy = self:get_ground_y()
  local s = self:get_scale()
  return p.x - self.level_scroll, gy - p.y * self.size.y, p.w, 10 * s
end

function FrontraView:get_boss_hp()
  -- Boss HP = base * 1.5^(level-1), rounded
  local hp = cfg.boss_health
  for i = 2, self.level do
    hp = hp * 1.5
  end
  return math.floor(hp)
end

function FrontraView:get_enemy_hp()
  return 1 + math.floor((self.level - 1) / 2)
end

function FrontraView:get_spawn_interval()
  -- Enemies spawn faster each level (min 0.5s)
  return math.max(0.5, cfg.enemy_spawn_interval - (self.level - 1) * 0.15)
end

function FrontraView:get_enemy_speed()
  return cfg.enemy_speed + (self.level - 1) * 10
end

function FrontraView:step()
  if self.paused or self.game_over then return end

  -- Handle intro sequence
  if self.intro.phase ~= "playing" then
    self:update_intro(1 / 60)
    return
  end

  -- When won, run the celebration animation
  if self.won then
    self:update_celebration(1 / 60)
    return
  end

  -- Game complete victory
  if self.game_complete then
    self.win_time = (self.win_time or 0) + 1 / 60
    return
  end

  -- Final stage warning at level 7
  if self.final_warning_timer then
    self.final_warning_timer = self.final_warning_timer - 1 / 60
    if self.final_warning_timer <= 0 then
      self.final_warning_timer = nil
    end
    return
  end

  local dt = 1 / 60
  self.elapsed = self.elapsed + dt

  -- Auto-scroll
  self.level_scroll = self.level_scroll + cfg.scroll_speed * dt

  -- Boss trigger
  if self.level_scroll >= cfg.level_length - self.size.x and not self.boss_spawned then
    if self.level >= 7 then
      self:spawn_main_frame()
    else
      self:spawn_boss()
    end
  end

  -- Process input into player velocity
  self:process_input()

  -- Player physics
  self:update_player(dt)

  -- Shooting
  local wdef = weapons[self.player.weapon] or weapons.default
  self.player.shoot_timer = math.max(0, self.player.shoot_timer - dt)
  if self.input.shoot and self.player.shoot_timer <= 0 then
    self:fire_weapon()
    self.player.shoot_timer = wdef.fire_rate
  end

  -- Update objects
  self:update_bullets(dt)
  self:update_lasers(dt)
  self:update_bombs(dt)
  self:update_rockets(dt)
  self:update_waves(dt)
  self:update_pickups(dt)
  self:update_enemy_spawning(dt)
  self:update_enemies(dt)
  self:update_enemy_bullets(dt)
  if self.boss then self:update_boss(dt) end
  if self.main_frame then self:update_main_frame(dt) end
  self:update_particles(dt)
  self:check_collisions()

  -- Win check
  if self.main_frame and self.main_frame.dead and not self.game_complete then
    self.game_complete = true
    self.win_time = 0
  elseif self.boss and self.boss.dead and not self.won then
    self.won = true
    self.win_time = 0
  end
end

function FrontraView:update_intro(dt)
  local intro = self.intro
  intro.timer = intro.timer + dt

  if intro.phase == "logo" then
    -- "Presented by" fades in after 0.5s
    if intro.timer > 0.5 then
      self:move_towards(intro, "presented_alpha", 1, 0.05)
    end
    -- Logo characters fade in after 1.5s
    if intro.timer > 1.5 then
      self:move_towards(intro, "logo_alpha", 1, 0.05)
    end
    -- "Pragtical" text fades in after 3.0s
    if intro.timer > 3.0 then
      self:move_towards(intro, "pragtical_alpha", 1, 0.05)
    end
    -- Auto-advance after 6 seconds
    if intro.timer > 6.0 then
      self:advance_intro()
    end
  elseif intro.phase == "story" then
    self:move_towards(intro, "story_alpha", 1, 0.05)
    -- Auto-advance slide after 4 seconds
    if intro.timer > 4.0 then
      self:advance_intro()
    end
  elseif intro.phase == "start" then
    intro.start_timer = intro.start_timer + dt
  end
end

function FrontraView:advance_intro()
  local intro = self.intro
  if intro.phase == "logo" then
    intro.phase = "story"
    intro.timer = 0
    intro.presented_alpha = 1
    intro.logo_alpha = 1
    intro.pragtical_alpha = 1
    intro.story_alpha = 0
    intro.story_slide = 1
  elseif intro.phase == "story" then
    if intro.story_slide < #story_slides then
      intro.story_slide = intro.story_slide + 1
      intro.story_alpha = 0
      intro.timer = 0
    else
      intro.phase = "start"
      intro.timer = 0
      intro.start_timer = 0
      intro.player_x = 0
    end
  elseif intro.phase == "start" then
    intro.phase = "playing"
    core.redraw = true
  end
end

function FrontraView:process_input()
  local p = self.player
  if self.input.left then
    p.vx = -cfg.player_speed
    p.facing = -1
  elseif self.input.right then
    p.vx = cfg.player_speed
    p.facing = 1
  else
    p.vx = 0
  end
  if self.input.jump and p.on_ground then
    p.vy = cfg.jump_velocity
    p.on_ground = false
    self.input.jump = false
  end
end

function FrontraView:update_celebration(dt)
  local p = self.player
  p.vx = 0
  p.vy = 0

  self.win_time = (self.win_time or 0) + dt

  -- Rapidly cycle through animation frames
  p.anim_timer = p.anim_timer + dt
  if p.anim_timer > 0.08 then
    p.anim_timer = 0
    p.anim_frame = (p.anim_frame + 1) % 4
  end

  -- Alternate facing direction every 0.4 seconds
  p.facing = (math.floor(self.win_time / 0.4) % 2 == 0) and 1 or -1

  -- Fire celebratory bullets upward
  p.shoot_timer = p.shoot_timer - dt
  if p.shoot_timer <= 0 then
    local s = self:get_scale()
    table.insert(self.bullets, {
      x = p.x + (p.facing > 0 and p.w or 0),
      y = p.y + p.h * 0.35,
      vx = (math.random() - 0.5) * 300,
      vy = -math.random() * 300 - 100,
      w = 6 * s, h = 3 * s,
      life = 1.5,
    })
    p.shoot_timer = 0.15
  end

  -- Spawn sparkle particles
  if math.random() < 0.3 then
    self:spawn_particles(
      p.x + math.random() * p.w,
      p.y,
      2,
      self.level_boss_color or C.win_text
    )
  end

  -- Fireworks in the sky
  if math.random() < 0.08 then
    local s = self:get_scale()
    local fw = {
      x = math.random() * self.size.x,
      y = math.random() * self.size.y * 0.4,
      vx = 0,
      vy = 0,
      life = 0.6 + math.random() * 0.8,
      color = random_level_color(),
      size = (4 + math.random() * 8) * s,
      exploded = true,
    }
    table.insert(self.fireworks, fw)
  end

  -- After 5 seconds, advance to next level
  if self.win_time >= 5.0 then
    self:level_up()
  end
end

function FrontraView:level_up()
  self.level = self.level + 1

  -- Generate new level colors
  self:generate_level_colors()

  -- Replenish and increase health: max_hp = 10 * self.level
  -- level 2 (first clear) -> max_hp = 20 = 10 more than base
  self.player.max_hp = 10 * self.level
  self.player.hp = self.player.max_hp

  -- Increase simultaneous enemy cap by 1.5x each level
  self.max_simultaneous_enemies = math.floor(self.max_simultaneous_enemies * 1.5)
  self.level_scroll = 0
  self.boss_spawned = false
  self.boss = nil
  self.spawn_timer = 0
  self.spawn_index = 1

  -- Clear old enemies, bullets and fireworks but keep the player and particles
  self.bullets = {}
  self.enemies = {}
  self.enemy_bullets = {}
  self.fireworks = {}

  self.won = false

  -- Trigger final stage warning at level 7
  if self.level >= 7 then
    self.final_warning_timer = 3.0
  end
end

function FrontraView:update_player(dt)
  local p = self.player
  local gy = self:get_ground_y()
  local s = self:get_scale()

  -- Decrement invincibility timer
  if p.invincible > 0 then
    p.invincible = p.invincible - dt
  end

  p.vy = p.vy + cfg.gravity * dt
  p.x = p.x + p.vx * dt
  p.y = p.y + p.vy * dt

  -- Horizontal bounds (margins scale with view)
  local margin = 20 * s
  p.x = math.max(margin, math.min(p.x, self.size.x - p.w - margin))

  -- Ground
  if p.y + p.h >= gy then
    p.y = gy - p.h
    p.vy = 0
    p.on_ground = true
  else
    p.on_ground = false
  end

  -- Platforms
  for _, pl in ipairs(platforms) do
    local px, py, pw = self:get_platform_rect(pl)
    if px + pw > 0 and px < self.size.x then
      local plat_h = 10 * s
      if p.vy >= 0
        and p.x + p.w > px and p.x < px + pw
        and p.y + p.h >= py and p.y + p.h <= py + plat_h + p.vy * dt + 2
      then
        p.y = py - p.h
        p.vy = 0
        p.on_ground = true
      end
    end
  end

  -- Animation
  if math.abs(p.vx) > 0 then
    p.anim_timer = p.anim_timer + dt
    if p.anim_timer > 0.15 then
      p.anim_timer = 0
      p.anim_frame = (p.anim_frame + 1) % 4
    end
  else
    p.anim_frame = 0
    p.anim_timer = 0
  end
end

function FrontraView:fire_weapon()
  local p = self.player
  local wdef = weapons[p.weapon] or weapons.default

  -- Consume ammo if limited
  if wdef.ammo > 0 then
    p.weapon_ammo = p.weapon_ammo - 1
    if p.weapon_ammo <= 0 then
      p.weapon = "default"
      p.weapon_ammo = -1
    end
  end

  if wdef.projectile == "bullet" then
    self:fire_bullet()
  elseif wdef.projectile == "laser" then
    self:fire_laser()
  elseif wdef.projectile == "triple" then
    self:fire_triple()
  elseif wdef.projectile == "bomb" then
    self:fire_bomb()
  elseif wdef.projectile == "homing" then
    self:fire_rocket()
  elseif wdef.projectile == "wave" then
    self:fire_wave()
  end
end

function FrontraView:fire_bullet()
  local p = self.player
  local s = self:get_scale()
  table.insert(self.bullets, {
    x = p.x + (p.facing > 0 and p.w or 0),
    y = p.y + p.h * 0.35,
    vx = cfg.bullet_speed * p.facing,
    vy = 0,
    w = 6 * s, h = 3 * s,
    life = 2.0,
  })
end

function FrontraView:fire_triple()
  local p = self.player
  local s = self:get_scale()
  local gun_x = p.x + (p.facing > 0 and p.w or 0)
  local gun_y = p.y + p.h * 0.35
  local speed = cfg.bullet_speed * p.facing
  local angles = { -0.2, 0, 0.2 }
  for _, ang in ipairs(angles) do
    table.insert(self.bullets, {
      x = gun_x, y = gun_y,
      vx = speed * math.cos(ang),
      vy = speed * math.sin(ang),
      w = 6 * s, h = 3 * s,
      life = 1.5,
    })
  end
end

function FrontraView:fire_laser()
  local p = self.player
  local s = self:get_scale()
  local gun_x = p.x + (p.facing > 0 and p.w or 0)
  local gun_y = p.y + p.h * 0.35 + 1 * s
  local end_x = p.facing > 0 and self.size.x or 0
  table.insert(self.lasers, {
    x1 = gun_x, y1 = gun_y,
    x2 = end_x, y2 = gun_y,
    w = 3 * s,
    life = 0.08,
  })
  -- Damage all enemies in the beam path
  local ecount = 0
  for _, e in ipairs(self.enemies) do
    if not e.dead and ecount < 5 then
      if self:rect_beam_overlap(e.x, e.y, e.w, e.h, gun_x, gun_y, end_x, gun_y, 3 * s) then
        e.hp = e.hp - 2
        self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 3, C.laser)
        if e.hp <= 0 then
          e.dead = true
          self.score = self.score + 100 * self.level
          self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 8, self.level_enemy_color)
          self:spawn_weapon_pickup(e.x + e.w / 2, e.y + e.h / 2)
        end
        ecount = ecount + 1
      end
    end
  end
  -- Also hit boss (no piercing limit)
  if self.boss and not self.boss.dead then
    if self:rect_beam_overlap(self.boss.x, self.boss.y, self.boss.w, self.boss.h, gun_x, gun_y, end_x, gun_y, 3 * s) then
      self.boss.hp = self.boss.hp - 2
      self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 3, C.laser)
      if self.boss.hp <= 0 then
        self.boss.dead = true
        self.boss.death_timer = 0
        self.score = self.score + 1000 * self.level
        self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 20, self.level_boss_color)
      end
    end
  end
  -- Also hit main frame
  if self.main_frame and not self.main_frame.dead then
    if self:rect_beam_overlap(self.main_frame.x, self.main_frame.y, self.main_frame.w, self.main_frame.h, gun_x, gun_y, end_x, gun_y, 3 * s) then
      self.main_frame.hp = self.main_frame.hp - 2
      self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 3, C.laser)
      if self.main_frame.hp <= 0 then
        self.main_frame.dead = true
        self.main_frame.death_timer = 0
        self.score = self.score + 5000
        self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 40, C.win_text)
      end
    end
  end
end

function FrontraView:fire_bomb()
  local p = self.player
  local s = self:get_scale()
  local gun_x = p.x + (p.facing > 0 and p.w or 0)
  local gun_y = p.y + p.h * 0.35
  table.insert(self.bombs, {
    x = gun_x, y = gun_y,
    vx = 250 * p.facing, vy = -150,
    w = 10 * s, h = 10 * s,
    life = 3.0,
    bounces = 4,
  })
end

function FrontraView:fire_rocket()
  local p = self.player
  local s = self:get_scale()
  local gun_x = p.x + (p.facing > 0 and p.w or 0)
  local gun_y = p.y + p.h * 0.35
  table.insert(self.rockets, {
    x = gun_x, y = gun_y,
    vx = 150 * p.facing, vy = 0,
    w = 8 * s, h = 4 * s,
    life = 3.0,
    steer_timer = 0.15,
  })
end

function FrontraView:fire_wave()
  local s = self:get_scale()
  table.insert(self.waves, {
    x = self.player.x + self.player.w / 2,
    y = self.player.y + self.player.h / 2,
    r = 20 * s,
    max_r = 120 * s,
    life = 0.6,
    hit = {}, -- enemies already hit
  })
end

function FrontraView:rect_beam_overlap(rx, ry, rw, rh, bx1, by1, bx2, by2, bw)
  -- Simplified: beam is a thick horizontal line; check rect against beam area
  if bx1 > bx2 then bx1, bx2 = bx2, bx1 end
  local y_gap = math.abs(ry + rh / 2 - by1)
  return rx + rw > bx1 and rx < bx2 and y_gap < bw / 2 + rh / 2
end

function FrontraView:update_bullets(dt)
  for i = #self.bullets, 1, -1 do
    local b = self.bullets[i]
    b.x = b.x + b.vx * dt
    b.life = b.life - dt
    if b.life <= 0 or b.x < 0 or b.x > self.size.x then
      table.remove(self.bullets, i)
    end
  end
end

function FrontraView:update_enemy_spawning(dt)
  local interval = self:get_spawn_interval()

  -- Continuous spawn: once all fixed spawn points are exhausted, keep spawning
  -- enemies at random positions until the boss area
  if self.spawn_index > #enemy_spawns then
    self.continuous_spawn = true
  end

  -- Cap check: don't spawn if we already have enough enemies on screen
  local live_count = 0
  for _, e in ipairs(self.enemies) do
    if not e.dead then live_count = live_count + 1 end
  end
  if live_count >= self.max_simultaneous_enemies then return end

  self.spawn_timer = self.spawn_timer + dt
  if self.spawn_timer >= interval then
    self.spawn_timer = 0

    local sp, sx

    if self.continuous_spawn then
      -- Random spawn at a horizontal position slightly ahead, at random height
      if self.boss_spawned then return end
      local ahead = self.level_scroll + self.size.x * (0.5 + math.random() * 0.5)
      if ahead >= cfg.level_length - 200 then return end
      sp = { x = ahead, y = 0.35 + math.random() * 0.4 }
      sx = sp.x - self.level_scroll
    else
      -- Fixed spawn point
      sp = enemy_spawns[self.spawn_index]
      sx = sp.x - self.level_scroll
      if sx <= 0 or sx > self.size.x + 100 then
        self.spawn_index = self.spawn_index + 1
        return
      end
    end

    local gy = self:get_ground_y()
    local s = self:get_scale()
    table.insert(self.enemies, {
      x = math.min(sx, self.size.x - 30 * s),
      y = gy - sp.y * self.size.y,
      w = 16 * s, h = 20 * s,
      speed = self:get_enemy_speed(),
      vy = 0,
      hp = self:get_enemy_hp(),
      shoot_timer = 1.0 + math.random() * 1.5,
      anim_frame = 0, anim_timer = 0,
      dead = false,
    })
    self.spawn_index = self.spawn_index + 1
  end
end

function FrontraView:update_enemies(dt)
  local gy = self:get_ground_y()
  local s = self:get_scale()
  -- Enemies use stronger gravity so they land quickly after spawning
  local enemy_gravity = cfg.gravity * 1.8
  for i = #self.enemies, 1, -1 do
    local e = self.enemies[i]
    if e.dead then
      table.remove(self.enemies, i)
    elseif e.x < -50 then
      table.remove(self.enemies, i)
    else
      local px = self.player.x + self.player.w / 2
      local ex = e.x + e.w / 2
      local dx = px - ex
      local dist = math.abs(dx)

      -- Apply gravity (stronger for enemies)
      e.vy = e.vy + enemy_gravity * dt
      e.y = e.y + e.vy * dt

      -- Move toward player horizontally
      if dist > 0 then
        local move = e.speed * dt
        e.x = e.x + (dx / dist) * move
      end

      -- Ground collision
      if e.y + e.h >= gy then
        e.y = gy - e.h
        e.vy = 0
      end

      e.shoot_timer = e.shoot_timer - dt
      if e.shoot_timer <= 0 and e.x > 0 and e.x < self.size.x then
        -- Aim bullet at player
        local px = self.player.x + self.player.w / 2
        local py = self.player.y + self.player.h * 0.4
        local ex = e.x
        local ey = e.y + e.h * 0.4
        local bdx = px - ex
        local bdy = py - ey
        local bdist = math.sqrt(bdx * bdx + bdy * bdy)
        if bdist > 0 then
          table.insert(self.enemy_bullets, {
            x = e.x, y = e.y + e.h * 0.4,
            vx = bdx / bdist * 200,
            vy = bdy / bdist * 200,
            w = 5 * s, h = 5 * s, life = 3.0,
          })
        end
        e.shoot_timer = 1.5 + math.random() * 2.0
      end

      e.anim_timer = e.anim_timer + dt
      if e.anim_timer > 0.2 then
        e.anim_timer = 0
        e.anim_frame = (e.anim_frame + 1) % 2
      end
    end
  end
end

function FrontraView:update_enemy_bullets(dt)
  for i = #self.enemy_bullets, 1, -1 do
    local b = self.enemy_bullets[i]
    b.x = b.x + b.vx * dt
    b.life = b.life - dt
    if b.life <= 0 or b.x < -10 or b.x > self.size.x + 10 then
      table.remove(self.enemy_bullets, i)
    end
  end
end

function FrontraView:update_fireworks(dt)
  for i = #self.fireworks, 1, -1 do
    local fw = self.fireworks[i]
    fw.life = fw.life - dt
    if fw.life <= 0 then
      table.remove(self.fireworks, i)
    end
  end
end

function FrontraView:update_lasers(dt)
  for i = #self.lasers, 1, -1 do
    local l = self.lasers[i]
    l.life = l.life - dt
    if l.life <= 0 then
      table.remove(self.lasers, i)
    end
  end
end

function FrontraView:update_bombs(dt)
  local gy = self:get_ground_y()
  for i = #self.bombs, 1, -1 do
    local b = self.bombs[i]
    b.vy = b.vy + cfg.gravity * dt
    b.x = b.x + b.vx * dt
    b.y = b.y + b.vy * dt

    -- Ground collision / bounce
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = -math.abs(b.vy) * 0.4
      b.bounces = b.bounces - 1
    end

    -- Platform collision
    for _, pl in ipairs(platforms) do
      local px, py, pw = self:get_platform_rect(pl)
      local plat_h = 10 * self:get_scale()
      if px + pw > 0 and px < self.size.x then
        if b.y + b.h >= py and b.y + b.h <= py + plat_h + b.vy * dt + 2
          and b.x + b.w > px and b.x < px + pw
        then
          b.y = py - b.h
          b.vy = -math.abs(b.vy) * 0.4
          b.bounces = b.bounces - 1
        end
      end
    end

    -- Off-screen or out of bounces
    b.life = b.life - dt
    if b.life <= 0 or b.x < -50 or b.x > self.size.x + 50 or b.bounces <= 0 then
      if b.bounces <= 0 or b.life <= 0 then
        -- Explode on expiration
        self:bomb_explode(b)
      end
      table.remove(self.bombs, i)
    end
  end
end

function FrontraView:update_rockets(dt)
  for i = #self.rockets, 1, -1 do
    local r = self.rockets[i]
    r.life = r.life - dt
    if r.life <= 0 or r.x < -20 or r.x > self.size.x + 20 then
      table.remove(self.rockets, i)
    else
      -- Homing: steer toward nearest enemy after short delay
      r.steer_timer = r.steer_timer - dt
      if r.steer_timer <= 0 then
        local best_dist = math.huge
        local best_enemy = nil
        for _, e in ipairs(self.enemies) do
          if not e.dead and e.x > 0 and e.x < self.size.x then
            local dx = e.x + e.w / 2 - r.x
            local dy = e.y + e.h / 2 - r.y
            local dist = dx * dx + dy * dy
            if dist < best_dist then
              best_dist = dist
              best_enemy = e
            end
          end
        end
        if best_enemy then
          local dx = best_enemy.x + best_enemy.w / 2 - r.x
          local dy = best_enemy.y + best_enemy.h / 2 - r.y
          local dist = math.sqrt(dx * dx + dy * dy)
          if dist > 0 then
            local steer_speed = 200
            r.vx = r.vx + (dx / dist * steer_speed - r.vx) * 0.15
            r.vy = r.vy + (dy / dist * steer_speed - r.vy) * 0.15
          end
          r.steer_timer = 0.08
        end
      end
      r.x = r.x + r.vx * dt
      r.y = r.y + r.vy * dt
    end
  end
end

function FrontraView:update_waves(dt)
  for i = #self.waves, 1, -1 do
    local w = self.waves[i]
    w.life = w.life - dt
    local progress = 1 - w.life / 0.6
    w.r = 20 * self:get_scale() + progress * (w.max_r - 20 * self:get_scale())

    -- Damage enemies touched
    for _, e in ipairs(self.enemies) do
      if not e.dead and not w.hit[e] then
        local edx = e.x + e.w / 2 - w.x
        local edy = e.y + e.h / 2 - w.y
        local edist = math.sqrt(edx * edx + edy * edy)
        if edist < w.r + e.w / 2 then
          e.hp = e.hp - 3
          self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 3, C.wave_color)
          if e.hp <= 0 then
            e.dead = true
            self.score = self.score + 100 * self.level
            self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 8, self.level_enemy_color)
            self:spawn_weapon_pickup(e.x + e.w / 2, e.y + e.h / 2)
          end
          w.hit[e] = true
        end
      end
    end
    -- Hit boss
    if self.boss and not self.boss.dead and not w.hit[self.boss] then
      local bdx = self.boss.x + self.boss.w / 2 - w.x
      local bdy = self.boss.y + self.boss.h / 2 - w.y
      local bdist = math.sqrt(bdx * bdx + bdy * bdy)
      if bdist < w.r + self.boss.w / 2 then
        self.boss.hp = self.boss.hp - 3
        self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 3, C.wave_color)
        if self.boss.hp <= 0 then
          self.boss.dead = true
          self.boss.death_timer = 0
          self.score = self.score + 1000 * self.level
          self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 20, self.level_boss_color)
        end
        w.hit[self.boss] = true
      end
    end
    -- Hit main frame
    if self.main_frame and not self.main_frame.dead and not w.hit[self.main_frame] then
      local mdx = self.main_frame.x + self.main_frame.w / 2 - w.x
      local mdy = self.main_frame.y + self.main_frame.h / 2 - w.y
      local mdist = math.sqrt(mdx * mdx + mdy * mdy)
      if mdist < w.r + self.main_frame.w / 2 then
        self.main_frame.hp = self.main_frame.hp - 3
        self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 3, C.wave_color)
        if self.main_frame.hp <= 0 then
          self.main_frame.dead = true
          self.main_frame.death_timer = 0
          self.score = self.score + 5000
          self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 40, C.win_text)
        end
        w.hit[self.main_frame] = true
      end
    end

    if w.life <= 0 then
      table.remove(self.waves, i)
    end
  end
end

function FrontraView:update_pickups(dt)
  local gy = self:get_ground_y()
  local p = self.player
  for i = #self.pickups, 1, -1 do
    local pu = self.pickups[i]
    pu.vy = pu.vy + cfg.gravity * dt
    pu.y = pu.y + pu.vy * dt
    if pu.y + pu.h >= gy then
      pu.y = gy - pu.h
      pu.vy = 0
    end
    pu.life = pu.life - dt
    if pu.life <= 0 then
      table.remove(self.pickups, i)
    elseif self:rects_overlap(p.x, p.y, p.w, p.h, pu.x, pu.y, pu.w, pu.h) then
      self:collect_pickup(pu)
      table.remove(self.pickups, i)
    end
  end
end

function FrontraView:bomb_explode(b)
  -- Damage all enemies near the bomb
  for _, e in ipairs(self.enemies) do
    if not e.dead then
      local dx = e.x + e.w / 2 - b.x
      local dy = e.y + e.h / 2 - b.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist < 80 * self:get_scale() then
        e.hp = e.hp - 3
        self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 3, C.bomb_color)
        if e.hp <= 0 then
          e.dead = true
          self.score = self.score + 100 * self.level
          self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 8, self.level_enemy_color)
          self:spawn_weapon_pickup(e.x + e.w / 2, e.y + e.h / 2)
        end
      end
    end
  end
  -- Hit boss
  if self.boss and not self.boss.dead then
    local dx = self.boss.x + self.boss.w / 2 - b.x
    local dy = self.boss.y + self.boss.h / 2 - b.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 80 * self:get_scale() then
      self.boss.hp = self.boss.hp - 3
      self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 5, C.bomb_color)
      if self.boss.hp <= 0 then
        self.boss.dead = true
        self.boss.death_timer = 0
        self.score = self.score + 1000 * self.level
        self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 20, self.level_boss_color)
      end
    end
  end
  -- Hit main frame
  if self.main_frame and not self.main_frame.dead then
    local dx = self.main_frame.x + self.main_frame.w / 2 - b.x
    local dy = self.main_frame.y + self.main_frame.h / 2 - b.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 80 * self:get_scale() then
      self.main_frame.hp = self.main_frame.hp - 3
      self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 5, C.bomb_color)
      if self.main_frame.hp <= 0 then
        self.main_frame.dead = true
        self.main_frame.death_timer = 0
        self.score = self.score + 5000
        self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 40, C.win_text)
      end
    end
  end
  self:spawn_particles(b.x, b.y, 10, C.bomb_color)
end

function FrontraView:collect_pickup(pu)
  local wdef = weapons[pu.weapon]
  if not wdef then return end
  local p = self.player
  if p.weapon == pu.weapon then
    -- Add ammo to current weapon
    p.weapon_ammo = p.weapon_ammo + wdef.ammo
  else
    -- Switch weapon
    p.weapon = pu.weapon
    p.weapon_ammo = wdef.ammo
    p.shoot_timer = 0
  end
end

function FrontraView:spawn_weapon_pickup(x, y)
  if math.random() > cfg.weapon_drop_chance then return end
  local wp = weapon_drop_list[math.random(#weapon_drop_list)]
  local s = self:get_scale()
  table.insert(self.pickups, {
    x = x - 6 * s, y = y,
    w = 12 * s, h = 12 * s,
    vy = -80,
    life = 8.0,
    weapon = wp,
  })
end

function FrontraView:spawn_boss()
  self.boss_spawned = true
  local gy = self:get_ground_y()
  local s = self:get_scale()
  self.boss = {
    x = self.size.x - 80 * s, y = gy - 80 * s,
    w = 40 * s, h = 40 * s,
    vx = 0, vy = 0,
    hp = self:get_boss_hp(), max_hp = self:get_boss_hp(),
    phase = 0,
    cycle_timer = 0,
    shoot_timer = 0,
    jump_timer = 0,
    cycle_state = "enter", -- enter -> idle -> run_left -> shoot_right -> run_right -> shoot_left -> ...
    dead = false, death_timer = 0,
    anim_frame = 0, anim_timer = 0,
  }
end

function FrontraView:spawn_main_frame()
  self.main_frame_spawned = true
  self.boss_spawned = true -- prevent regular boss spawn too
  local gy = self:get_ground_y()
  local s = self:get_scale()
  -- Position on the right side, large structure
  self.main_frame = {
    x = self.size.x - 220 * s, y = gy - 180 * s,
    w = 160 * s, h = 180 * s,
    hp = self:get_boss_hp() * 3,
    max_hp = self:get_boss_hp() * 3,
    shoot_timer = 0,
    cycle_timer = 0,
    cycle_phase = 0,  -- 0=lower, 1=gap1, 2=middle, 3=gap2, 4=upper, 5=cooldown
    burst_count = 0,
    dead = false,
    death_timer = 0,
  }
end

function FrontraView:update_main_frame(dt)
  local mf = self.main_frame
  if mf.dead then
    mf.death_timer = mf.death_timer + dt
    return
  end

  local s = self:get_scale()
  local phases = {
    { name = "lower",  dur = 0.6, rate = 0.12 },
    { name = "gap1",   dur = 0.30, rate = 99 },
    { name = "middle", dur = 0.6, rate = 0.12 },
    { name = "gap2",   dur = 0.30, rate = 99 },
    { name = "upper",  dur = 0.5, rate = 0.18 },
    { name = "cooldown", dur = 1.5, rate = 99 },
  }

  mf.cycle_timer = mf.cycle_timer + dt
  local ph = phases[mf.cycle_phase + 1]

  if mf.cycle_timer >= ph.dur then
    mf.cycle_timer = 0
    mf.burst_count = 0
    mf.cycle_phase = (mf.cycle_phase + 1) % #phases
  else
    -- Fire bullets according to phase
    mf.shoot_timer = mf.shoot_timer - dt
    if mf.shoot_timer <= 0 and ph.rate < 10 then
      mf.shoot_timer = ph.rate
      local gun_y_offsets = { 0.18, 0.50, 0.88 } -- upper (cosmetic), middle (jump height), lower (walk height)
      local gun_idx
      if ph.name == "lower" then gun_idx = 3
      elseif ph.name == "middle" then gun_idx = 2
      elseif ph.name == "upper" then gun_idx = 1
      else gun_idx = nil end

      if gun_idx then
        local gun_y = mf.y + mf.h * gun_y_offsets[gun_idx]
        local bx = mf.x - 10 * s  -- fire left toward player
        local by = gun_y
        -- Fire toward player's current Y
        local px = self.player.x + self.player.w / 2
        local py = self.player.y + self.player.h * 0.4
        local dx = px - bx
        local dy = py - by
        local dist = math.sqrt(dx * dx + dy * dy)
        local speed = 220
        if dist > 0 then
          local vx = dx / dist * speed
          local vy = dy / dist * speed
          -- Fire a burst of 2 bullets slightly spread
          for j = -1, 1, 2 do
            local ang = j * 0.08
            local cos_a, sin_a = math.cos(ang), math.sin(ang)
            table.insert(self.enemy_bullets, {
              x = bx, y = by,
              vx = vx * cos_a - vy * sin_a,
              vy = vx * sin_a + vy * cos_a,
              w = 8 * s, h = 6 * s,
              life = 3.5,
            })
          end
        end
      end
    end
  end
end

function FrontraView:update_boss(dt)
  local b = self.boss
  if b.dead then
    b.death_timer = b.death_timer + dt
    return
  end

  local gy = self:get_ground_y()
  local s = self:get_scale()

  if b.phase == 0 then
    -- Enter from the right
    b.x = b.x - 120 * dt
    if b.x <= self.size.x - 100 * s then
      b.phase = 1
      b.cycle_state = "idle"
      b.cycle_timer = 0
    end
    return
  end

  if b.cycle_state == "idle" then
    -- Wait 5 seconds, shoot at the player during this time
    b.cycle_timer = b.cycle_timer + dt

    -- Gravity and ground
    b.vy = b.vy + cfg.gravity * dt
    b.y = b.y + b.vy * dt
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = 0
      -- Occasional jump while idle
      if math.random() < 0.005 then
        b.vy = -350
      end
    end

    b.shoot_timer = b.shoot_timer - dt
    if b.shoot_timer <= 0 then
      local dx = self.player.x - b.x
      local dy = self.player.y - b.y
      local dist = math.sqrt(dx * dx + dy * dy)
      if dist > 0 then
        table.insert(self.enemy_bullets, {
          x = b.x + b.w / 2, y = b.y + b.h / 2,
          vx = dx / dist * 250, vy = dy / dist * 250,
          w = 6 * s, h = 6 * s, life = 4.0,
        })
      end
      b.shoot_timer = 0.8 + math.random() * 0.6
    end
    if b.cycle_timer >= 5.0 then
      b.cycle_state = "run_left"
      b.cycle_timer = 0
    end
    return
  end

  -- Cycle timer
  b.cycle_timer = b.cycle_timer + dt

  local left_margin = 50 * s
  local right_margin = self.size.x - b.w - 20 * s
  local left_x = left_margin
  local right_x = right_margin
  local run_speed = 150

  if b.cycle_state == "run_left" then
    -- Run to the left for 5 seconds, shooting while running
    b.vy = b.vy + cfg.gravity * dt
    b.y = b.y + b.vy * dt
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = 0
    end
    b.x = b.x - run_speed * dt
    b.x = math.max(left_x, b.x)

    b.shoot_timer = b.shoot_timer - dt
    if b.shoot_timer <= 0 then
      table.insert(self.enemy_bullets, {
        x = b.x + b.w / 2, y = b.y + b.h / 2,
        vx = -250, vy = 0,
        w = 6 * s, h = 6 * s, life = 4.0,
      })
      b.shoot_timer = 0.6
    end

    if b.cycle_timer >= 5.0 or b.x <= left_x then
      b.cycle_state = "shoot_right"
      b.cycle_timer = 0
    end
  elseif b.cycle_state == "shoot_right" then
    -- Stay at left edge, shoot to the right, jump every ~2s
    b.x = left_x

    b.vy = b.vy + cfg.gravity * dt
    b.y = b.y + b.vy * dt
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = 0
    end

    b.jump_timer = b.jump_timer + dt
    if b.jump_timer >= 2.0 and b.y + b.h >= gy - 2 then
      b.vy = -400
      b.jump_timer = 0
    end

    b.shoot_timer = b.shoot_timer - dt
    if b.shoot_timer <= 0 then
      table.insert(self.enemy_bullets, {
        x = b.x + b.w / 2, y = b.y + b.h / 2,
        vx = 250, vy = 0,
        w = 6 * s, h = 6 * s, life = 4.0,
      })
      b.shoot_timer = 0.6
    end
    if b.cycle_timer >= 5.0 then
      b.cycle_state = "run_right"
      b.cycle_timer = 0
    end
  elseif b.cycle_state == "run_right" then
    -- Run back to the right for 5 seconds, shooting while running
    b.vy = b.vy + cfg.gravity * dt
    b.y = b.y + b.vy * dt
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = 0
    end
    b.x = b.x + run_speed * dt
    b.x = math.min(right_x, b.x)

    b.shoot_timer = b.shoot_timer - dt
    if b.shoot_timer <= 0 then
      table.insert(self.enemy_bullets, {
        x = b.x + b.w / 2, y = b.y + b.h / 2,
        vx = 250, vy = 0,
        w = 6 * s, h = 6 * s, life = 4.0,
      })
      b.shoot_timer = 0.6
    end

    if b.cycle_timer >= 5.0 or b.x >= right_x then
      b.cycle_state = "shoot_left"
      b.cycle_timer = 0
    end
  elseif b.cycle_state == "shoot_left" then
    -- Stay at right edge, shoot to the left, jump every ~2s
    b.x = right_x

    b.vy = b.vy + cfg.gravity * dt
    b.y = b.y + b.vy * dt
    if b.y + b.h >= gy then
      b.y = gy - b.h
      b.vy = 0
    end

    b.jump_timer = b.jump_timer + dt
    if b.jump_timer >= 2.0 and b.y + b.h >= gy - 2 then
      b.vy = -400
      b.jump_timer = 0
    end

    b.shoot_timer = b.shoot_timer - dt
    if b.shoot_timer <= 0 then
      table.insert(self.enemy_bullets, {
        x = b.x + b.w / 2, y = b.y + b.h / 2,
        vx = -250, vy = 0,
        w = 6 * s, h = 6 * s, life = 4.0,
      })
      b.shoot_timer = 0.6
    end
    if b.cycle_timer >= 5.0 then
      b.cycle_state = "run_left"
      b.cycle_timer = 0
    end
  end

  -- Random jump during idle (early-return'd above) or running phases
  if (b.cycle_state == "run_left" or b.cycle_state == "run_right")
    and b.y + b.h >= gy - 2 and math.random() < 0.005 then
    b.vy = -350
  end

  b.anim_timer = b.anim_timer + dt
  if b.anim_timer > 0.15 then
    b.anim_timer = 0
    b.anim_frame = (b.anim_frame + 1) % 2
  end
end

function FrontraView:update_particles(dt)
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + 200 * dt
    p.life = p.life - dt
    if p.life <= 0 then table.remove(self.particles, i) end
  end
end

function FrontraView:spawn_particles(x, y, count, color)
  local s = self:get_scale()
  for i = 1, count do
    table.insert(self.particles, {
      x = x, y = y,
      vx = (math.random() - 0.5) * 300,
      vy = (math.random() - 0.5) * 300 - 100,
      life = 0.3 + math.random() * 0.4,
      color = color,
      size = (2 + math.random() * 3) * s,
    })
  end
end

function FrontraView:check_collisions()
  local p = self.player

  -- Player bullets vs enemies
  for bi = #self.bullets, 1, -1 do
    local b = self.bullets[bi]
    for ei = #self.enemies, 1, -1 do
      local e = self.enemies[ei]
      if not e.dead and self:rects_overlap(b.x, b.y, b.w, b.h, e.x, e.y, e.w, e.h) then
        e.hp = e.hp - 1
        self:spawn_particles(b.x, b.y, 4, C.bullet)
        table.remove(self.bullets, bi)
        if e.hp <= 0 then
          e.dead = true
          self.score = self.score + 100 * self.level
          self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 8, self.level_enemy_color)
          self:spawn_weapon_pickup(e.x + e.w / 2, e.y + e.h / 2)
        end
        break
      end
    end
  end

  -- Player bullets vs boss
  if self.boss and not self.boss.dead then
    for bi = #self.bullets, 1, -1 do
      local b = self.bullets[bi]
      if self:rects_overlap(b.x, b.y, b.w, b.h, self.boss.x, self.boss.y, self.boss.w, self.boss.h) then
        self.boss.hp = self.boss.hp - 1
        self:spawn_particles(b.x, b.y, 4, C.bullet)
        table.remove(self.bullets, bi)
        if self.boss.hp <= 0 then
          self.boss.dead = true
          self.boss.death_timer = 0
          self.score = self.score + 1000 * self.level
          self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 20, self.level_boss_color)
        end
      end
    end
  end

  -- Player bullets vs main frame
  if self.main_frame and not self.main_frame.dead then
    for bi = #self.bullets, 1, -1 do
      local b = self.bullets[bi]
      if self:rects_overlap(b.x, b.y, b.w, b.h, self.main_frame.x, self.main_frame.y, self.main_frame.w, self.main_frame.h) then
        self.main_frame.hp = self.main_frame.hp - 1
        self:spawn_particles(b.x, b.y, 4, C.bullet)
        table.remove(self.bullets, bi)
        if self.main_frame.hp <= 0 then
          self.main_frame.dead = true
          self.main_frame.death_timer = 0
          self.score = self.score + 5000
          self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 40, C.win_text)
        end
      end
    end
  end

  -- Bombs vs enemies
  for bi = #self.bombs, 1, -1 do
    local b = self.bombs[bi]
    local hit = false
    for ei = #self.enemies, 1, -1 do
      local e = self.enemies[ei]
      if not e.dead and self:rects_overlap(b.x, b.y, b.w, b.h, e.x, e.y, e.w, e.h) then
        self:bomb_explode(b)
        table.remove(self.bombs, bi)
        hit = true
        break
      end
    end
    if hit then break end
  end

  -- Bombs vs boss
  if self.boss and not self.boss.dead then
    for bi = #self.bombs, 1, -1 do
      local b = self.bombs[bi]
      if self:rects_overlap(b.x, b.y, b.w, b.h, self.boss.x, self.boss.y, self.boss.w, self.boss.h) then
        self:bomb_explode(b)
        table.remove(self.bombs, bi)
      end
    end
  end

  -- Bombs vs main frame
  if self.main_frame and not self.main_frame.dead then
    for bi = #self.bombs, 1, -1 do
      local b = self.bombs[bi]
      if self:rects_overlap(b.x, b.y, b.w, b.h, self.main_frame.x, self.main_frame.y, self.main_frame.w, self.main_frame.h) then
        self:bomb_explode(b)
        table.remove(self.bombs, bi)
      end
    end
  end

  -- Rockets vs enemies
  for ri = #self.rockets, 1, -1 do
    local r = self.rockets[ri]
    local hit = false
    for ei = #self.enemies, 1, -1 do
      local e = self.enemies[ei]
      if not e.dead and self:rects_overlap(r.x, r.y, r.w, r.h, e.x, e.y, e.w, e.h) then
        e.hp = e.hp - 3
        self:spawn_particles(r.x, r.y, 6, C.rocket)
        if e.hp <= 0 then
          e.dead = true
          self.score = self.score + 100 * self.level
          self:spawn_particles(e.x + e.w / 2, e.y + e.h / 2, 8, self.level_enemy_color)
          self:spawn_weapon_pickup(e.x + e.w / 2, e.y + e.h / 2)
        end
        table.remove(self.rockets, ri)
        hit = true
        break
      end
    end
    if hit then break end
  end

  -- Rockets vs boss
  if self.boss and not self.boss.dead then
    for ri = #self.rockets, 1, -1 do
      local r = self.rockets[ri]
      if self:rects_overlap(r.x, r.y, r.w, r.h, self.boss.x, self.boss.y, self.boss.w, self.boss.h) then
        self.boss.hp = self.boss.hp - 3
        self:spawn_particles(r.x, r.y, 6, C.rocket)
        if self.boss.hp <= 0 then
          self.boss.dead = true
          self.boss.death_timer = 0
          self.score = self.score + 1000 * self.level
          self:spawn_particles(self.boss.x + self.boss.w / 2, self.boss.y + self.boss.h / 2, 20, self.level_boss_color)
        end
        table.remove(self.rockets, ri)
      end
    end
  end

  -- Rockets vs main frame
  if self.main_frame and not self.main_frame.dead then
    for ri = #self.rockets, 1, -1 do
      local r = self.rockets[ri]
      if self:rects_overlap(r.x, r.y, r.w, r.h, self.main_frame.x, self.main_frame.y, self.main_frame.w, self.main_frame.h) then
        self.main_frame.hp = self.main_frame.hp - 3
        self:spawn_particles(r.x, r.y, 6, C.rocket)
        if self.main_frame.hp <= 0 then
          self.main_frame.dead = true
          self.main_frame.death_timer = 0
          self.score = self.score + 5000
          self:spawn_particles(self.main_frame.x + self.main_frame.w / 2, self.main_frame.y + self.main_frame.h / 2, 40, C.win_text)
        end
        table.remove(self.rockets, ri)
      end
    end
  end

  -- Enemy bullets vs player
  for bi = #self.enemy_bullets, 1, -1 do
    local b = self.enemy_bullets[bi]
    if self:rects_overlap(b.x, b.y, b.w, b.h, p.x, p.y, p.w, p.h) then
      table.remove(self.enemy_bullets, bi)
      self:player_hit()
    end
  end

  -- Enemy body vs player
  for ei = #self.enemies, 1, -1 do
    local e = self.enemies[ei]
    if not e.dead and self:rects_overlap(p.x, p.y, p.w, p.h, e.x, e.y, e.w, e.h) then
      self:player_hit()
    end
  end

  -- Boss body vs player
  if self.boss and not self.boss.dead then
    if self:rects_overlap(p.x, p.y, p.w, p.h, self.boss.x, self.boss.y, self.boss.w, self.boss.h) then
      self:player_hit()
    end
  end
end

function FrontraView:player_hit()
  if self.game_over then return end
  local p = self.player
  if p.invincible > 0 then return end
  p.hp = p.hp - 1
  if p.hp <= 0 then
    self.game_over = true
    self:spawn_particles(p.x + p.w / 2, p.y + p.h / 2, 15, C.player)
  else
    p.invincible = 1.5
    self:spawn_particles(p.x + p.w / 2, p.y + p.h / 2, 5, C.health_bar)
  end
end

function FrontraView:rects_overlap(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and y1 < y2 + h2 and y1 + h1 > y2
end

function FrontraView:restart()
  self.player.x = 80
  self.player.y = 0
  self.player.vx = 0
  self.player.vy = 0
  self.player.on_ground = false
  self.player.shooting = false
  self.player.shoot_timer = 0
  self.player.facing = 1
  self.player.anim_frame = 0
  self.player.anim_timer = 0
  self.player.hp = 10
  self.player.max_hp = 10
  self.player.invincible = 0
  self.player.weapon = "default"
  self.player.weapon_ammo = -1

  self.input.left  = false
  self.input.right = false
  self.input.jump  = false
  self.input.shoot = false

  self.bullets = {}
  self.enemies = {}
  self.enemy_bullets = {}
  self.particles = {}
  self.fireworks = {}
  self.pickups = {}
  self.lasers = {}
  self.bombs = {}
  self.rockets = {}
  self.waves = {}

  self.level = 1
  self.level_scroll = 0
  self.boss_spawned = false
  self.boss = nil
  self.main_frame = nil
  self.main_frame_spawned = false
  self.game_complete = false
  self.final_warning_timer = nil
  self.score = 0
  self.elapsed = 0
  self.spawn_timer = 0
  self.spawn_index = 1
  self.max_simultaneous_enemies = 2
  self.continuous_spawn = false
  self.game_over = false
  self.won = false
  self.paused = false

  self.intro.phase = "playing"

  self:generate_level_colors()
end

function FrontraView:quit()
  self.finished = true
  local node = core.root_view.root_node:get_node_for_view(self)
  if node then
    node:close_view(core.root_view.root_node, self)
  end
end

-- Drawing
function FrontraView:draw()
  if self.intro.phase ~= "playing" then
    self:draw_intro()
    return
  end

  local ox, oy = self.position.x, self.position.y
  local vw, vh = self.size.x, self.size.y

  self:draw_background(C.sky)

  local s = self:get_scale()

  -- Parallax stars
  for _, st in ipairs(stars) do
    local sx = ox + (st.x * vw - self.level_scroll * st.speed) % vw
    local sy = oy + st.y * vh
    renderer.draw_rect(sx, sy, st.size * s, st.size * s, C.star)
  end

  -- Parallax mountains
  for _, m in ipairs(mountains) do
    local mx = ox + (m.x * vw - self.level_scroll * 0.3) % (vw + 100) - 50
    local my = oy + self:get_ground_y()
    renderer.draw_rect(mx, my - m.h * vh, m.w * vw, m.h * vh, C.mountain)
  end

  -- Ground
  local gy = oy + self:get_ground_y()
  renderer.draw_rect(ox, gy, vw, oy + vh - gy, C.ground)
  renderer.draw_rect(ox, gy - 2 * s, vw, 2 * s, C.platform)

  -- Platforms
  for _, pl in ipairs(platforms) do
    local px, py, pw = self:get_platform_rect(pl)
    if px + pw > 0 and px < vw then
      renderer.draw_rect(ox + px, oy + py, pw, 8 * s, C.platform)
    end
  end

  -- Player (also draws during victory celebration since won/finished don't affect this)
  if not self.game_over then self:draw_player(s) end

  -- Bullets
  for _, b in ipairs(self.bullets) do
    renderer.draw_rect(ox + b.x, oy + b.y, b.w, b.h, C.bullet)
  end

  -- Enemies
  for _, e in ipairs(self.enemies) do
    if not e.dead then self:draw_enemy(e, s) end
  end

  -- Enemy bullets
  for _, b in ipairs(self.enemy_bullets) do
    renderer.draw_rect(ox + b.x, oy + b.y, b.w, b.h, self.level_enemy_bullet_color)
  end

  -- Boss
  if self.boss and not self.boss.dead then self:draw_boss(s) end
  if self.main_frame and not self.main_frame.dead then self:draw_main_frame(s) end

  -- Fireworks (drawn behind HUD overlays)
  if self.won then
    for _, fw in ipairs(self.fireworks) do
      local alpha = math.max(0, math.min(1, fw.life / 0.3))
      local c = fw.color
      renderer.draw_rect(ox + fw.x - fw.size / 2, oy + fw.y - fw.size / 2, fw.size, fw.size,
        { c[1], c[2], c[3], math.floor(alpha * 255) })
      -- Glow ring
      renderer.draw_rect(ox + fw.x - fw.size, oy + fw.y - fw.size, fw.size * 2, fw.size * 2,
        { c[1], c[2], c[3], math.floor(alpha * 60) })
    end
  end

  -- Particles
  for _, p in ipairs(self.particles) do
    local alpha = math.max(0, math.min(1, p.life / 0.5))
    local color = p.color or C.bullet
    renderer.draw_rect(ox + p.x - p.size / 2, oy + p.y - p.size / 2, p.size, p.size,
      { color[1], color[2], color[3], math.floor(alpha * 255) })
  end

  -- Lasers
  for _, l in ipairs(self.lasers) do
    local alpha = math.max(0, math.min(1, l.life / 0.08))
    local x1, x2 = ox + l.x1, ox + l.x2
    if x1 > x2 then x1, x2 = x2, x1 end
    -- Draw as a thick line using overlapping rects
    for j = 0, math.floor(l.w) - 1 do
      local a = alpha * (1 - j / l.w)
      renderer.draw_rect(x1, oy + l.y1 - l.w / 2 + j, x2 - x1, 1,
        { C.laser[1], C.laser[2], C.laser[3], math.floor(255 * a) })
    end
    renderer.draw_rect(x1, oy + l.y1 - l.w / 2, x2 - x1, l.w,
      { C.laser[1], C.laser[2], C.laser[3], math.floor(255 * alpha * 0.3) })
  end

  -- Bombs
  for _, b in ipairs(self.bombs) do
    renderer.draw_rect(ox + b.x, oy + b.y, b.w, b.h, C.bomb_color)
    -- Flickering spark
    if math.random() < 0.5 then
      renderer.draw_rect(ox + b.x + b.w / 2 - 2, oy + b.y + b.h / 2 - 2, 4, 4, C.bullet)
    end
  end

  -- Rockets
  for _, r in ipairs(self.rockets) do
    renderer.draw_rect(ox + r.x, oy + r.y, r.w, r.h, C.rocket)
    -- Exhaust flame
    local fx = r.vx > 0 and ox + r.x - 4 or ox + r.x + r.w
    renderer.draw_rect(fx, oy + r.y + 1, 4, 2,
      { C.bomb_color[1], C.bomb_color[2], C.bomb_color[3], 150 })
  end

  -- Waves
  for _, w in ipairs(self.waves) do
    local alpha = math.max(0, w.life / 0.6)
    local cx, cy = ox + w.x, oy + w.y
    -- Draw as expanding circle using rects
    local step = w.r / 6
    for j = 1, 4 do
      local sr = w.r - (4 - j) * 3 * self:get_scale()
      if sr > 0 then
        local a = math.floor(alpha * 40 * (5 - j) / 4)
        renderer.draw_rect(cx - sr, cy - sr, sr * 2, sr * 2,
          { C.wave_color[1], C.wave_color[2], C.wave_color[3], a })
      end
    end
  end

  -- Pickups
  for _, pu in ipairs(self.pickups) do
    local pulse = 0.5 + math.sin((self.elapsed or 0) * 6) * 0.5
    renderer.draw_rect(ox + pu.x, oy + pu.y, pu.w, pu.h, C.pickup_bg)
    local wdef = weapons[pu.weapon]
    local label = wdef and wdef.name:sub(1, 1) or "?"
    local lw = style.font:get_width(label)
    local lh = style.font:get_height()
    renderer.draw_text(style.font, label,
      ox + pu.x + pu.w / 2 - lw / 2, oy + pu.y + pu.h / 2 - lh / 2,
      { 255, 255, 255, math.floor(180 + 75 * pulse) })
  end

  -- HUD
  self:draw_hud(s)

  -- Overlays
  if self.paused then
    renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 128 })
    common.draw_text(style.font, style.warn, "PAUSED", "center", ox, oy, vw, vh)
    common.draw_text(style.font, C.hud_text, "Press P to resume", "center", ox, oy + vh * 0.55, vw, 20)
  end

  if self.game_over then
    renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 160 })
    common.draw_text(style.font, C.game_over, "GAME OVER", "center", ox, oy + vh * 0.4, vw, 30)
    common.draw_text(style.font, C.hud_text, "Level " .. self.level, "center", ox, oy + vh * 0.46, vw, 20)
    common.draw_text(style.font, C.hud_text, "Press ENTER to restart", "center", ox, oy + vh * 0.52, vw, 20)
    common.draw_text(style.font, C.hud_text, "Press ESC to quit", "center", ox, oy + vh * 0.57, vw, 20)
  end

  if self.won then
    renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 80 })
    local time_left = math.max(0, 5.0 - (self.win_time or 0))
    if time_left > 0 then
      common.draw_text(style.font, C.win_text, "LEVEL " .. self.level .. " CLEAR!", "center", ox, oy + vh * 0.32, vw, 30)
      common.draw_text(style.font, C.hud_text, "Next level in " .. math.ceil(time_left) .. "...", "center", ox, oy + vh * 0.39, vw, 20)
    end
  end

  if self.game_complete then
    renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 180 })
    common.draw_text(style.big_font, C.win_text, "GAME COMPLETE", "center", ox, oy + vh * 0.20, vw, 30)
    common.draw_text(style.font, C.win_text, "The Main Frame is destroyed!", "center", ox, oy + vh * 0.30, vw, 20)
    common.draw_text(style.font, C.hud_text, "Frontran saved the galaxy!", "center", ox, oy + vh * 0.36, vw, 20)
    common.draw_text(style.font, C.hud_text, "Final Score: " .. self.score, "center", ox, oy + vh * 0.44, vw, 20)
    common.draw_text(style.font, C.hud_text, "Press ENTER to restart", "center", ox, oy + vh * 0.55, vw, 20)
    common.draw_text(style.font, C.hud_text, "Press ESC to quit", "center", ox, oy + vh * 0.61, vw, 20)
  end

  -- Final stage warning
  if self.final_warning_timer then
    renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 200 })
    local pulse = 0.5 + math.sin(self.final_warning_timer * 6) * 0.5
    common.draw_text(style.big_font,
      { C.game_over[1], C.game_over[2], C.game_over[3], math.floor(200 + 55 * pulse) },
      "WARNING", "center", ox, oy + vh * 0.28, vw, 30)
    common.draw_text(style.font, C.hud_text,
      "Final Stage Approaching", "center", ox, oy + vh * 0.38, vw, 20)
    common.draw_text(style.font, C.win_text,
      "Prepare to destroy the Main Frame!", "center", ox, oy + vh * 0.45, vw, 20)
    common.draw_text(style.font,
      { C.hud_text[1], C.hud_text[2], C.hud_text[3], math.floor(120 + 80 * pulse) },
      "Dodge the triple cannons...", "center", ox, oy + vh * 0.55, vw, 20)
  end
end

function FrontraView:draw_player(s)
  local ox, oy = self.position.x, self.position.y
  local p = self.player
  local x, y = ox + p.x, oy + p.y
  local w, h = p.w, p.h

  -- Skip drawing every other frame during invincibility flash
  if p.invincible > 0 and math.floor(p.invincible * 10) % 2 == 0 then
    return
  end

  -- Body
  renderer.draw_rect(x, y, w, h, C.player)
  -- Head
  renderer.draw_rect(x + 3 * s, y - 4 * s, w - 6 * s, 6 * s, C.player)
  -- Eyes
  local eye_x = p.facing > 0 and x + w - 5 * s or x + 2 * s
  renderer.draw_rect(eye_x, y - 2 * s, 3 * s, 2 * s, C.player_gun)
  -- Gun
  local gun_x = p.facing > 0 and x + w or x - 6 * s
  renderer.draw_rect(gun_x, y + 6 * s, 6 * s, 3 * s, C.player_gun)
  -- Legs
  if p.on_ground and math.abs(p.vx) > 0 then
    local leg_off = (p.anim_frame % 2 == 0) and 2 * s or -2 * s
    renderer.draw_rect(x + 2 * s, y + h - 4 * s, 4 * s, 4 * s, C.player)
    renderer.draw_rect(x + w - 6 * s, y + h - 4 * s, 4 * s, 4 * s + leg_off, C.player)
  end
end

function FrontraView:draw_enemy(e, s)
  local ox, oy = self.position.x, self.position.y
  local x, y = ox + e.x, oy + e.y
  local w, h = e.w, e.h
  local enemy_color = self.level_enemy_color
  renderer.draw_rect(x, y, w, h, enemy_color)
  renderer.draw_rect(x + 3 * s, y + 3 * s, 3 * s, 3 * s, C.bullet)
  renderer.draw_rect(x + w - 6 * s, y + 3 * s, 3 * s, 3 * s, C.bullet)
  local leg_off = (e.anim_frame == 0) and 2 * s or -2 * s
  renderer.draw_rect(x + 2 * s, y + h - 4 * s, 4 * s, 4 * s + leg_off, enemy_color)
  renderer.draw_rect(x + w - 6 * s, y + h - 4 * s, 4 * s, 4 * s - leg_off, enemy_color)
end

function FrontraView:draw_boss(s)
  local ox, oy = self.position.x, self.position.y
  local b = self.boss
  local x, y = ox + b.x, oy + b.y
  local w, h = b.w, b.h
  local boss_color = self.level_boss_color
  local boss_eye_color = self.level_boss_eye_color

  renderer.draw_rect(x, y, w, h, boss_color)
  renderer.draw_rect(x + 4 * s, y + 4 * s, w - 8 * s, 6 * s, boss_eye_color)
  renderer.draw_rect(x + 4 * s, y + h - 10 * s, w - 8 * s, 6 * s, boss_eye_color)
  renderer.draw_rect(x + 6 * s, y + 14 * s, 8 * s, 6 * s, boss_eye_color)
  renderer.draw_rect(x + w - 14 * s, y + 14 * s, 8 * s, 6 * s, boss_eye_color)

  local pupil_off = (self.player.x < b.x) and 0 or 4 * s
  renderer.draw_rect(x + 6 * s + pupil_off, y + 15 * s, 4 * s, 4 * s, boss_color)
  renderer.draw_rect(x + w - 14 * s + pupil_off, y + 15 * s, 4 * s, 4 * s, boss_color)

  -- Gun always points toward the player
  local gun_len = 14 * s
  local gun_w = 6 * s
  local bx = x + w / 2
  local by = y + h / 2
  local px = self.player.x + self.player.w / 2
  local py = self.player.y + self.player.h / 2
  local gdx = px - bx
  local gdy = py - by
  local gdist = math.sqrt(gdx * gdx + gdy * gdy)
  if gdist > 0 then
    -- Normalize
    local ux, uy = gdx / gdist, gdy / gdist
    -- Draw barrel as overlapping squares from center outward
    for i = 0, math.floor(gun_len / gun_w) do
      local gx = bx + ux * i * gun_w
      local gy = by + uy * i * gun_w
      renderer.draw_rect(gx - gun_w / 2, gy - gun_w / 2, gun_w, gun_w, C.player_gun)
    end
    -- Muzzle flash (small white tip)
    local mx = bx + ux * gun_len
    local my = by + uy * gun_len
    renderer.draw_rect(mx - gun_w * 0.75, my - gun_w * 0.75, gun_w * 1.5, gun_w * 1.5, C.bullet)
  end

  -- Health bar
  local bar_w = 50 * s
  local bar_h = 4 * s
  local bar_x = x + w / 2 - bar_w / 2
  local bar_y = y - 10 * s
  renderer.draw_rect(bar_x, bar_y, bar_w, bar_h, C.health_bg)
  renderer.draw_rect(bar_x, bar_y, bar_w * (b.hp / b.max_hp), bar_h, C.health_bar)

  -- Level badge on boss
  local badge_size = 8 * s
  renderer.draw_rect(x + w / 2 - badge_size / 2, y - badge_size - 4, badge_size, badge_size,
    { common.color(string.format("#%02x%02x%02x", 200 + self.level * 10, 50, 50)) })
end

function FrontraView:draw_main_frame(s)
  local ox, oy = self.position.x, self.position.y
  local mf = self.main_frame
  local x, y = ox + mf.x, oy + mf.y
  local w, h = mf.w, mf.h

  -- Dark metallic body
  local dark = { 50, 45, 55, 255 }
  local mid  = { 70, 65, 75, 255 }
  local light = { 100, 95, 105, 255 }
  local red   = { 200, 40, 40, 255 }
  local red_dark = { 160, 20, 20, 255 }
  local glow  = { 255, 60, 60, 200 }

  -- Main body
  renderer.draw_rect(x, y, w, h, dark)
  -- Shoulders
  renderer.draw_rect(x - 20 * s, y + 10 * s, 20 * s, h - 20 * s, mid)
  renderer.draw_rect(x + w, y + 10 * s, 20 * s, h - 20 * s, mid)
  -- Core (pulsing red center)
  local pulse = 0.5 + math.sin((self.elapsed or 0) * 4) * 0.5
  local core_x = x + w * 0.3
  local core_y = y + h * 0.35
  local core_w = w * 0.4
  local core_h = h * 0.3
  renderer.draw_rect(core_x - 4 * s, core_y - 4 * s, core_w + 8 * s, core_h + 8 * s,
    { glow[1], glow[2], glow[3], math.floor(100 * pulse) })
  renderer.draw_rect(core_x, core_y, core_w, core_h, red_dark)
  renderer.draw_rect(core_x + 4 * s, core_y + 4 * s, core_w - 8 * s, core_h - 8 * s, red)
  renderer.draw_rect(core_x + core_w / 2 - 6 * s, core_y + core_h / 2 - 6 * s, 12 * s, 12 * s,
    { 255, 255, 255, math.floor(200 * pulse) })

  -- Three weapon emplacements
  local gun_positions = {
    { y_frac = 0.18, label = "upper" },
    { y_frac = 0.50, label = "middle" },
    { y_frac = 0.88, label = "lower" },
  }
  for _, gp in ipairs(gun_positions) do
    local gy = y + h * gp.y_frac
    local gx = x - 16 * s
    -- Gun barrel
    renderer.draw_rect(gx, gy - 4 * s, 18 * s, 8 * s, mid)
    -- Barrel opening / glow when active
    local phases = { "lower", "gap1", "middle", "gap2", "upper", "cooldown" }
    local active_phase = phases[mf.cycle_phase + 1]
    local is_active = (active_phase == gp.label)
    local gr = is_active and red or dark
    if is_active then
      local g_pulse = 0.5 + math.sin(mf.cycle_timer * 20) * 0.5
      renderer.draw_rect(gx - 4 * s, gy - 3 * s, 4 * s, 6 * s,
        { glow[1], glow[2], glow[3], math.floor(180 * g_pulse) })
    end
    renderer.draw_rect(gx - 8 * s, gy - 5 * s, 8 * s, 10 * s, gr)
  end

  -- Health bar
  local bar_w = w
  local bar_h = 6 * s
  local bar_x = x
  local bar_y = y - 16 * s
  renderer.draw_rect(bar_x, bar_y, bar_w, bar_h, C.health_bg)
  renderer.draw_rect(bar_x, bar_y, bar_w * (mf.hp / mf.max_hp), bar_h, C.health_bar)
  -- "MAIN FRAME" label
  local lw = style.font:get_width("MAIN FRAME")
  renderer.draw_text(style.font, "MAIN FRAME", bar_x + bar_w / 2 - lw / 2, bar_y - 14, C.hud_text)
end

-- Helper to apply alpha multiplier to a color
local function apply_alpha(color, alpha)
  local a = color[4] or 255
  return { color[1], color[2], color[3], math.floor(a * alpha) }
end

function FrontraView:draw_story_scene(n, ox, oy, vw, vh, sc, alpha)
  -- Apply alpha to a color
  local function ac(color, mult)
    local a = (color[4] or 255)
    local m = (mult or 1)
    return { color[1], color[2], color[3], math.floor(a * alpha * m) }
  end

  local cx = ox + (vw - 640 * sc) / 2
  local cy = oy

  local function r(x, y, w, h, c, mult)
    renderer.draw_rect(cx + x * sc, cy + y * sc, w * sc, h * sc, ac(c, mult))
  end

  -- Scene palette
  local sky_blue     = { 30, 60, 140, 255 }
  local grass_green  = { 40, 120, 40, 255 }
  local sun_yellow   = { 255, 220, 50, 255 }
  local building     = { 140, 130, 110, 255 }
  local window_c     = { 200, 200, 100, 255 }
  local roof_color   = { 100, 40, 40, 255 }
  local fire_color   = { 255, 100, 20, 255 }
  local smoke        = { 80, 80, 80, 255 }
  local ship_dark    = { 50, 50, 60, 255 }
  local bot_color    = { 100, 100, 100, 255 }
  local bot_eye      = { 255, 60, 60, 255 }
  local rubble       = { 90, 80, 70, 255 }
  local wasteland    = { 60, 50, 40, 255 }
  local fortress     = { 60, 60, 80, 255 }
  local glow_red     = { 180, 30, 30, 150 }

  if n == 1 then
    -- Peaceful planet Xytheris
    r(0, 0, 640, 320, sky_blue)
    r(0, 220, 640, 120, grass_green)
    r(0, 210, 640, 20, { 50, 140, 50, 255 })
    r(520, 30, 56, 56, sun_yellow, 0.8)
    r(500, 15, 10, 80, sun_yellow, 0.4)
    r(540, 50, 60, 10, sun_yellow, 0.4)
    r(530, 10, 10, 40, sun_yellow, 0.4)
    r(120, 120, 60, 100, building)
    r(130, 100, 40, 20, roof_color)
    r(130, 140, 12, 14, window_c)
    r(155, 140, 12, 14, window_c)
    r(130, 170, 12, 14, window_c)
    r(155, 170, 12, 14, window_c)
    r(250, 100, 80, 120, building)
    r(260, 80, 60, 20, roof_color)
    r(265, 120, 14, 16, window_c)
    r(295, 120, 14, 16, window_c)
    r(265, 155, 14, 16, window_c)
    r(295, 155, 14, 16, window_c)
    r(60, 170, 12, 50, { 50, 30, 20, 255 })
    r(30, 140, 72, 40, { 30, 100, 30, 255 })
    r(400, 150, 14, 70, { 50, 30, 20, 255 })
    r(370, 120, 74, 40, { 30, 100, 30, 255 })
    r(440, 240, 100, 40, { 40, 100, 200, 120 })
    r(180, 50, 8, 2, { 200, 200, 200, 200 })
    r(200, 40, 10, 2, { 200, 200, 200, 200 })
  elseif n == 2 then
    -- Oblivian Empire attacks
    r(0, 0, 640, 320, { 60, 20, 20, 255 })
    r(0, 230, 640, 120, { 60, 80, 40, 255 })
    local function ship(x, y, s)
      r(x, y, 30 * s, 18 * s, ship_dark)
      r(x + 2, y - 8 * s, 8 * s, 8 * s, ship_dark)
      r(x + 20, y - 8 * s, 8 * s, 8 * s, ship_dark)
      r(x + 4, y + 18 * s, 8 * s, 10 * s, fire_color, 0.7)
      r(x + 18, y + 18 * s, 8 * s, 10 * s, fire_color, 0.7)
      r(x + 6, y + 26 * s, 4 * s, 14 * s, fire_color, 0.9)
    end
    ship(80, 20, 1.2)
    ship(200, 40, 1.0)
    ship(350, 15, 1.3)
    ship(500, 50, 0.9)
    r(160, 200, 40, 40, fire_color, 0.7)
    r(170, 190, 20, 60, fire_color, 0.5)
    r(155, 195, 50, 10, fire_color, 0.5)
    r(460, 180, 30, 30, fire_color, 0.7)
    r(465, 170, 20, 50, fire_color, 0.5)
    r(150, 180, 40, 20, smoke, 0.4)
    r(450, 160, 30, 20, smoke, 0.4)
  elseif n == 3 then
    -- Bot armies destroy civilization
    r(0, 0, 640, 320, { 100, 30, 10, 255 })
    r(0, 240, 640, 100, { 50, 30, 20, 255 })
    r(80, 100, 50, 140, rubble)
    r(70, 90, 70, 20, rubble)
    r(250, 80, 60, 160, rubble)
    r(240, 60, 80, 30, rubble)
    r(310, 100, 30, 20, rubble)
    r(120, 200, 30, 30, fire_color, 0.7)
    r(130, 185, 10, 25, fire_color, 0.5)
    r(300, 170, 25, 25, fire_color, 0.7)
    r(305, 155, 15, 30, fire_color, 0.5)
    local function bot(x, y, s)
      s = s or 1
      r(x, y - 20 * s, 16 * s, 20 * s, bot_color)
      r(x + 4 * s, y - 26 * s, 8 * s, 8 * s, bot_color)
      r(x + 5 * s, y - 24 * s, 3 * s, 3 * s, bot_eye)
      r(x + 2 * s, y, 4 * s, 8 * s, bot_color)
      r(x + 10 * s, y, 4 * s, 8 * s, bot_color)
      r(x + 16 * s, y - 14 * s, 6 * s, 4 * s, bot_color)
    end
    bot(30, 240, 1.0)
    bot(70, 240, 1.0)
    bot(110, 240, 1.0)
    bot(380, 240, 1.1)
    bot(420, 240, 1.1)
    bot(520, 240, 1.0)
    bot(560, 240, 1.0)
  elseif n == 4 then
    -- Last survivor
    r(0, 0, 640, 320, { 40, 40, 50, 255 })
    r(0, 240, 640, 100, wasteland)
    r(50, 180, 40, 60, { 30, 30, 35, 255 })
    r(200, 200, 30, 40, { 30, 30, 35, 255 })
    r(550, 170, 50, 70, { 30, 30, 35, 255 })
    local px, py, ps = 290, 160, 1.5
    r(px, py, 16 * ps, 24 * ps, C.player)
    r(px + 3 * ps, py - 4 * ps, 16 * ps - 6 * ps, 6 * ps, C.player)
    r(px + 16 * ps - 5 * ps, py - 2 * ps, 3 * ps, 2 * ps, C.player_gun)
    r(px + 16 * ps, py + 6 * ps, 6 * ps, 3 * ps, C.player_gun)
    r(px + 2 * ps, py + 24 * ps - 4 * ps, 4 * ps, 4 * ps, C.player)
    r(px + 14 * ps - 6 * ps, py + 24 * ps - 4 * ps, 4 * ps, 6 * ps, C.player)
    r(px + 4 * ps, py - 40 * ps, 8 * ps, 40 * ps, { 200, 200, 220, 40 })
    r(80, 20, 3, 3, { 220, 220, 220, 150 })
    r(180, 50, 2, 2, { 220, 220, 220, 150 })
    r(350, 30, 3, 3, { 220, 220, 220, 150 })
    r(500, 15, 2, 2, { 220, 220, 220, 150 })
    r(600, 60, 3, 3, { 220, 220, 220, 150 })
  elseif n == 5 then
    -- Main Frame fortress
    r(0, 0, 640, 320, { 30, 15, 20, 255 })
    r(0, 240, 640, 100, { 40, 25, 25, 255 })
    r(160, 30, 300, 210, glow_red, 0.3)
    r(200, 100, 240, 140, fortress)
    r(190, 80, 260, 30, { 80, 80, 100, 255 })
    r(220, 50, 200, 40, { 100, 100, 120, 255 })
    r(260, 20, 120, 40, { 120, 120, 140, 255 })
    r(290, 130, 60, 60, glow_red, 0.6)
    r(300, 140, 40, 40, { 255, 60, 60, 200 })
    r(310, 150, 20, 20, { 255, 150, 150, 255 })
    r(210, 120, 20, 30, { 50, 50, 70, 255 })
    r(410, 120, 20, 30, { 50, 50, 70, 255 })
    r(200, 200, 30, 40, { 70, 70, 90, 255 })
    r(410, 200, 30, 40, { 70, 70, 90, 255 })
    r(290, 200, 60, 40, { 70, 70, 90, 255 })
    local function fbot(x, y, s)
      s = s or 1
      r(x, y - 20 * s, 16 * s, 20 * s, bot_color)
      r(x + 4 * s, y - 26 * s, 8 * s, 8 * s, bot_color)
      r(x + 5 * s, y - 24 * s, 3 * s, 3 * s, bot_eye)
      r(x + 2 * s, y, 4 * s, 8 * s, bot_color)
      r(x + 10 * s, y, 4 * s, 8 * s, bot_color)
      r(x + 16 * s, y - 14 * s, 6 * s, 4 * s, bot_color)
    end
    fbot(140, 240, 1.0)
    fbot(170, 240, 1.0)
    fbot(460, 240, 1.0)
    fbot(490, 240, 1.0)
    local ppx, ppy, pps = 60, 190, 1.3
    r(ppx, ppy, 16 * pps, 24 * pps, C.player)
    r(ppx + 3 * pps, ppy - 4 * pps, 16 * pps - 6 * pps, 6 * pps, C.player)
    r(ppx + 16 * pps - 5 * pps, ppy - 2 * pps, 3 * pps, 2 * pps, C.player_gun)
    r(ppx + 16 * pps, ppy + 6 * pps, 6 * pps, 3 * pps, C.player_gun)
    r(ppx + 2 * pps, ppy + 24 * pps - 4 * pps, 4 * pps, 4 * pps, C.player)
    r(ppx + 14 * pps - 6 * pps, ppy + 24 * pps - 4 * pps, 4 * pps, 6 * pps, C.player)
    r(ppx + 20 * pps, ppy + 12 * pps, 40, 3, C.bullet)
    r(ppx + 20 * pps + 40, ppy + 12 * pps, 20, 3, { 255, 255, 255, 120 })
  end
end

function FrontraView:draw_intro()
  local ox, oy = self.position.x, self.position.y
  local vw, vh = self.size.x, self.size.y
  local intro = self.intro

  -- Dark backdrop for all intro phases
  renderer.draw_rect(ox, oy, vw, vh, { 0, 0, 0, 255 })

  if intro.phase == "logo" then
    -- "Presented by"
    local pa = intro.presented_alpha
    if pa > 0.001 then
      common.draw_text(style.font,
        apply_alpha(style.dim, pa),
        "Presented by", "center", ox, oy + vh * 0.22, vw, 20)
    end

    -- Pragtical logo (icon characters 5-9)
    local la = intro.logo_alpha
    if la > 0.001 then
      local icon_font = style.icon_big_font:copy(math.floor(70 * SCALE))
      -- Compute center position so the entire stacked glyph fits
      local gw = icon_font:get_width("9")
      local gh = icon_font:get_height()
      local logo_x = ox + (vw - gw) / 2
      local logo_y = oy + vh * 0.32 + (gh * 0.1)

      renderer.draw_text(icon_font, "5", logo_x, logo_y, apply_alpha(style.background2, la))
      renderer.draw_text(icon_font, "6", logo_x, logo_y, apply_alpha(style.text, la))
      renderer.draw_text(icon_font, "7", logo_x, logo_y, apply_alpha(style.caret, la))
      renderer.draw_text(icon_font, "8", logo_x, logo_y, apply_alpha(common.lighten_color(style.dim, 25), la))
      renderer.draw_text(icon_font, "9", logo_x, logo_y, apply_alpha(common.lighten_color(style.dim, 45), la))
    end

    -- "Pragtical"
    local pra = intro.pragtical_alpha
    if pra > 0.001 then
      common.draw_text(style.big_font,
        apply_alpha(style.text, pra),
        "Pragtical", "center", ox, oy + vh * 0.68, vw, 30)
    end

    -- Hint
    if intro.timer > 4.0 then
      local pulse = 0.4 + math.sin(intro.timer * 3) * 0.3
      common.draw_text(style.font,
        { C.hud_text[1], C.hud_text[2], C.hud_text[3], math.floor(160 * pulse) },
        "Press Enter to skip", "center", ox, oy + vh * 0.85, vw, 20)
    end
  elseif intro.phase == "story" then
    local slide = story_slides[intro.story_slide]
    local alpha = intro.story_alpha

    -- Scene area: upper 53% of view
    local scene_y = oy + vh * 0.02
    local scene_h = vh * 0.53
    local sc = math.min(vw / 640, scene_h / 320)
    if alpha > 0.001 then
      self:draw_story_scene(intro.story_slide, ox, scene_y, vw, scene_h, sc, alpha)
    end

    -- Story text below the scene
    if slide and alpha > 0.001 then
      local lines = {}
      for line in slide:gmatch("[^\n]+") do
        lines[#lines + 1] = line
      end
      local lh = style.font:get_height() + 4
      local total_h = #lines * lh
      local text_y = scene_y + scene_h + 6
      local avail_h = oy + vh - text_y - 40
      local start_y = text_y + (avail_h - total_h) / 2
      for i, line in ipairs(lines) do
        common.draw_text(style.font,
          { C.hud_text[1], C.hud_text[2], C.hud_text[3], math.floor(255 * alpha) },
          line, "center", ox, start_y + (i - 1) * lh, vw, lh)
      end
    end

    -- Slide counter
    common.draw_text(style.font,
      { C.hud_text[1], C.hud_text[2], C.hud_text[3], 100 },
      intro.story_slide .. " / " .. #story_slides, "center", ox, oy + vh - 30, vw, 20)

    -- Hint
    local pulse = 0.4 + math.sin(intro.timer * 3) * 0.3
    common.draw_text(style.font,
      { C.hud_text[1], C.hud_text[2], C.hud_text[3], math.floor(160 * pulse) },
      "Press Enter to continue", "center", ox, oy + vh * 0.88, vw, 20)
  elseif intro.phase == "start" then
    -- Level text
    common.draw_text(style.big_font, C.win_text,
      "LEVEL " .. self.level, "center", ox, oy + vh * 0.12, vw, 30)

    -- Amplified player in center (2.5x scale)
    local s = self:get_scale() * 2.5
    local px = ox + vw / 2 - 8 * s
    local py = oy + vh * 0.40
    local pw, ph = 16 * s, 24 * s

    -- Animate player shooting
    local anim_frame = math.floor(intro.start_timer / 0.15) % 4

    -- Body
    renderer.draw_rect(px, py, pw, ph, C.player)
    -- Head
    renderer.draw_rect(px + 3 * s, py - 4 * s, pw - 6 * s, 6 * s, C.player)
    -- Eyes
    renderer.draw_rect(px + pw - 5 * s, py - 2 * s, 3 * s, 2 * s, C.player_gun)
    -- Gun
    renderer.draw_rect(px + pw, py + 6 * s, 6 * s, 3 * s, C.player_gun)
    -- Legs (walking animation)
    local leg_off = (anim_frame % 2 == 0) and 2 * s or -2 * s
    renderer.draw_rect(px + 2 * s, py + ph - 4 * s, 4 * s, 4 * s, C.player)
    renderer.draw_rect(px + pw - 6 * s, py + ph - 4 * s, 4 * s, 4 * s + leg_off, C.player)

    -- Smoking bullets fired periodically to the right
    if math.floor(intro.start_timer / 0.2) % 2 == 0 then
      local bx = px + pw + 6 * s
      local by = py + 7 * s
      -- Bullet trail
      renderer.draw_rect(bx, by, 10 * s, 3 * s, C.bullet)
      renderer.draw_rect(bx + 10 * s, by + 1 * s, 6 * s, 2 * s,
        { C.bullet[1], C.bullet[2], C.bullet[3], 150 })
      -- Smoke puffs
      for i = 1, 4 do
        local sx = bx + 12 * s + math.random() * 25 * s
        local sy = by + (math.random() - 0.5) * 12 * s
        local ss = (2 + math.random() * 4) * s
        local smoke_alpha = math.floor(60 + math.random() * 80)
        renderer.draw_rect(sx, sy, ss, ss, { 180, 180, 180, smoke_alpha })
      end
    end

    -- "Press Enter to Start" with pulse
    local pulse = 0.5 + math.sin(intro.start_timer * 2.5) * 0.5
    local text_y = oy + vh * 0.78
    common.draw_text(style.font,
      { C.win_text[1], C.win_text[2], C.win_text[3], math.floor(180 + 75 * pulse) },
      "Press Enter to Start", "center", ox, text_y, vw, 20)
  end
end

function FrontraView:draw_hud(s)
  local ox, oy = self.position.x, self.position.y
  local vw = self.size.x
  local lh = style.font:get_height()
  renderer.draw_text(style.font, "SCORE: " .. self.score, ox + 10, oy + 10, C.hud_text)

  -- Level indicator
  renderer.draw_text(style.font, "LEVEL: " .. self.level, ox + 10, oy + 10 + lh + 4, C.hud_text)

  -- Health bar
  local p = self.player
  local bar_w = 120 * s
  local bar_h = 8 * s
  local bar_x = ox + 10 * s
  local bar_y = oy + 10 + (lh + 4) * 2 + 4
  renderer.draw_rect(bar_x, bar_y, bar_w, bar_h, C.health_bg)
  renderer.draw_rect(bar_x, bar_y, bar_w * (p.hp / p.max_hp), bar_h, C.health_bar)
  renderer.draw_text(style.font, "HP: " .. p.hp .. "/" .. p.max_hp, bar_x + bar_w + 6, bar_y - 1, C.hud_text)

  -- Weapon info
  local wdef = weapons[p.weapon] or weapons.default
  local wname = wdef.name
  local wammo = p.weapon_ammo > 0 and (" x" .. p.weapon_ammo) or ""
  local wtext = wname .. wammo
  local wcolor = p.weapon == "default" and C.hud_text
    or p.weapon == "laser" and C.laser
    or p.weapon == "triple" and { 50, 255, 50, 255 }
    or p.weapon == "bomb" and C.bomb_color
    or p.weapon == "homing" and C.rocket
    or p.weapon == "wave" and C.wave_color
    or C.hud_text
  renderer.draw_text(style.font, wtext, bar_x, bar_y + bar_h + 4 * s, wcolor)

  -- Stage progress
  local progress = math.min(1, self.level_scroll / cfg.level_length)
  local sbar_w = 100 * s
  local sbar_h = 6 * s
  local sbar_x = ox + vw - sbar_w - 10
  local sbar_y = oy + 10
  renderer.draw_rect(sbar_x, sbar_y, sbar_w, sbar_h, C.health_bg)
  renderer.draw_rect(sbar_x, sbar_y, sbar_w * progress, sbar_h, C.health_bar)
  renderer.draw_text(style.font, "STAGE", sbar_x, sbar_y + sbar_h + 2, C.hud_text)

  renderer.draw_text(style.font,
    "Arrows: Move/Jump  Z: Shoot  P: Pause  ESC: Quit",
    ox + 10, oy + self.size.y - lh - 10,
    { C.hud_text[1], C.hud_text[2], C.hud_text[3], 100 })
end

-- Commands (input state setters)
command.add(FrontraView, {
  ["frontra:move-left"] = function()
    local v = core.active_view
    v.input.left = true
    v.input.right = false
  end,
  ["frontra:move-right"] = function()
    local v = core.active_view
    v.input.right = true
    v.input.left = false
  end,
  ["frontra:stop-left"] = function()
    core.active_view.input.left = false
  end,
  ["frontra:stop-right"] = function()
    core.active_view.input.right = false
  end,
  ["frontra:jump"] = function()
    core.active_view.input.jump = true
  end,
  ["frontra:stop-jump"] = function()
    core.active_view.input.jump = false
  end,
  ["frontra:shoot"] = function()
    core.active_view.input.shoot = true
  end,
  ["frontra:stop-shoot"] = function()
    core.active_view.input.shoot = false
  end,
  ["frontra:pause"] = function()
    local v = core.active_view
    if not v.game_over and not v.won then
      v.paused = not v.paused
    end
  end,
  ["frontra:quit"] = function()
    core.active_view:quit()
  end,
  ["frontra:restart"] = function()
    local v = core.active_view
    if v.intro and v.intro.phase ~= "playing" then
      v:advance_intro()
    elseif v.game_over or v.won or v.game_complete then
      v:restart()
    end
  end,
})

command.add(nil, {
  ["frontra:start"] = function()
    local view = FrontraView()
    core.root_view:get_active_node_default():add_view(view)
    core.set_active_view(view)
  end,
})

-- Key bindings
keymap.add {
  ["left"]        = "frontra:move-left",
  ["right"]       = "frontra:move-right",
  ["up"]          = "frontra:jump",
  ["z"]           = "frontra:shoot",
  ["space"]       = "frontra:shoot",
  ["escape"]      = "frontra:quit",
  ["p"]           = "frontra:pause",
  ["return"]      = "frontra:restart",
}

return { view = FrontraView }