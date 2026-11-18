-- mod-version:3
local command = require "core.command"
local keymap = require "core.keymap"
local translate = require "core.doc.translate"

command.add("core.docview", {
  ["doc:transpose-chars"] = function(dv)
    local doc = dv.doc
    for idx, line, col, line2, col2 in doc:get_selections(true, true) do
      local has_no_selection = line == line2 and col == col2
      if has_no_selection then
        local pl, pc = doc:position_offset(line, col, translate.previous_char)
        local nl, nc = doc:position_offset(line, col, translate.next_char)
        local chars_on_same_line = pl == nl
        if chars_on_same_line then
          local before = doc:get_text(pl, pc, line, col)
          local after = doc:get_text(line, col, nl, nc)
          local has_char_before = #before > 0
          local has_char_after = #after > 0
          if has_char_before and has_char_after then
            doc:remove(pl, pc, nl, nc)
            doc:insert(pl, pc, after .. before)
            doc:set_selections(idx, line, pc + #after + #before)
          end
        end
      end
    end
    doc:merge_cursors()
  end,
})

keymap.add_direct {
  ["ctrl+t"] = "doc:transpose-chars"
}
