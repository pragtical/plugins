-- mod-version:3

---Skip plugin if missing json dependency
local json_found, json = pcall(require, "libraries.json")
if not json_found then return end

local core = require "core"
local cli = require "core.cli"
local common = require "core.common"

local skipped_libraries = {
  ["core.bit"] = true,
  ["core.encoding"] = true,
  ["core.start"] = true,
  ["core.strict"] = true,
  ["core.utf8string"] = true,
  ["plugins.gendocs"] = true,
}

---Split a string by the given delimeter
---@param s string The string to split
---@param delimeter string Delimeter without lua patterns
---@param delimeter_pattern? string Optional delimeter with lua patterns
---@return table
---@return boolean ends_with_delimiter
local function split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local last_idx = 1
  local result = {}
  for match_idx, afer_match_idx in s:gmatch("()"..delimeter_pattern.."()") do
    table.insert(result, string.sub(s, last_idx, match_idx - 1))
    last_idx = afer_match_idx
  end
  if last_idx > #s then
    return result, true
  else
    table.insert(result, string.sub(s, last_idx))
    return result, false
  end
end

---Check if a file exists.
---@param file_path string
---@return boolean
local function file_exists(file_path)
  local file = io.open(file_path, "r")
  if file ~= nil then
    file:close()
    return true
  end
 return false
end

---Used on windows to check if command is a valid executable on the given path.
---
---If the command does not contains a file extension it will automatically
---search using the extensions: .exe, .cmd or .bat in that same order.
---@param command string
---@param path? string
---@return boolean
local function win_command_exists(command, path)
  path = path or ""
  local extensions = {"exe", "cmd", "bat"}
  local has_extension = false
  for _, ext in ipairs(extensions) do
    if command:lower():find("%."..ext.."$") then
      has_extension = true
      break
    end
  end
  if has_extension then
    if file_exists(path .. command) then
      return true
    end
  else
    for _, ext in ipairs(extensions) do
      local command_ext = command .. "." .. ext
      if file_exists(path .. command_ext) then
        return true
      end
    end
  end
  return false
end

---Check if a command exists on the system by inspecting the PATH envar.
---@param command string
---@return boolean
local function command_exists(command)
  local is_win = PLATFORM == "Windows"

  if file_exists(command) or (is_win and win_command_exists(command)) then
    return true
  end

  local env_path = os.getenv("PATH") or ""
  local path_list = {}

  if not is_win then
    path_list = split(env_path, ":")
  else
    path_list = split(env_path, ";")
  end

  -- Automatic support for brew, macports, etc...
  if PLATFORM == "Mac OS X" then
    if
      system.get_file_info("/usr/local/bin")
      and
      not string.find(env_path, "/usr/local/bin", 1, true)
    then
      table.insert(path_list, 1, "/usr/local/bin")
      system.setenv("PATH", table.concat(path_list, ":"))
    end
  end

  for _, path in pairs(path_list) do
    local path_fix = path:gsub("[/\\]$", "") .. PATHSEP
    if file_exists(path_fix .. command) then
      return true
    elseif is_win and win_command_exists(command, path_fix) then
      return true
    end
  end

  return false
end

local function uri_decode(value)
  return value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function normalize_source_path(path)
  path = path:gsub("\\", "/"):gsub("/+$", "")
  if PLATFORM == "Windows" then
    path = path:gsub("^/([%a]:/)", "%1")
  end
  return path
end

local function library_name(file)
  return file
    :gsub("[\\/]", "/")
    :gsub("^%.?/", "")
    :gsub("%.lua$", "")
    :gsub("/", ".")
    :gsub("%.init$", "")
end

local function markdown_anchor(heading)
  return heading:lower()
    :gsub("[^%w%s_%-]", "")
    :gsub("%s+", "-")
    :gsub("%-+", "-")
    :gsub("^%-", "")
    :gsub("%-$", "")
end

local function source_link_target(uri, docs_root, label, link_headings)
  local uri_path = uri:match("^file://([^#]+)")
  if not uri_path then return end

  local source_path = normalize_source_path(uri_decode(uri_path))
  local root_path = normalize_source_path(docs_root)
  local source_compare = source_path
  local root_compare = root_path
  if PLATFORM == "Windows" then
    source_compare = source_compare:lower()
    root_compare = root_compare:lower()
  end

  local root_prefix = root_compare .. "/"
  if source_compare:sub(1, #root_prefix) ~= root_prefix then return end

  local relative_path = source_path:sub(#root_path + 2)
  if not relative_path:match("%.lua$") then return end

  local library = library_name(relative_path)
  if
    skipped_libraries[library]
    or (label ~= library and label:sub(1, #library + 1) ~= library .. ".")
  then
    return
  end

  local heading = link_headings[label]
  if not heading then return end

  local anchor = markdown_anchor(heading)
  if anchor == "" then return end

  return string.format("[%s](/docs/api/%s#%s)", label, library, anchor)
end

---@param markdown string
---@param docs_root string
---@param link_headings table<string,string>
---@return string
local function clean_markdown(markdown, docs_root, link_headings)
  local links = {}
  markdown = markdown:gsub(
    "%[([^%]]+)%]%((file://[^%)]+)%)",
    function(label, uri)
      local target = source_link_target(uri, docs_root, label, link_headings)
      if not target then return label end

      table.insert(links, target)
      return "\1GENDOCS_LINK_" .. #links .. "\2"
    end
  )

  markdown = markdown:gsub("</?br/?>", "")
    :gsub("%[", "\\[")
    :gsub("%]", "\\]")
    :gsub("%{", "\\{")
    :gsub("%}", "\\}")
    :gsub("<", "\\<")
    :gsub(">", "\\>")
    :gsub("^%s*", "")
    :gsub("%s$", "")

  return markdown:gsub("\1GENDOCS_LINK_(%d+)\2", function(index)
    return links[tonumber(index)]
  end)
end

---@alias plugins.gendocs.lls.view string | "string" | "unknown"

---@alias plugins.gendocs.lls.type
---| string
---| "doc.class"
---| "setglobal"
---| "setfield"
---| "setmethod"
---| "variable"
---| "type"

---@alias plugins.gendocs.lls.position table<integer,integer>

---@class plugins.gendocs.lls.arg
---@field name? string
---@field desc? string
---@field rawdesc? string
---@field start plugins.gendocs.lls.position
---@field finish plugins.gendocs.lls.position
---@field type plugins.gendocs.lls.type
---@field view plugins.gendocs.lls.view

---@class plugins.gendocs.lls.return
---@field name? string
---@field desc? string
---@field rawdesc? string
---@field type plugins.gendocs.lls.type
---@field view plugins.gendocs.lls.view

---@class plugins.gendocs.lls.extends
---If defining a function this field contains the parameters.
---@field args? plugins.gendocs.lls.arg[]
---If defining a function this field contains the return types.
---@field returns? plugins.gendocs.lls.return[]
---Plain text description of symbol
---@field desc? string
---Description of symbol including markdown styling
---@field rawdesc? string
---@field start plugins.gendocs.lls.position
---@field finish plugins.gendocs.lls.position
---@field type plugins.gendocs.lls.type
---@field view plugins.gendocs.lls.view

---@class plugins.gendocs.lls.define
---Indicates if definition supports async
---@field async? boolean
---Flag that indicates if definition is deprecated
---@field deprecated? boolean
---Plain text description of symbol
---@field desc? string
---Description of symbol including markdown styling
---@field rawdesc? string
---More detailed information about the entry data type
---@field extends? plugins.gendocs.lls.extends
---If it starts with [FORIEGN] it should be skipped
---@field file? string
---Location where the symbol definition starts in the file
---@field start plugins.gendocs.lls.position
---Location where the symbol definition ends in the file
---@field finish plugins.gendocs.lls.position
---Language server type
---@field type plugins.gendocs.lls.type
---User given data type
---@field view string
---Visibility
---@field visible "public" | "private" | "protected"

---@class plugins.gendocs.lls.field
---Name of the field
---@field name? string
---Indicates if definition supports async
---@field async? boolean
---Flag that indicates if definition is deprecated
---@field deprecated? boolean
---Plain text description of symbol
---@field desc? string
---Description of symbol including markdown styling
---@field rawdesc? string
---More detailed information about the entry data type
---@field extends? plugins.gendocs.lls.extends
---If it starts with [FORIEGN] it should be skipped
---@field file? string
---Location where the symbol definition starts in the file
---@field start plugins.gendocs.lls.position
---Location where the symbol definition ends in the file
---@field finish plugins.gendocs.lls.position
---Language server type
---@field type plugins.gendocs.lls.type
---User given data type
---@field view string
---Visibility
---@field visible "public" | "private" | "protected"

---@class plugins.gendocs.lls.symbol
---@field name string
---@field type plugins.gendocs.lls.type
---@field view plugins.gendocs.lls.view
---@field defines plugins.gendocs.lls.define[]
---@field fields plugins.gendocs.lls.field[]

---@class plugins.gendocs.lls.element
---@field desc string
---@field def string
---@field params? plugins.gendocs.function_entry[]
---@field returns? plugins.gendocs.function_entry[]

---@class plugins.gendocs.function_entry
---@field name? string
---@field view string
---@field desc string
---@field optional? boolean

---@class plugins.gendocs.lls.library
---@field lib string
---@field name string
---@field desc string
---@field fields table<string,plugins.gendocs.lls.element>
---@field functions table<string,plugins.gendocs.lls.element>
---@field methods table<string,plugins.gendocs.lls.element>
---@field types table<string,plugins.gendocs.lls.library>

---List of registered system globals.
---@type table<string,plugins.gendocs.lls.element>
local globals = {}

---List of library definitions.
---@type table<string,plugins.gendocs.lls.library>
local libraries = {}

---Generated API target for each known custom type.
---@type table<string,string>
local type_targets = {}

---List of library names.
---@type table<integer,string>
local libraries_list = {}

---The sidebar position number to use when generating markdown pages.
---This number is incremented each time it is used. It is set to 2 because
---We manually generate the globals.md file with position set to 1.
---@type integer
local lib_position = 2

local function normalize_optional_type(view)
  local inner = view:match("^%((.*)%)%?$")
  if inner then return inner, true end
  if view:sub(-1) == "?" then return view:sub(1, -2), true end
  return view, false
end

local function function_element(source, definition, path, link_headings)
  local extends = source.extends or {}
  local params = {}
  for _, arg in ipairs(extends.args or {}) do
    if arg.type ~= "self" then
      local view, optional = normalize_optional_type(tostring(arg.view or ""))
      table.insert(params, {
        name = arg.name,
        view = view,
        desc = clean_markdown(arg.rawdesc or arg.desc or "", path, link_headings),
        optional = optional,
      })
    end
  end

  local returns = {}
  for _, value in ipairs(extends.returns or {}) do
    table.insert(returns, {
      name = value.name,
      view = tostring(value.view or ""),
      desc = clean_markdown(
        value.rawdesc or value.desc or "",
        path,
        link_headings
      ),
    })
  end

  return {
    desc = clean_markdown(
      source.rawdesc or extends.rawdesc or "",
      path,
      link_headings
    ),
    def = "```lua\n" .. definition .. "\n```",
    params = params,
    returns = returns,
  }
end

---Parse the generated LuaLS documentation and make it ready to generate docs.
---@param path string
---@param output_dir
local function parse_docs(path, output_dir)
  print ""
  print(cli.colorize("Parsing files on:", "green") .. "\n\n  " .. path)
  print ""
  local lls = io.popen(
    "lua-language-server "
      .. "--doc="..path .. " "
      .. "--doc_out_path="..output_dir,
    "r"
  )
  if not lls then
    print(
      cli.colorize("Error:", "red")
        .. " "
        .. "could not properly run lua-language-server"
    )
    os.exit(1)
  end
  print(cli.colorize("Language Server Output:", "green") .. "\n")
  print(cli.colorize(lls:read("*a"), "liteblue"))
  local success, exitcode, code = lls:close()

  local output = io.open(output_dir..PATHSEP.."doc.json", "r")

  ---@type plugins.gendocs.lls.symbol[]
  local data = json.decode(output:read("*a"))

  ---@type table<string,string>
  local link_headings = {}
  -- Standalone types use qualified headings; fields use their short names.
  for _, symbol in ipairs(data) do
    if symbol.type == "type" then
      link_headings[symbol.name] = symbol.name
      local define = symbol.defines[1]
      if define and define.file and not define.file:match("^%[FOR") then
        local lib_name = library_name(define.file)
        if not skipped_libraries[lib_name] then
          local target = "/docs/api/" .. lib_name
          if symbol.name ~= lib_name then
            target = target .. "#" .. markdown_anchor(symbol.name)
          end
          type_targets[symbol.name] = type_targets[symbol.name] or target
        end
      end
    end
  end
  for _, symbol in ipairs(data) do
    if symbol.type == "type" then
      for _, field in ipairs(symbol.fields or {}) do
        local name = symbol.name .. "." .. field.name
        link_headings[name] = link_headings[name] or field.name
      end
    end
  end

  ---@type string
  local prev_lib_name = ""
  for _, symbol in ipairs(data) do
    local define = symbol.defines[1]
    if define and define.file and not define.file:match("^%[FOR") then
      local lib_name = library_name(define.file)
      if prev_lib_name ~= lib_name then
        prev_lib_name = lib_name
        if not libraries[lib_name] then
          table.insert(libraries_list, lib_name)
          libraries[lib_name] = {
            lib = lib_name,
            name = symbol.name,
            desc = (
              symbol.name == lib_name
              and clean_markdown(define.desc or "", path, link_headings)
              or ""
            ),
            fields = {},
            methods = {},
            functions = {},
            types = {}
          }
        end
      end
      if symbol.type ~= "type" then
        if define.type == "setglobal" then
          if not globals[symbol.name] then
            local definition = "global "..symbol.name..": " .. define.view
            if define.view == "function" then
              globals[symbol.name] = function_element(
                define,
                definition,
                path,
                link_headings
              )
            else
              globals[symbol.name] = {
                desc = clean_markdown(define.desc or "", path, link_headings),
                def = "```lua\n" .. definition .. "\n```"
              }
            end
          end
        elseif define.type == "setmethod" or define.type == "setfield" then
          if define.view == "function" then
            libraries[lib_name].functions[symbol.name] = function_element(
              define,
              define.extends.view,
              path,
              link_headings
            )
          else
            libraries[lib_name].fields[symbol.name] = {
              desc = clean_markdown(define.desc or "", path, link_headings),
              def = "```lua\n"
                .. "(field) "..symbol.name..": " .. define.view .. "\n"
                .. "```"
            }
          end
        else
          print ("Unhandled type:", define.type)
        end
      else
        if
          symbol.name == lib_name and
          (
            not libraries[lib_name].desc
            or
            libraries[lib_name].desc == ""
          )
          and symbol.defines[1].desc
        then
          libraries[lib_name].desc = clean_markdown(
            symbol.defines[1].desc,
            path,
            link_headings
          )
        end

        if not libraries[lib_name].types[symbol.name] then
          libraries[lib_name].types[symbol.name] = {
            lib = lib_name,
            name = symbol.name,
            desc = clean_markdown(
              symbol.desc or symbol.defines[1].desc or "",
              path,
              link_headings
            ),
            fields = {},
            functions = {},
            methods = {}
          }
        end
        for _, field in ipairs(symbol.fields) do
          if field.view ~= "function" then
            libraries[lib_name].types[symbol.name].fields[field.name] = {
              lib = lib_name,
              name = symbol.name,
              desc = clean_markdown(field.desc or "", path, link_headings),
              def = "```lua\n"
                .. "(field) "..field.name..": " .. field.view .. "\n"
                .. "```"
            }
          else
            if field.type == "setfield" then
              libraries[lib_name].types[symbol.name].functions[field.name] =
                function_element(
                  field,
                  field.extends.view,
                  path,
                  link_headings
                )
            else
              libraries[lib_name].types[symbol.name].methods[field.name] =
                function_element(
                  field,
                  field.extends.view,
                  path,
                  link_headings
                )
            end
          end
        end
      end
    elseif not define then
      print(
        cli.colorize("Warning: ", "yellow")
          .. "No defines on symbol or invalid entry:"
      )
      print(common.serialize(symbol, {pretty = true}))
    end
  end
end

---@generic T: table, K, V
---@param list T
---@return fun(table: table<K, V>, index?: K):K, V
---@return T
local function ordered(list)
  local names = {}
  for name, _ in pairs(list) do
    table.insert(names, name)
  end
  table.sort(names)
  return coroutine.wrap(function()
    for _, name in ipairs(names) do
      coroutine.yield(name, list[name])
    end
  end)
end

local function inline_code(value)
  local delimiter = "`"
  while value:find(delimiter, 1, true) do
    delimiter = delimiter .. "`"
  end
  return delimiter .. value .. delimiter
end

local builtin_types = {
  ["any"] = true,
  ["boolean"] = true,
  ["false"] = true,
  ["function"] = true,
  ["integer"] = true,
  ["lightuserdata"] = true,
  ["never"] = true,
  ["nil"] = true,
  ["number"] = true,
  ["string"] = true,
  ["table"] = true,
  ["thread"] = true,
  ["true"] = true,
  ["unknown"] = true,
  ["userdata"] = true,
}

local function format_type(view)
  if view == "" then return "", false end

  local parts = {}
  local offset = 1
  local last = 1
  local linked = false
  while offset <= #view do
    local start_idx, original_end = view:find("[%a_][%w_%.]*", offset)
    if not start_idx then break end

    local end_idx = original_end
    local type_name = view:sub(start_idx, end_idx)
    while type_name:sub(-1) == "." do
      type_name = type_name:sub(1, -2)
      end_idx = end_idx - 1
    end

    local target = not builtin_types[type_name] and type_targets[type_name]
    local previous = view:sub(start_idx - 1, start_idx - 1)
    local following = view:sub(end_idx + 1, end_idx + 1)
    local quoted = (previous == '"' or previous == "'") and following == previous
    if target and not quoted then
      if start_idx > last then
        table.insert(parts, inline_code(view:sub(last, start_idx - 1)))
      end
      table.insert(parts, "[" .. inline_code(type_name) .. "](" .. target .. ")")
      last = end_idx + 1
      linked = true
    end

    offset = original_end + 1
  end

  if not linked then return inline_code(view), false end
  if last <= #view then
    table.insert(parts, inline_code(view:sub(last)))
  end
  return table.concat(parts), true
end

local function metadata_line(kind, entry)
  local type_view, has_link = format_type(entry.view)
  local has_name = entry.name and entry.name ~= ""
  if kind == "param" then
    if entry.desc == "" and not has_link then return end
  elseif not has_name and entry.desc == "" and not has_link then
    return
  end

  local line = "@*" .. kind .. "*"
  if has_name then
    local name = entry.name .. (entry.optional and "?" or "")
    line = line .. " " .. inline_code(name)
  end
  if type_view ~= "" then
    line = line .. ": " .. type_view
  end
  if entry.desc ~= "" then
    line = line .. " — " .. entry.desc
  end
  return line
end

local function element_docs(element)
  local blocks = {}
  if element.desc and element.desc ~= "" then
    table.insert(blocks, element.desc)
  end
  for _, param in ipairs(element.params or {}) do
    local line = metadata_line("param", param)
    if line then table.insert(blocks, line) end
  end
  for _, value in ipairs(element.returns or {}) do
    local line = metadata_line("return", value)
    if line then table.insert(blocks, line) end
  end
  if #blocks == 0 then return "" end
  return table.concat(blocks, "\n\n") .. "\n\n"
end

---@param type plugins.gendocs.lls.library
---@param file file*
local function generate_type_docs(type, file, indent)
  indent = indent or "#"
  for name, field in ordered(type.fields) do
    if
      not libraries[type.lib].types[type.lib.."."..name]
      or
      libraries[type.lib].types[type.lib.."."..name].lib ~= type.lib.."."..name
    then
      file:write(
        indent .. "## " .. name .. "\n\n"
        .. field.def .. "\n\n"
        .. element_docs(field)
        .. "---\n\n"
      )
    else
      file:write(
        indent .. "## " .. name .. "\n\n"
        .. element_docs(field)
      )
      generate_type_docs(
        libraries[type.lib].types[type.lib.."."..name],
        file,
        indent .. "#"
      )
    end
  end
  for name, field in ordered(type.functions) do
    file:write(
      indent .. "## " .. name .. "\n\n"
      .. field.def .. "\n\n"
      .. element_docs(field)
      .. "---\n\n"
    )
  end
  for name, field in ordered(type.methods) do
    file:write(
      indent .. "## " .. name .. "\n\n"
      .. field.def .. "\n\n"
      .. element_docs(field)
      .. "---\n\n"
    )
  end
end


---Generate documentation.
---@param library string
---@param output string
---@param show_require? boolean
local function generate_docs(library, output, show_require)
  local file, errmsg = io.open(output .. PATHSEP .. library .. ".md", "w")
  if file then
    local lib = libraries[library]
    if not lib then
      print ""
      print(string.format(
        cli.colorize("Warning:", "yellow")
          .. " "
          .. "library '%s' not found.",
        library
      ))
      return
    end

    file:write(
      "---\n"
      .. "sidebar_position: " .. lib_position .. "\n"
      .. "---\n\n"
    )

    file:write("<!-- DO NOT EDIT: file generated with `pragtical gendocs` -->\n\n")

    file:write("# " .. library .. "\n\n")

    if lib.desc and lib.desc ~= "" then
      file:write(lib.desc .. "\n\n")
    end

    if show_require then
      local varname = library:match("%.([%a_][%w_]*)$") or library
      file:write(
        "```lua\n"
        .. "local "..varname.." = require \""..library.."\"\n"
        .. "```"
        .. "\n\n"
      )
    end

    if lib.types[library] then
      local type = lib.types[library]
      for name, field in ordered(type.fields) do
        if not lib.types[library.."."..name] then
          file:write(
            "## " .. name .. "\n\n"
            .. field.def .. "\n\n"
            .. element_docs(field)
            .. "---\n\n"
          )
        end
      end
      for name, field in ordered(lib.types) do
        if name ~= library then
          file:write(
            "## " .. name .. "\n\n"
            .. element_docs(field)
          )
          generate_type_docs(
            field,
            file,
            "#"
          )
        end
      end
      for name, field in ordered(type.functions) do
        file:write(
          "## " .. name .. "\n\n"
          .. field.def .. "\n\n"
          .. element_docs(field)
          .. "---\n\n"
        )
      end
      for name, field in ordered(type.methods) do
        file:write(
          "## " .. name .. "\n\n"
          .. field.def .. "\n\n"
          .. element_docs(field)
          .. "---\n\n"
        )
      end
    else
      for name, field in ordered(lib.fields) do
        if not lib.types[library.."."..name] then
          file:write(
            "## " .. name .. "\n\n"
            .. field.def .. "\n\n"
            .. element_docs(field)
            .. "---\n\n"
          )
        else
          file:write(
            "## " .. library.."."..name .. "\n\n"
            .. element_docs(field)
          )
          generate_type_docs(
            lib.types[library.."."..name],
            file
          )
        end
      end
      for name, field in ordered(lib.types) do
        if name ~= library then
          file:write(
            "## " .. name .. "\n\n"
            .. element_docs(field)
          )
          generate_type_docs(
            field,
            file,
            "#"
          )
        end
      end
      for name, field in ordered(lib.functions) do
        file:write(
          "## " .. name .. "\n\n"
          .. field.def .. "\n\n"
          .. element_docs(field)
          .. "---\n\n"
        )
      end
      for name, field in ordered(lib.methods) do
        file:write(
          "## " .. name .. "\n\n"
          .. field.def .. "\n\n"
          .. element_docs(field)
          .. "---\n\n"
        )
      end
    end
    file:close()
    lib_position = lib_position + 1
  end
end

cli.register({
  command = "gendocs",
  description = "Generate documentation of the api in markdown format.",
  long_description = "In order to use this command you should have the\n"
    .. "lua-language-server installed. For more information\n"
    .. "about this language server visit:\n\n"
    .. "  * https://luals.github.io/\n"
    .. "  * https://github.com/luals/lua-language-server",
  exit_editor = true,
  usage = "[options]\n\n"
    .. "  Example: gendocs --output=/path/to/pragtical.github.io/docs/api",
  flags = {
    {
      name = "output",
      short_name = "o",
      description = "Path to store the documentation",
      type = "string",
      value = "output"
    },
    {
      name = "keep",
      short_name = "k",
      description = "Keep language server generated files"
    }
  },
  execute = function(flags, arguments)
    -- revert to the initial working directory since the output flag
    -- can get interpreted as a project directory and we may need initial.
    system.chdir(core.init_working_dir)

    local output_dir = "output"
    local keep = false

    for _, flag in ipairs(flags) do
      if flag.name == "output" then
        output_dir = flag.value:gsub("[\\/]$", "")
      elseif flag.name == "keep" then
        keep = true
      end
    end

    -- make output directory if not exists
    if not system.get_file_info(output_dir) then
      common.mkdirp(output_dir)
    end

    -- change output directory to absolute format and print it
    output_dir = system.absolute_path(output_dir)
    print(cli.colorize("\nOutput Directory:", "green") .. "\n\n  " .. output_dir)

    if not command_exists("lua-language-server") then
      print(
        cli.colorize("\nError:", "red")
        .. " "
        .. "lua-language-server not found in path"
      )
      os.exit(1)
    end

    local system_libs = {}
    local core_docs_path = system.absolute_path("data")

    -- detect if running the generator directly from the sources directory
    -- and use it to generate the documentation
    if file_exists("docs"..PATHSEP.."api") then
      -- parse the Lua C libraries
      parse_docs(system.absolute_path("docs"..PATHSEP.."api"), output_dir)

      table.sort(libraries_list)
      for _, libname in pairs(libraries_list) do
        if libname ~= "globals" then
          table.insert(system_libs, libname)
        end
      end
    else
      core_docs_path = DATADIR
      system_libs = {
        "bit",
        "canvas",
        "diff",
        "dirmonitor",
        "encoding",
        "globals",
        "net",
        "process",
        "regex",
        "renderer",
        "renwindow",
        "repl",
        "shmem",
        "string",
        "system",
        "thread",
        "tokenizer",
        "utf8extra",
      }
      for i = #system_libs, 1, -1 do
        if not file_exists(DATADIR..PATHSEP..system_libs[i]..".lua") then
          table.remove(system_libs, i)
        end
      end
      -- we need to parse C Lua libs first to prevent issues
      -- so we copy them to output, parse and then delete
      for _, name in ipairs(system_libs) do
        local succ, exitcode = os.execute(
          "cp "
          .. "\""..DATADIR..PATHSEP..name..".lua".."\" "
          .. "\""..output_dir..PATHSEP..name..".lua".."\""
        )
        if not succ then
          print ""
          print(
            cli.colorize("Error: ", "red")
              .. "Could not copy "
              .. DATADIR..PATHSEP..name
          )
          os.exit(1)
        end
      end
      parse_docs(output_dir, output_dir)
      for _, name in ipairs(system_libs) do
        common.rm(output_dir..PATHSEP..name..".lua")
      end
    end

    -- parse the editor libraries
    parse_docs(core_docs_path, output_dir)
    table.sort(libraries_list)

    -- generate documentation for Lua C libraries first
    table.sort(system_libs)
    for _, libname in pairs(system_libs) do
      generate_docs(libname, output_dir, false)
    end

    -- skip some libraries
    for libname in pairs(skipped_libraries) do
      table.insert(system_libs, libname)
    end

    -- generate documentation for Lua libraries
    for _, libname in pairs(libraries_list) do
      local is_system = false
      for _, system_lib in ipairs(system_libs) do
        if libname == system_lib then
          is_system = true
          break
        end
      end
      if not is_system then
        generate_docs(libname, output_dir, true)
      end
    end

    -- generate documentation of available globals
    local file = io.open(output_dir..PATHSEP.."globals.md", "w")
    if file then
      file:write(
        "---\n"
        .. "sidebar_position: 1\n"
        .. "---\n\n"
        .. "<!-- DO NOT EDIT: file generated with `pragtical gendocs` -->\n\n"
        .. "# Globals\n\n"
        .. "Available system globals.\n\n"
      )
      for name, global in ordered(globals) do
        file:write(
          "## " .. name .. "\n\n"
          .. global.def .. "\n\n"
          .. element_docs(global)
        )
        if libraries[name] and global.def:find(":%s*"..name) then
          file:write(
            "[\\[View Library\\]](/docs/api/"..name..")\n\n"
          )
        end
        file:write("---\n\n")
      end
      file:close()
    end

    -- remove LuaLS generated output
    if not keep then
      common.rm(output_dir .. PATHSEP .. "doc.md")
      common.rm(output_dir .. PATHSEP .. "doc.json")
    end

    print("\n" .. cli.colorize("Documentation generated!", "green"))
  end
})
