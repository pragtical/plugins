# Profiler Plugin

Profiling is mainly the runtime analysis of a program performance by counting
the calls and duration for the various routines executed thru the lifecycle
of the application. For more information view the [wikipedia] article.

This plugin adds the ability to profile function calls while running Pragtical,
becoming easier to investigate performance related issues and pinpoint what
could be causing them. It integrates the [lua-profiler] when running with
PUC LUA or the more performant [luajit-profiler] when running with LuaJIT.

## Usage

Open Pragtical and access the command palette by pressing `ctrl+shift+p` and
search for `profiler`. The command `Profiler: Toggle` will be shown to let you
start or stop the profiler. You should start the profiler before triggering
the events that are causing any performance issues.

![command](https://user-images.githubusercontent.com/1702572/202113672-6ba593d9-03be-4462-9e82-e3339cf2722f.png)

> **Note:** Starting the profiler with the [lua-profiler] will make the editor
> slower since it is now accumulating metrics about every function call. Do not
> worry, this is expected and shouldn't affect the end result, just be patience
> because everything will be slower. (performance impact is barely noticeable
> when using the [luajit-profiler])

There may be some situations when you would like to enable the profiler
early on the startup process so we provided a configuration option for that.
Also the profiler output is saved to a log file for easy sharing, its default
path is also configurable as shown below:

![settings](https://user-images.githubusercontent.com/1702572/202113713-7e932b4f-3283-42e6-af92-a1aa9ad09bde.png)

> **Note:** since the profiler is not part of the core, but a plugin, it will
> only start accumulating metrics once the plugin is loaded. The `priority`
> tag of the profiler plugin was set to `0` to make it one of the first
> plugins to start.

Once you have profiled enough you can execute the `Profiler: Toggle` command
to stop it, the log will be automatically open with the collected metrics
as shown below:

![metrics](https://user-images.githubusercontent.com/1702572/202113736-ef8d550c-130e-4372-b66c-694ee5f4c5c0.png)

## LuaJIT Profiler

When the editor is compiled with LuaJIT support a native more performant
profiler developed by Mike Pall can be use. This profiler allows generating
raw data that can be read by third party tools to generate more graphical
visualizations like [FlameGraph], eg: `flamegraph profiler.log out.svg`.

It also offers more control on the output data by using flags documented below.
By default the highlevel profiler developed by Mike Pall is included and used
by this plugin, if you disable the highlevel profiler a more basic dump will
be generated.

Support for displaying code `zones` with the highlevel profiler is available
by using the `z` flag. To give regions of your code a certain name you can
do the following:

```lua
local zone = require("plugins.profiler.zone")
zone("ZoneName")
  --- ... your lua code here
  zone("ZoneNameTwo")
    --- ... your lua code here
  zone()
  --- ... your lua code here
zone()
```

### HighLevel JIT Profiler Flags

* `f` - Stack dump: function name, otherwise module:line. Default mode.
* `F` - Stack dump: ditto, but always prepend module.
* `l` - Stack dump: module:line.
* `<number>` - stack dump depth (callee < caller). Default: 1.
* `-<number>` - Inverse stack dump depth (caller > callee).
* `s` - Split stack dump after first stack level. Implies abs(depth) >= 2.
* `p` - Show full path for module names.
* `v` - Show VM states. Can be combined with stack dumps, e.g. vf or fv.
* `z` - Show zones. Can be combined with stack dumps, e.g. zf or fz.
* `r` - Show raw sample counts. Default: show percentages.
* `a` - Annotate excerpts from source code files.
* `A` - Annotate complete source code files.
* `G` - Produce raw output suitable for graphical tools (e.g. flame graphs).
* `m<number>` - Minimum sample percentage to be shown. Default: 3.
* `i<number>` - Sampling interval in milliseconds. Default: 10.

## Last Steps

You can send Pragtical developers the output of `profiler.log` for easier
diagnosing of performant related issues.

[wikipedia]: https://en.wikipedia.org/wiki/Profiling_(computer_programming)
[lua-profiler]: https://github.com/charlesmallah/lua-profiler
[luajit-profiler]: https://github.com/LuaJIT/LuaJIT/blob/v2.1/doc/ext_profiler.html
[FlameGraph]: https://github.com/brendangregg/FlameGraph
