-- mod-version:3.1
local core = require "core"
local command = require "core.command"
local common = require "core.common"


local function exec(cmd)
  local proc = process.start(cmd, {cwd = core.root_project().path})
  while proc:running() do
    coroutine.yield(0.1)
  end
  if proc:returncode() > 0 then
    core.error("ERROR - command: " .. table.concat(cmd, " "))
  end
  return proc:read_stdout() or ""
end


local function git_find_files_and_open(commit)
  local git_root = exec({"git", "rev-parse", "--show-toplevel"}):match( "^%s*(.-)%s*$" )
  local file_list_str = exec({"git", "show", "--name-only", "--pretty=format:", commit})

  local git_files = {}
  for str in string.gmatch(file_list_str, "([^\n]+)") do
    git_files[git_root .. PATHSEP .. str] = true
  end

  for file, flag in pairs(git_files) do
    if system.get_file_info(file) then
      core.root_view:open_doc(core.open_doc(file))
    end
  end
end

-- works in any context
command.add(nil, {
  ["gitopen:open-from-commit"] = function(dv)
    core.command_view:enter("Which commit? (default=HEAD)", {
      submit = function(commit)
        if commit == nil or commit == "" then
          commit = "HEAD"
        end
        -- open the files in the background, return immediately
        core.add_thread(
          function ()
            git_find_files_and_open(commit)
          end
        )
      end
    })
  end,
})
