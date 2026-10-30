-- mod-version:3
local core = require("core")
local command = require("core.command")
local translate = require("core.doc.translate")

local function split_lines(text)
  local res = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(res, line)
  end
  return res
end

local function transform_lines(dv, transform)
  local doc = dv.doc

  local l1, c1, l2, c2, swap = doc:get_selection(true)
  l1, c1 = translate.start_of_line(doc, l1, c1)
  l2, c2 = translate.end_of_line(doc, l2, c2)
  doc:set_selection(l1, c1, l2, c2, swap)

  doc:replace(function(text)
    local head, body, foot = text:match("(\n*)(.-)(\n*)$")
    local lines = split_lines(body)
    transform(lines)
    return head .. table.concat(lines, "\n") .. foot, 1
  end)
end

command.add("core.docview!", {
  -- sort case insensitively (default)
  ["sort:sort"] = function(dv)
    transform_lines(dv, function(lines)
      table.sort(lines, function(a, b)
        return a:lower() < b:lower()
      end)
    end)
  end,
  -- sort case sensitively
  ["sort:case-sensitive"] = function(dv)
    transform_lines(dv, function(lines)
      table.sort(lines)
    end)
  end,
  -- reverse lines, no sort
  ["sort:reverse-lines"] = function(dv)
    transform_lines(dv, function(lines)
      local i, j = 1, #lines
      while i < j do
        lines[i], lines[j] = lines[j], lines[i]
        i, j = i + 1, j - 1
      end
    end)
  end,
})

if core.menu_view then
  core.menu_view:register({ "edit", "lines" }, {
    core.menu_view.DIVIDER,
    { id = "reverse", text = "Reverse Lines", command = "sort:reverse-lines" },
    { id = "sort", text = "Sort Lines", command = "sort:sort" },
    {
      id = "sort_case_sensitive",
      text = "Sort Lines (Case Sensitive)",
      command = "sort:case-sensitive",
    },
  }, "sort")
end
