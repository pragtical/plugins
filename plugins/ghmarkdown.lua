-- mod-version:3
local core = require "core"
local command = require "core.command"
local common = require "core.common"
local config = require "core.config"
local keymap = require "core.keymap"

config.plugins.ghmarkdown = common.merge({
  -- the url to send POST request to
  url = "https://api.github.com/markdown/raw",
  -- Find information on how to generate your own token at
  -- https://docs.github.com/en/rest/markdown/markdown?apiVersion=2022-11-28#render-a-markdown-document-in-raw-mode
  github_token = "",
   -- The config specification used by the settings gui
  config_spec = {
    name = "Github Markdown Preview",
    {
      label = "URL",
      description = "The URL to POST the request to for formatting.",
      path = "url",
      type = "string",
      default = "https://api.github.com/markdown/raw"
    },
    {
      label = "GitHub token",
      description = "Enter your personal GitHub token",
      path = "github_token",
      type = "string",
      default = ""
    }
  }
}, config.plugins.ghmarkdown)

local open_link
if common.open_in_system then
  open_link = common.open_in_system
else -- backward compatibility with older Pragtical versions
  config.plugins.ghmarkdown.exec_format = PLATFORM == "Windows" and 'start "" %q' or "xdg-open %q"

  table.insert(config.plugins.ghmarkdown, {
    label = "Exec Pattern",
    description = "The string.format() pattern to pass to system.exec.",
    path = "exec_format",
    type = "string",
    default = PLATFORM == "Windows" and 'start "" %q' or "xdg-open %q"
  })

  open_link = function(file)
    system.exec(string.format(config.plugins.ghmarkdown.exec_format, file))
  end
end

local html = [[
<html>
  <style>
    body {
      margin:80 auto 100 auto;
      max-width: 750px;
      line-height: 1.6;
      font-family: Open Sans, Arial;
      color: #444;
      padding: 0 10px;
    }
    h1, h2, h3 { line-height: 1.2; padding-top: 14px; }
    hr { border: 0px; border-top: 1px solid #ddd; }
    code, pre { background: #f3f3f3; padding: 8px; }
    code { padding: 4px; }
    a { text-decoration: none; color: #0366d6; }
    a:hover { text-decoration: underline; }
    table { border-collapse: collapse; }
    table, th, td { border: 1px solid #ddd; padding: 6px; }
  </style>
  <head>
    <title>${title}</title>
  <head>
  <body>
    <script>
      var xhr = new XMLHttpRequest;
      xhr.open("POST", "${url}");
      xhr.setRequestHeader("content-type", "text/plain");
      xhr.setRequestHeader("authorization", "Bearer ${token}");
      xhr.setRequestHeader("x-github-api-version", "2022-11-28");
      xhr.onload = function() { document.body.innerHTML = xhr.responseText; };
      xhr.send("${content}");
    </script>
  </body>
</html>
]]


command.add("core.docview!", {
  ["ghmarkdown:show-preview"] = function(dv)
    if config.plugins.ghmarkdown.github_token == "" then
      core.error "You need to provide your own GitHub token"
      return
    end

    local content = dv.doc:get_text(1, 1, math.huge, math.huge)
    local esc = { ['"'] = '\\"', ["\n"] = '\\n' }
    local text = html:gsub("${(.-)}", {
      title = dv:get_name(),
      url = config.plugins.ghmarkdown.url,
      content = content:gsub(".", esc),
      token = config.plugins.ghmarkdown.github_token
    })

    local htmlfile = core.temp_filename(".html")
    local fp = io.open(htmlfile, "w")
    if fp then
      fp:write(text)
      fp:close()

      core.log("Opening markdown preview for \"%s\"", dv:get_name())
      open_link(htmlfile)

      core.add_thread(function()
        coroutine.yield(5)
        os.remove(htmlfile)
      end)
    else
      core.error("Could not generate markdown preview for \"%s\"", dv:get_name())
    end
  end
})


keymap.add { ["ctrl+alt+m"] = "ghmarkdown:show-preview" }
