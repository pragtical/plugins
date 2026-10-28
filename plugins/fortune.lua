-- mod-version:3
-- Show fortune in the status view
-- when there is no active document
-- or the active document is empty.

local core = require("core")
local common = require("core.common")
local config = require("core.config")
local style = require("core.style")
local StatusView = require("core.statusview")
local command = require("core.command")

local DEFAULT_ARGUMENTS = "-n 80 -s"
local MAX_LENGTH = 120

config.plugins.fortune = common.merge({
  command = "fortune",
  arguments = DEFAULT_ARGUMENTS,
  length = MAX_LENGTH,

  config_spec = {
    name = "Fortune",
    {
      label = "Command",
      description = "Path to the fortune program.",
      path = "command",
      type = "string",
      default = "fortune",
    },
    {
      label = "Arguments",
      description = "Arguments passed to the command.",
      path = "arguments",
      type = "string",
      default = DEFAULT_ARGUMENTS,
    },
    {
      label = "Length",
      description = "Maximum length of quotes.",
      path = "length",
      type = "number",
      default = MAX_LENGTH,
      min = 20,
      max = 500,
    },
  },
}, config.plugins.fortune)

local state = {
  text = nil,
  last_eligible = false,
  document = nil,
  project_dir = nil,
}

local function shell_quote(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function run_fortune()
  local plugin_config = config.plugins.fortune
  local executable = tostring(plugin_config.command or "")
  if executable == "" then
    executable = "fortune"
  end

  -- arguments in config replace the defaults, not appended
  local arguments = tostring(plugin_config.arguments or "")

  local cmd = shell_quote(executable)
  if arguments ~= "" then
    cmd = cmd .. " " .. arguments
  end

  local ok, process = pcall(io.popen, cmd .. " 2>/dev/null", "r")
  if not ok or not process then
    core.log("[fortune] could not run " .. executable)
    return nil
  end

  local output = process:read("*a") or ""
  local closed, reason, code = process:close()

  if closed ~= true and closed ~= 0 then
    if code == 127 or closed == 127 then -- shell: command not found
      core.log("[fortune] command not found: " .. executable)
    elseif reason == "signal" then
      core.log("[fortune] killed by signal " .. code)
    else
      core.log("[fortune] command failed (exit code " .. tostring(code or closed) .. ")")
    end
    return nil
  end

  -- ensure the quote is one-lienr
  output = output:gsub("\r\n", " "):gsub("%s+", " ")
  output = output:match("^%s*(.-)%s*$") or ""

  if output == "" then
    core.log("[fortune] command returned empty output")
    return nil
  end

  return output
end

local function truncate(text, limit)
  limit = math.max(1, math.floor(tonumber(limit) or MAX_LENGTH))
  if #text > limit then
    return text:sub(1, math.max(0, limit - 3)) .. "..."
  end
  return text
end

local function is_eligible()
  local view = core.active_view

  if (not view or not view.doc) and core.root_view and core.root_view.get_active_view then
    local ok, root_view = pcall(core.root_view.get_active_view, core.root_view)
    if ok and root_view then
      view = root_view
    end
  end

  local doc = view and view.doc or nil
  -- hide in plugin manager and settings
  if view and type(view.get_name) == "function" then
    local view_name = view:get_name()
    if view_name == "Plugin Manager" or view_name == "Settings" then
      return false, doc
    end
  end

  -- empty project
  if not doc then
    return true, nil
  end
  -- untitled
  if not doc.abs_filename then
    return true, doc
  end
  -- empty doc
  local lines = doc.lines
  return type(lines) == "table" and #lines == 1 and lines[1] == "", doc
end

local function refresh_fortune()
  local limit = math.max(1, math.floor(tonumber(config.plugins.fortune.length) or MAX_LENGTH))
  local text
  for _ = 1, 3 do
    text = run_fortune()
    if not text then
      state.text = nil
      return
    end
    if #text <= limit then
      state.text = text
      return
    end
  end
  -- truncate after consecutive long draw to avoid endless retry
  state.text = truncate(text, limit)
end

command.add(nil, {
  ["fortune:new"] = refresh_fortune,
})

core.status_view:add_item({
  name = "status:fortune",
  alignment = StatusView.Item.LEFT,
  position = -1,
  separator = core.status_view.separator2,
  command = "fortune:new",
  tooltip = "Click to refresh",

  get_item = function()
    local eligible, doc = is_eligible()

    if not eligible then
      state.last_eligible = false
      state.document = nil
      state.project_dir = nil
      return { style.text, "" }
    end

    local project_dir = core.project_dir
    local context_changed = not state.last_eligible or state.document ~= doc or state.project_dir ~= project_dir
    if context_changed then
      state.document = doc
      state.project_dir = project_dir
      state.last_eligible = true
      refresh_fortune()
    end

    local text = truncate(state.text or "", config.plugins.fortune.length)
    return { style.text, text }
  end,
})

return state
