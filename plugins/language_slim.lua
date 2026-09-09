-- mod-version:3
local syntax = require "core.syntax"

syntax.add {
  name = "Slim template language",
  files = { "%.slim$", "%.skim$" },
  comment = "/",
  patterns = {
    {
      -- Embedded engine blocks (indented content until next non-indented line).
      -- Matches:
      --   ruby:
      --     body { color: red }
      pattern = { "^%s*ruby:%s*[^\n]*", "^%S" },
      syntax = ".rb",
      type = "function",
    },
    {
      -- Matches:
      --   css:
      --     body { color: red }
      pattern = { "^%s*css:%s*[^\n]*", "^%S" },
      syntax = ".css",
      type = "function",
    },
    {
      -- Matches:
      --   sass:
      --     $c: #fff
      --     body
      --       color: $c
      pattern = { "^%s*sass:%s*[^\n]*", "^%S" },
      syntax = ".sass",
      type = "function",
    },
    {
      -- Matches:
      --   styl:
      --     body
      --       color red
      pattern = { "^%s*styl:%s*[^\n]*", "^%S" },
      syntax = ".styl",
      type = "function",
    },
    {
      -- Matches:
      --   scss:
      --     $c: #fff;
      --     body { color: $c; }
      pattern = { "^%s*scss:%s*[^\n]*", "^%S" },
      syntax = ".scss",
      type = "function",
    },
    {
      -- Matches:
      --   coffee:
      --     alert "hi"
      pattern = { "^%s*coffee:%s*[^\n]*", "^%S" },
      syntax = ".coffee",
      type = "function",
    },
    {
      -- Matches:
      --   javascript:
      --     console.log("hi")
      pattern = { "^%s*javascript:%s*[^\n]*", "^%S" },
      syntax = ".js",
      type = "function",
    },

    {
      -- Slim block comment: a slash line with nested indented lines.
      -- Matches:
      --   / This is a comment block
      --     still commented
      regex = "^%s*/%S[^\n]*$",
      type = "comment",
    },
    {
      -- Slim line comment: slash at line start, no indentation block.
      -- Matches:
      --   /just a comment
      pattern = { "^%s*/%s*", "\n" },
      -- regex = "^%s*/%S[^\n]*$",
      type = "comment",
    },

    {
      -- Escaped content block: literal text starting with | or ' then space/tab.
      -- Matches:
      --   | literal <b>not a tag</b> #{user.name}
      --     continued line
      pattern = { "^%s*[|']%s", "^%S" },
      type = "normal",
      syntax = ".html",
    },

    {
      -- Ruby logic line (control flow): lines starting with "-".
      -- Matches:
      --   - if user
      --   - user.items.each do |i|
      pattern = { "^%s*%-%s*", "\n" },
      syntax = ".rb",
      type = "function",
    },
    {
      -- Ruby output line: lines starting with "=" or "==".
      -- Matches:
      --   = user.name
      --   == render("partial")
      pattern = { "^%s*==?%s*", "\n" },
      syntax = ".rb",
      type = "function",
    },
    {
      -- Ruby interpolation inside text: #{ ... } (best-effort; nested braces not handled).
      -- Matches:
      --   | Hello #{current_user.name}!
      regex = { "(?<!\\\\)#\\{", "\\}" },
      syntax = ".rb",
      type = "function",
    },

    {
      -- Enclosed tag params: `tag[...]` with ruby-ish params.
      -- Matches:
      --   a[href=user_path(user)]
      regex = { "([A-Za-z][%w.#-]*%w)\\[", "\\]" },
      type = "function",
      patterns = {
        {
          -- Attribute name.
          -- Matches:
          --   a[href=...]
          regex = "(?:^|[\\s\\[{(])()\\w[\\w:-]*(?==)",
          type = "keyword2",
        },
        {
          -- Attribute value (ruby expression), starting right after '=' with no space.
          -- Matches:
          --   a[href=user_path(user)]
          regex = "=(?!\\s)([^\\s\\]\\}):)]*)",
          syntax = ".rb",
          type = "string",
        },
        {
          -- Any ruby content inside params.
          -- Matches:
          --   div[data={a: 1, b: foo()}]
          regex = "[^\\]\\n]+",
          syntax = ".rb",
          type = "string",
        },
      },
    },
    {
      -- Enclosed tag params: `tag{...}` with ruby-ish params.
      -- Matches:
      --   div{data: {a: 1}}
      regex = { "([A-Za-z][%w.#-]*%w)\\{", "\\}" },
      type = "function",
      syntax = ".rb",
    },
    {
      -- Enclosed tag params: `tag(...)` with ruby-ish params.
      -- Matches:
      --   input(type="text" value=user.name)
      regex = { "([A-Za-z][%w.#-]*%w)\\(", "\\)" },
      type = "function",
      syntax = ".rb",
    },

    {
      -- Unenclosed tag at start of line (best-effort).
      -- Matches:
      --   div class="a"
      --   .btn#save
      regex = "^%s*([A-Za-z.#][%w.#-]*%w)",
      type = "function",
    },

    {
      -- Illegal line (TextMate's "illegal" rule): line starts with a character
      -- that doesn't look like Slim markup.
      -- Matches:
      --   @@@
      regex = "^%s*[^%w=%.#|\\'%-][^\n]*$",
      type = "comment",
    },

    {
      -- Doctype.
      -- Matches:
      --   doctype html
      pattern = "doctype%s+%S+",
      type = "keyword",
    },

    {
      -- Double-quoted string.
      -- Matches:
      --   a href="x"
      pattern = { '"', '"', '\\' },
      type = "string",
    },
    {
      -- Single-quoted string.
      -- Matches:
      --   a href='x'
      pattern = { "'", "'", '\\' },
      type = "string",
    },

    {
      -- ID shorthand.
      -- Matches:
      --   #main
      pattern = "#[%a][%w_-]*",
      type = "keyword2",
    },
    {
      -- Class shorthand.
      -- Matches:
      --   .btn.primary
      pattern = "%.[%a][%w_.-]*",
      type = "keyword2",
    },
    {
      -- Attribute-like name before '=' (best-effort).
      -- Matches:
      --   href=
      pattern = "[%a][%w_-]*%s*=",
      type = "keyword",
    },
    {
      -- Numbers.
      -- Matches:
      --   123
      --   -12.5
      pattern = "-?%d+[%d%.]*",
      type = "number",
    },
    {
      -- Generic identifiers (best-effort fallback).
      -- Matches:
      --   div
      --   render
      pattern = "[%a][%w]*",
      type = "function",
    },
    {
      -- Operators/punctuation common in Slim.
      -- Matches:
      --   . # = / ( ) [ ] { } | :
      pattern = "[.#=/()%[%]{}|:]",
      type = "operator",
    },
  },
  symbols = {},
}
