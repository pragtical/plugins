# EditorConfig

This plugin implements the [EditorConfig](https://editorconfig.org/) spec
purely on lua by leveraging lua patterns and the regex engine on pragtical.
Installing additional dependencies is not required.

The EditorConfig spec was implemented as best understood,
if you find any bugs please report them on this repository
[issue tracker](https://github.com/pragtical/plugins/issues).

## Implemented Features

Global options:

* root - prevents upward searching of .editorconfig files

Applied to documents indent info:

* indent_style
* indent_size
* tab_width

Applied on document save:

* charset
* end_of_line - if set to `cr` it is ignored
* trim_trailing_whitespace
* insert_final_newline boolean

## Extras

* Supports multiple project directories
* Implements hot reloading, so modifying an .editorconfig file from within
  the editor will re-apply all rules to currently opened files.

## Testing

This plugin includes a test suite to check how well the .editorconfig parser
is working.

The [editorconfig-core-test](https://github.com/editorconfig/editorconfig-core-test)
glob, parser and properties cmake tests where ported and we are getting a 100%
pass rate.

If you are interested in running the test suite, from the terminal execute
the following:

```sh
pragtical test editorconfig
```

To inspect the generated sections and regex rules:

```sh
pragtical test editorconfig --parsers
```
