-- mod-version:3
--
-- Number stepping plugin for Pragtical
-- @copyright Jefferson Gonzalez <jgmdev@gmail.com>
-- @license MIT
--
local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"

---Configuration settings for the numstep plugin.
---@class config.plugins.numstep
---The default integral amount used to step a number.
---@field integer_step integer
---The default decimals amount used to step a number.
---@field decimals_step number
config.plugins.numstep = common.merge({
  integer_step = 1,
  decimals_step = 0.1,
  -- The config specification used by the settings gui
  config_spec = {
    name = "Number Stepping",
    {
      label = "Integer Step",
      description = "The default integral amount used to step a number.",
      path = "integer_step",
      type = "number",
      min = 1,
      step = 1,
      default = 1
    },
    {
      label = "Decimals Step",
      description = "The default decimals amount used to step a number.",
      path = "decimals_step",
      type = "number",
      min = 0.01,
      step = 0.01,
      default = 0.1
    }
  }
}, config.plugins.numstep)

---Get the starting position of a number from given doc cursor position.
---@param doc core.doc
---@param line integer
---@param col integer
---@return integer col
local function start_of_number(doc, line, col)
  local dot_found = false
  local doc_line = doc.lines[line]
  while true do
    local char = doc_line:sub(col-1, col-1):match("[%d%.%-]")
    if not char then
      break
    elseif col-1 == 1 then
      col = col - 1
      break
    elseif char == "." then
      if not dot_found then
        dot_found = true
        local valid_pchar = doc_line:sub(col-2, col-2):match("%d")
        if not valid_pchar then break end
      else
        break
      end
    elseif char == "-" then
      local valid_pchar = doc_line:sub(col-2, col-2):match("[%s%p]")
      if not valid_pchar then
        break
      end
    end
    col = col - 1
  end
  return col
end

---Get the ending position of a number from given doc cursor position.
---@param doc core.doc
---@param line integer
---@param col integer
---@return integer col
local function end_of_number(doc, line, col)
  local dot_found = false
  local doc_line = doc.lines[line]
  local line_len = #doc_line
  while true do
    local char = doc_line:sub(col+1, col+1):match("[%d%.]")
    if not char or col+1 == line_len then
      col = col + 1
      break
    elseif char == "." then
      if not dot_found then
        dot_found = true
        local valid_nchar = doc_line:sub(col+2, col+2):match("%d")
        if not valid_nchar then break end
      else
        break
      end
    end
    col = col + 1
  end
  return col
end

---Functionality to allow stepping a document selected numbers.
---@class plugins.numstep
local numstep = {}

---Increment or decrement a DocView document selected numbers by the given step.
---@param dv core.docview
---@param step number
---@param operation? "sum" | "mul" | "div"
function numstep.step(dv, step, operation)
  operation = operation or "sum"
  ---@type core.doc
  local doc = dv.doc
  for idx, line, col1 in doc:get_selections(true) do
    col1 = start_of_number(doc, line, col1)
    local col2 = end_of_number(doc, line, col1)
    local text = doc:get_text(line, col1, line, col2)
    local number_text = text:match("^%-?%d*[%.%d]*%d+")
    if number_text then
      local zero_pad = number_text:match("^0+")
      local num_len = #number_text
      local number = tonumber(number_text)
      if operation == "sum" then
        number = number + step
      elseif operation == "mul" then
        number = number * step
      elseif operation == "div" then
        number = number / step
      end
      number_text = tostring(number)
      if zero_pad and #zero_pad < num_len and not text:match("%.") then
        number_text = string.format("%0"..num_len.."d", number)
      end
      doc:insert(line, col2, number_text)
      doc:remove(line, col1, line, col2)
      if col1 == col2 then
        line, col2 = doc:position_offset(line, col1, #number_text)
        doc:set_selections(idx, line, col1, line, col2)
      end
    end
  end
end

command.add("core.docview", {
  ["doc:increase-number"] = function(dv)
    numstep.step(dv, config.plugins.numstep.integer_step)
  end,

  ["doc:decrease-number"] = function(dv)
    numstep.step(dv, -config.plugins.numstep.integer_step)
  end,

  ["doc:increase-number-decimals"] = function(dv)
    numstep.step(dv, config.plugins.numstep.decimals_step)
  end,

  ["doc:decrease-number-decimals"] = function(dv)
    numstep.step(dv, -config.plugins.numstep.decimals_step)
  end,

  ["doc:multiply-number"] = function(dv)
    core.command_view:enter("Enter the Multiplier", {
      submit = function(text)
        local step = tonumber(text)
        if not step then
          core.error("Invalid number given.")
        else
          numstep.step(dv, step, "mul")
        end
      end
    })
  end,

  ["doc:divide-number"] = function(dv)
    core.command_view:enter("Enter the Divisor", {
      submit = function(text)
        local step = tonumber(text)
        if not step then
          core.error("Invalid number given.")
        else
          numstep.step(dv, step, "div")
        end
      end
    })
  end,

  ["doc:input-step-number"] = function(dv)
    core.command_view:enter("Enter a Step Number (+ or -)", {
      submit = function(text)
        local step = tonumber(text)
        if not step then
          core.error("Invalid number given.")
        else
          numstep.step(dv, step)
        end
      end
    })
  end,
})

keymap.add({
  ["ctrl+keypad +"] = "doc:increase-number",
  ["ctrl+keypad -"] = "doc:decrease-number",
  ["ctrl+shift+keypad +"] = "doc:increase-number-decimals",
  ["ctrl+shift+keypad -"] = "doc:decrease-number-decimals",
  ["ctrl+keypad *"] = "doc:multiply-number",
  ["ctrl+keypad /"] = "doc:divide-number",
  ["ctrl+keypad enter"] = "doc:input-step-number",
})


return numstep
