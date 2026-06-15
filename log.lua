--
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = nil
log.level = "trace"
log.name = nil


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = _tostring(x)
  end
  return table.concat(t, " ")
end


-- Install the trace/debug/info/warn/error/fatal methods onto `logger`. Each
-- method is a plain closure bound to `logger` (call it with dot syntax, e.g.
-- `logger.info(...)`), so every logger reads its own `level`, `usecolor`,
-- `outfile` and `name` fields at call time and stays independent of the others.
local function set_modes(logger)
  for i, x in ipairs(modes) do
    local nameupper = x.name:upper()
    logger[x.name] = function(...)

      -- Return early if we're below the log level
      if i < levels[logger.level] then
        return
      end

      -- Optional per-logger name, printed just before the source location so
      -- that interleaved logs from different loggers stay distinguishable.
      local nameprefix = logger.name and (logger.name .. " ") or ""

      local msg = tostring(...)
      local info = debug.getinfo(2, "Sl")
      local lineinfo = info.short_src .. ":" .. info.currentline

      -- Output to console
      print(string.format("%s[%-6s%s]%s %s%s: %s",
                          logger.usecolor and x.color or "",
                          nameupper,
                          os.date("%H:%M:%S"),
                          logger.usecolor and "\27[0m" or "",
                          nameprefix,
                          lineinfo,
                          msg))

      -- Output to log file
      if logger.outfile then
        local fp = io.open(logger.outfile, "a")
        local str = string.format("[%-6s%s] %s%s: %s\n",
                                  nameupper, os.date(), nameprefix, lineinfo, msg)
        fp:write(str)
        fp:close()
      end

    end
  end
end


-- Create a new, independent logger with its own settings. `options` is an
-- optional table; any field left out falls back to a sensible default:
--   options.name     -> nil   (no name/prefix)
--   options.level    -> "trace"
--   options.usecolor -> true
--   options.outfile  -> nil   (console only)
-- The returned logger exposes the same trace/debug/info/warn/error/fatal
-- functions as the module and never shares mutable state with other loggers.
function log.new(options)
  options = options or {}
  local logger = {
    name     = options.name,
    level    = options.level or "trace",
    usecolor = options.usecolor == nil and true or options.usecolor,
    outfile  = options.outfile,
  }
  set_modes(logger)
  return logger
end


-- The module table itself is the default (global) logger, so existing code
-- that calls log.trace(...), log.info(...) and friends keeps working unchanged.
set_modes(log)


return log
