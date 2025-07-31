-- mod-version:3
--
-- Original Code:
-- https://github.com/vincens2005/lite-xl-updatechecker
--
-- Copyright: cukmekerb <cukmekerb@gmail.com>
-- Improvements and Adaptation: Jefferson Gonzalez <jgmdev@gmail.com>
-- License: MIT
local core = require "core"
local config = require "core.config"
local common = require "core.common"
local command = require "core.command"
local json = require "libraries.jsonmod"

config.plugins.updatechecker = common.merge({
  timeout = 3, -- increase this value if you get json.lua errors
  check_on_startup = true,
  config_spec = {
    name = "Update Checker",
    {
      label = "Check on Startup",
      description = "Check for new releases on editor startup.",
      path = "check_on_startup",
      type = "toggle",
      default = true
    },
    {
      label = "Timeout",
      description = "Maximum amount in seconds to fetch the latest release info.",
      path = "timeout",
      type = "number",
      default = 3,
      min = 3,
      max = 10
    }
  }
}, config.plugins.updatechecker)

local open_link
if common.open_in_system then
  open_link = common.open_in_system
else -- backward compatibility with older Pragtical versions
  local function launcher_fix_path(path)
    if not io.open(path, "rb") then
      path = common.basename(path)
    end
    return path
  end

  local platform_url_launcher
  if PLATFORM == "Windows" then
    platform_url_launcher = 'start ""'
  elseif PLATFORM == "Mac OS X" then
    platform_url_launcher = "open"
  else
    platform_url_launcher = "xdg-open"
  end

  config.plugins.updatechecker.url_launcher = platform_url_launcher

  table.insert(config.plugins.updatechecker.config_spec, {
    label = "URL Launcher",
    description = "Command used to open the release page.",
    path = "url_launcher",
    type = "file",
    default = platform_url_launcher,
    get_value = launcher_fix_path,
    set_value = launcher_fix_path
  })

  open_link = function(resource)
    system.exec(
      config.plugins.updatechecker.url_launcher .. " " .. resource
    )
  end
end

-- stolen from git status
local function exec(cmd, wait)
  local res = ""
  local proc_started, proc = pcall(process.start, cmd, {timeout = wait})
  if proc_started and proc then
    proc:wait(wait * 1000)
    local data = proc:read_stdout()
    while data ~= nil do
      res = res .. data
      data = proc:read_stdout()
    end
  end
  return res
end

local function fetch(url)
  local cmd = {"curl", url}
  local result = exec(cmd, config.plugins.updatechecker.timeout)
  return result
end

local function check_updates()
  core.log_quiet("checking for updates...")

  local raw_data = fetch(
    "https://api.github.com/repos/pragtical/pragtical/releases/latest"
  )

  if raw_data == "" then
    core.error(
      "[updatechecker] could not download release information, "
      .. "make sure curl is properly installed"
    )
    return
  end

  local data_read, data = pcall(json.decode, raw_data)

  if data_read == false then
    core.error(
      "[updatechecker] Invalid JSON: %s\n%s\n%s",
      json.last_error(),
      "-----",
      raw_data
    )
    return
  end

  local current_version = "v" .. VERSION:match("^%d+%.%d+%.%d+")

  core.log_quiet("[updatechecker] latest: " .. data.tag_name .. " installed: " .. current_version )

  if current_version == data.tag_name or data.draft or data.prerelease then
    core.log_quiet("[updatechecker] pragtical is up to date")
    return
  end

  core.nag_view:show(
    "new update available",
    "New Pragtical " .. data.tag_name .. " update is available",
    {
      {text = "Ignore", default_no = true},
      {text = "View Release", default_yes = true}
    },
    function(item)
      if item.text == "View Release" then
        core.log("opening in browser...")
        core.add_thread(function()
          open_link(data.html_url)
        end)
      end
    end
  )
end

core.add_thread(function()
  if config.plugins.updatechecker.check_on_startup then
    -- TODO: store last check timestamp to determine if check is necessary
    check_updates()
  end
end)

command.add(nil, {["update-checker:check-for-updates"] = check_updates})
