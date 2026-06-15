--
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = { _version = "0.2.0" }


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


-- Internal write function shared by all logger instances.
-- Called as logger:_write(msg, mode_index, lineinfo)
local function _write(self, msg, mode_index, lineinfo)
  local x = modes[mode_index]
  local nameupper = x.name:upper()
  local prefix = self._name or ""

  -- Output to console
  print(string.format("%s[%-6s%s]%s [%s] %s: %s",
                      self._usecolor and x.color or "",
                      nameupper,
                      os.date("%H:%M:%S"),
                      self._usecolor and "\27[0m" or "",
                      prefix,
                      lineinfo,
                      msg))

  -- Output to log file
  if self._outfile then
    local fp = io.open(self._outfile, "a")
    if fp then
      local str = string.format("[%-6s%s] [%s] %s: %s\n",
                                nameupper, os.date(), prefix, lineinfo, msg)
      fp:write(str)
      fp:close()
    end
  end
end


-- Creates and returns a new independent logger instance.
-- options:
--   level   : minimum log level (default "trace")
--   usecolor: enable ANSI colors in console output (default true)
--   outfile : path to log file, nil disables file output (default nil)
--   name    : a label/prefix shown in every log line (default "")
local function new_logger(options)
  options = options or {}
  local logger = {}

  logger._level    = options.level or "trace"
  if options.usecolor == nil then
    logger._usecolor = true
  else
    logger._usecolor = options.usecolor
  end
  logger._outfile  = options.outfile or nil
  logger._name     = options.name    or ""

  logger._write = _write

  for i, x in ipairs(modes) do
    logger[x.name] = function(_self, ...)
      -- Return early if below the log level
      if i < levels[logger._level] then
        return
      end
      local msg = tostring(...)
      local info = debug.getinfo(2, "Sl")
      local lineinfo = info.short_src .. ":" .. info.currentline
      _write(logger, msg, i, lineinfo)
    end
  end

  return logger
end


-- Create the default logger instance (powers the module-level API).
local default_logger = new_logger({
  level    = "trace",
  usecolor = true,
  outfile  = nil,
  name     = "",
})


-- Expose module-level configuration that feeds into default_logger.
-- Writing to log.level / log.usecolor / log.outfile updates the default
-- logger so that legacy code continues to work transparently.
setmetatable(log, {
  __newindex = function(t, k, v)
    if k == "level" then
      default_logger._level = v
    elseif k == "usecolor" then
      default_logger._usecolor = v
    elseif k == "outfile" then
      default_logger._outfile = v
    else
      rawset(t, k, v)
    end
  end,
  __index = function(t, k)
    if k == "level" then
      return default_logger._level
    elseif k == "usecolor" then
      return default_logger._usecolor
    elseif k == "outfile" then
      return default_logger._outfile
    end
    return nil
  end,
})


-- Attach module-level log functions that delegate to the default logger.
for i, x in ipairs(modes) do
  log[x.name] = function(...)
    -- Return early if below the log level
    if i < levels[default_logger._level] then
      return
    end
    local msg = tostring(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline
    _write(default_logger, msg, i, lineinfo)
  end
end


-- Expose the constructor on the module table.
log.new = new_logger


return log
