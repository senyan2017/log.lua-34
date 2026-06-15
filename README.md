# log.lua
A tiny logging module for Lua. 

![screenshot from 2014-07-04 19 55 55](https://cloud.githubusercontent.com/assets/3920290/3484524/2ea2a9c6-03ad-11e4-9ed5-a9744c6fd75d.png)


## Installation
The [log.lua](log.lua?raw=1) file should be dropped into an existing project
and required by it.
```lua
log = require "log"
``` 


## Usage
log.lua provides 6 functions, each function takes all its arguments,
concatenates them into a string then outputs the string to the console and --
if one is set -- the log file:

* **log.trace(...)**
* **log.debug(...)**
* **log.info(...)**
* **log.warn(...)**
* **log.error(...)**
* **log.fatal(...)**


### Additional options
log.lua provides variables for setting additional options:

#### log.usecolor
Whether colors should be used when outputting to the console, this is `true` by
default. If you're using a console which does not support ANSI color escape
codes then this should be disabled.

#### log.outfile
The name of the file where the log should be written, log files do not contain
ANSI colors and always use the full date rather than just the time. By default
`log.outfile` is `nil` (no log file is used). If a file which does not exist is
set as the `log.outfile` then it is created on the first message logged. If the
file already exists it is appended to.

#### log.level
The minimum level to log, any logging function called with a lower level than
the `log.level` is ignored and no text is outputted or written. By default this
value is set to `"trace"`, the lowest log level, such that no log messages are
ignored.

The level of each log mode, starting with the lowest log level is as follows:
`"trace"` `"debug"` `"info"` `"warn"` `"error"` `"fatal"`


## Logger instances
The module table returned by `require "log"` is itself the default logger, so
the global usage above keeps working exactly as before. When the console log,
the file log or the per-module log level need to differ, create independent
loggers with `log.new`:

```lua
local log = require "log"

-- A logger that only writes to a file, no colors, only warnings and above.
local filelog = log.new {
  name     = "file",
  level    = "warn",
  usecolor = false,
  outfile  = "app.log",
}

-- A separately-named console logger that keeps the trace level.
local netlog = log.new { name = "net" }

log.info("uses the global config")          -- default logger
filelog.warn("written to app.log only")     -- own level/color/outfile
netlog.debug("tagged with the 'net' name")  -- own name prefix
```

`log.new(options)` takes an optional table; any field that is omitted falls
back to a sensible default:

| Option           | Default   | Meaning                                             |
| ---------------- | --------- | --------------------------------------------------- |
| `options.name`     | `nil`     | Name/prefix printed before the source location.     |
| `options.level`    | `"trace"` | Minimum level this logger will output.              |
| `options.usecolor` | `true`    | Whether ANSI colors are used on the console.        |
| `options.outfile`  | `nil`     | File the logger appends to (console only if unset). |

Each logger owns its own `name`, `level`, `usecolor` and `outfile` fields and
never shares mutable state with another logger, so changing one (e.g.
`filelog.level = "error"`) does not affect the others. Call the logging
functions with dot syntax (`logger.info(...)`), just like the global ones. The
default logger also accepts a name via `log.name = "main"`. When no name is set
the output is identical to previous versions of the library.


## Minimal verification
Save the following as `verify.lua` next to `log.lua` and run it with
`lua verify.lua` (or `luajit verify.lua`). It exercises the global logger and
two custom loggers and confirms their level, color, prefix and output file are
independent:

```lua
local log = require "log"

-- 1. Default/global logger: unchanged behaviour, colored, level "trace".
log.info("global logger, colored, trace level")

-- 2. Custom logger "alpha": no colors, level "warn", writes to alpha.log.
local alpha = log.new { name = "alpha", usecolor = false, level = "warn",
                        outfile = "alpha.log" }
alpha.info("filtered out (below warn)")   -- not shown / not written
alpha.error("alpha error -> console + alpha.log")

-- 3. Custom logger "beta": colored, level "trace", writes to beta.log.
local beta = log.new { name = "beta", outfile = "beta.log" }
beta.trace("beta trace -> console + beta.log")

-- Independence checks.
assert(log.usecolor == true,  "global keeps color")
assert(alpha.usecolor == false, "alpha disabled color independently")
assert(beta.usecolor == true,  "beta keeps color independently")
assert(log.name == nil and alpha.name == "alpha" and beta.name == "beta")

-- alpha.log must only contain the error (info was below its level)...
local fa = assert(io.open("alpha.log")); local a = fa:read("*a"); fa:close()
assert(a:find("alpha error") and not a:find("filtered out"), "alpha.log filtered")
-- ...and beta.log must be a separate file with beta's trace line.
local fb = assert(io.open("beta.log")); local b = fb:read("*a"); fb:close()
assert(b:find("beta trace") and not b:find("alpha"), "beta.log is independent")

print("OK: global and custom loggers are independent")
```


## License
This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.

