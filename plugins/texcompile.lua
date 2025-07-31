-- mod-version:3
local core = require "core"
local config = require "core.config"
local command = require "core.command"
local common = require "core.common"
local console = require "plugins.console"
local keymap = require "core.keymap"

-- This plugin requires the console plugin to work. It can be found at:
--
-- https://github.com/pragtical/console
--
-- Before using this plugin add in your user's config file something like:
--
-- config.plugins.texcompile = {
--   latex_command = "pdflatex",
--   view_command = "evince",
-- }
--
-- as long as the commands are in your PATH.
--
-- Options can be passed as part of the command for example like in:
--
-- latex_command = "latex -pdf -pdflatex -c".
--
-- On Windows, if the commands are not in your PATH, you may use the full path
-- of the executable like, for example:
--
-- config.plugins.texcompile = {
--   latex_command = [[C:\miktex\miktex\bin\x64\pdflatex.exe]],
--   view_command = [[C:\Program^ Files\SumatraPDF\SumatraPDF.exe]],
-- }
--
-- Note that in the example we have used "^ " for spaces that appear in the path.
-- It is required on Windows for path or file names that contains space characters.

config.plugins.texcompile = common.merge({
  enabled = true,
  latex_command = "",
  view_command = "",
  -- The config specification used by the settings gui
  config_spec = {
    name = "Latex Compile",
    {
      label = "Latex Compiler Command",
      description = "Name or path to the latex compiler command.",
      path = "latex_command",
      type = "string"
    },
    {
      label = "PDF Viewer Command",
      description = "Name or path to the pdf viewer command.",
      path = "view_command",
      type = "string"
    }
  }
}, config.plugins.texcompile)


command.add("core.docview!", {
  ["texcompile:tex-compile"] = function(dv)
    -- The current (La)TeX file and path
    local texname = dv:get_name()
    local texpath = common.dirname(dv:get_filename())
    local pdfname = texname:gsub("%.tex$", ".pdf")

    -- LaTeX compiler as configured in config.plugins.texcompile
    local texcmd = config.plugins.texcompile and config.plugins.texcompile.latex_command
    local viewcmd = config.plugins.texcompile and config.plugins.texcompile.view_command

    if not texcmd or texcmd == "" then
      core.log("No LaTeX compiler provided in config.")
    else
      core.log("LaTeX compiler is %s, compiling %s", texcmd, texname)

      console.run {
        command = string.format("%s %q", texcmd, texname),
        cwd = texpath,
        on_complete = function()
          core.log("Tex compiling command terminated.")
          if viewcmd and viewcmd ~= ""  then
            system.exec(string.format("%q %q", viewcmd, pdfname))
          elseif common.open_in_system then
            common.open_in_system(pdfname)
          else
            core.log("No PDF viewer provided in config.")
          end
        end
      }
    end
  end,

  ["texcompile:show-pdf-preview"] = function(av)
    -- User's home directory
    local homedir = ""

    if PLATFORM == "Windows" then
        homedir = os.getenv("USERPROFILE")
    else
        homedir = os.getenv("HOME")
    end

    -- The current (La)TeX file
    local texfile = av:get_filename()
    texfile = string.gsub(texfile, '~', homedir)
    -- Construct the PDF file name out of the (La)Tex filename
    local pdffile = "\"" .. string.gsub(texfile, ".tex", ".pdf") .. "\""
    -- PDF viewer - is there any provided by the environment
    local pdfcmd = config.plugins.texcompile and config.plugins.texcompile.view_command

    core.log("Opening pdf preview for \"%s\"", texfile)

    if pdfcmd and pdfcmd ~= "" then
      system.exec(string.format("%q %q", pdfcmd, pdffile))
    elseif common.open_in_system then
      common.open_in_system(pdffile)
    else
      core.log("No PDF viewer provided in config.")
    end

   -- core.add_thread(function()
   --   coroutine.yield(5)
   --   os.remove(htmlfile)
   -- end)
  end
})

keymap.add { ["ctrl+shift+t"] = "texcompile:tex-compile" }
keymap.add { ["ctrl+shift+v"] = "texcompile:show-pdf-preview" }
