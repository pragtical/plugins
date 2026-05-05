-- mod-version:3
local core = require "core"
local style = require "core.style"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local tokenizer = require "core.tokenizer"
local Highlighter = require "core.doc.highlighter"

config.plugins.rainbowparen = common.merge({
  enabled = true,
  parens = 5
}, config.plugins.rainbowparen)

style.syntax.paren_unbalanced = style.syntax.paren_unbalanced or { common.color "#DC0408" }
style.syntax.paren1  =  style.syntax.paren1 or { common.color "#FC6F71"}
style.syntax.paren2  =  style.syntax.paren2 or { common.color "#fcb053"}
style.syntax.paren3  =  style.syntax.paren3 or { common.color "#fcd476"}
style.syntax.paren4  =  style.syntax.paren4 or { common.color "#52dab2"}
style.syntax.paren5  =  style.syntax.paren5 or { common.color "#5a98cf"}

local highlighter_start = Highlighter.start
local highlighter_get_line = Highlighter.get_line
local highlighter_tokenize_line = Highlighter.tokenize_line
local closers = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}"
}

local function parenstyle(parenstack)
  return "paren" .. ((#parenstack % config.plugins.rainbowparen.parens) + 1)
end

local function apply_rainbow(tokens, parenstack)
  parenstack = parenstack or ""
  local newres = {}
  -- split parens out
  -- the stock tokenizer can't do this because it merges identical adjacent tokens
  for _, type, text in tokenizer.each_token(tokens) do
    if type == "normal" or type == "symbol" then
      for normtext1, paren, normtext2 in text:gmatch("([^%(%[{}%]%)]*)([%(%[{}%]%)]?)([^%(%[{}%]%)]*)") do
        if #normtext1 > 0 then
          table.insert(newres, type)
          table.insert(newres, normtext1)
        end
        if #paren > 0 then
          if paren == parenstack:sub(-1) then -- expected closer
            parenstack = parenstack:sub(1, -2)
            table.insert(newres, parenstyle(parenstack))
          elseif closers[paren] then -- opener
            table.insert(newres, parenstyle(parenstack))
            parenstack = parenstack .. closers[paren]
          else -- unexpected closer
            table.insert(newres, "paren_unbalanced")
          end
          table.insert(newres, paren)
        end
        if #normtext2 > 0 then
          table.insert(newres, type)
          table.insert(newres, normtext2)
        end
      end
    else
      table.insert(newres, type)
      table.insert(newres, text)
    end
  end
  return newres, parenstack
end

local function get_prev_parenstack(self, idx)
  local prev = idx > 1 and self.lines[idx - 1]
  return prev and prev.parenstack or ""
end

local function set_max_wanted_line(self, idx)
  self.max_wanted_line = math.max(self.max_wanted_line, idx)
  if self.first_invalid_line <= self.max_wanted_line then
    self:start()
  end
end

local function recolor_line(line, parenstack)
  line.init_parenstack = parenstack
  line.tokens, line.parenstack = apply_rainbow(line.base_tokens or line.tokens, parenstack)
  return line
end

local function tokenize_highlighter_line(self, idx, state, parenstack, resume)
  local res = self.lines[idx] or {}
  res.init_state = state
  res.init_parenstack = parenstack or ""
  res.text = self.doc:get_utf8_line(idx)
  res.base_tokens, res.state, res.resume = tokenizer.tokenize(self.doc.syntax, res.text, state, resume)
  res.tokens, res.parenstack = apply_rainbow(res.base_tokens, res.init_parenstack)
  return res
end

function Highlighter:tokenize_line(idx, state, resume)
  if not config.plugins.rainbowparen.enabled then
    return highlighter_tokenize_line(self, idx, state, resume)
  end
  return tokenize_highlighter_line(self, idx, state, get_prev_parenstack(self, idx), resume)
end

function Highlighter:get_line(idx)
  if not config.plugins.rainbowparen.enabled then
    return highlighter_get_line(self, idx)
  end
  if not self.doc then return { text = "", tokens = { "normal", "" } } end

  local line = self.lines[idx]
  local text = self.doc:get_utf8_line(idx)
  local state = idx > 1 and self.lines[idx - 1] and self.lines[idx - 1].state
  local parenstack = get_prev_parenstack(self, idx)
  if not line or line.text ~= text or line.init_state ~= state then
    line = self:tokenize_line(idx, state)
    self.lines[idx] = line
    self:update_notify(idx, 0)
  elseif line.init_parenstack ~= parenstack then
    recolor_line(line, parenstack)
    self:update_notify(idx, 0)
  end

  set_max_wanted_line(self, idx)
  return line
end

function Highlighter:start()
  if not config.plugins.rainbowparen.enabled then
    return highlighter_start(self)
  end
  if self.running then return end
  self.running = true
  core.add_thread(function()
    local views = #core.get_views_referencing_doc(self.doc)
    local prev_line = 0
    while self.first_invalid_line <= self.max_wanted_line do
      if not self.doc then return end
      local max = math.min(self.first_invalid_line + 40, self.max_wanted_line)
      local line
      local retokenized_from
      for i = self.first_invalid_line, max do
        local state = (i > 1) and self.lines[i - 1].state
        line = self.lines[i]
        local text = self.doc:get_utf8_line(i)
        local parenstack = get_prev_parenstack(self, i)
        if line and line.resume and (line.init_state ~= state or line.text ~= text) then
          line.resume = nil
        end
        if not (line and line.init_state == state and line.text == text and not line.resume) then
          retokenized_from = retokenized_from or i
          self.lines[i] = self:tokenize_line(i, state, line and line.resume)
          if self.lines[i].resume then
            self.first_invalid_line = i
            goto yield
          end
        elseif line.init_parenstack ~= parenstack then
          retokenized_from = retokenized_from or i
          recolor_line(line, parenstack)
        elseif retokenized_from then
          self:update_notify(retokenized_from, i - retokenized_from - 1)
          retokenized_from = nil
        end
      end

      self.first_invalid_line = max + 1
      ::yield::
      if
        retokenized_from and (
          prev_line ~= retokenized_from
          or
          not (line and line.resume and #line.text > 200)
        )
      then
        prev_line = retokenized_from
        self:update_notify(retokenized_from, max - retokenized_from)
      end
      core.redraw = true
      coroutine.yield()

      if views > 0 and #core.get_views_referencing_doc(self.doc) == 0 then
        break
      end
    end
    self.max_wanted_line = 0
    self.running = false
  end, self)
end

local function toggle_rainbowparen(enabled)
  config.plugins.rainbowparen.enabled = enabled
  for _, doc in ipairs(core.docs) do
    doc.highlighter = Highlighter(doc)
    doc:reset_syntax()
  end
end

-- The config specification used by the settings gui
config.plugins.rainbowparen.config_spec = {
  name = "Rainbow Parentheses",
  {
    label = "Enable",
    description = "Activates rainbow parenthesis coloring by default.",
    path = "enabled",
    type = "toggle",
    default = true,
    on_apply = function(enabled)
      toggle_rainbowparen(enabled)
    end
  }
}

command.add(nil, {
  ["rainbow-parentheses:toggle"] = function()
    toggle_rainbowparen(not config.plugins.rainbowparen.enabled)
    core.log(
      "Rainbow Parentheses: %s",
      config.plugins.rainbowparen.enabled and "Enabled" or "Disabled"
    )
  end
})
