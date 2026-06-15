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

In addition to the module-level (default) logger, you can create independent
logger instances via `log.new(options)`. Each instance carries its own level,
color switch, output file, and optional name/prefix — changes to one instance
do not affect others or the global logger.

```lua
log = require "log"

-- Create a logger for the database layer
local db_log = log.new({
  level    = "debug",
  usecolor = true,
  outfile  = "db.log",
  name     = "DB",
})

-- Create a quiet logger for network noise
local net_log = log.new({
  level    = "warn",   -- only warn/error/fatal pass through
  usecolor = false,
  name     = "NET",
})

db_log:info("connection established")    -- printed (info >= debug)
db_log:trace("raw query bytes: ...")     -- suppressed (trace < debug)

net_log:debug("TCP handshake ok")        -- suppressed (debug < warn)
net_log:warn("retry #2 to api.example.com")  -- printed
```

### Options

| Option     | Type    | Default   | Description                                     |
|------------|---------|-----------|-------------------------------------------------|
| `level`    | string  | `"trace"` | Minimum severity to emit                        |
| `usecolor` | boolean | `true`    | ANSI colors in console output                   |
| `outfile`  | string  | `nil`     | Path to log file (`nil` = no file output)       |
| `name`     | string  | `""`      | Label/prefix printed in every log line          |

### Calling convention

Instance log methods accept the same variadic arguments as the module-level
functions:

```lua
local mylog = log.new({ name = "AUTH" })
mylog:info("user", username, "logged in from", ip)
```

> **Note:** When calling an instance method use `:` syntax (colon) so the
> logger object is passed as `self`. Module-level calls (`log.info(...)`) use
> `.` syntax (dot) as before.


## License
This library is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.
