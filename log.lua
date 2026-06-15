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


-- ==========================================================================
-- Level definitions
-- ==========================================================================

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


-- ==========================================================================
-- Internal helpers
-- ==========================================================================

local function round(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local function tostring(...)
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


local function get_lineinfo()
  local info = debug.getinfo(4, "Sl")
  if not info then
    return "?:0"
  end
  return info.short_src .. ":" .. info.currentline
end


-- ==========================================================================
-- Formatters
-- ==========================================================================

local function format_console(level_name, color, time_str, lineinfo, msg, usecolor)
  return string.format("%s[%-6s%s]%s %s: %s",
    usecolor and color or "",
    level_name,
    time_str,
    usecolor and "\27[0m" or "",
    lineinfo,
    msg)
end


local function format_file(level_name, date_str, lineinfo, msg)
  return string.format("[%-6s%s] %s: %s\n",
    level_name,
    date_str,
    lineinfo,
    msg)
end


-- ==========================================================================
-- Writers
-- ==========================================================================

local function write_console(formatted)
  print(formatted)
end


local function write_file(filepath, formatted)
  local fp, err = io.open(filepath, "a")
  if not fp then
    io.stderr:write("log.lua: could not open '" .. filepath .. "': " .. (err or "unknown") .. "\n")
    return
  end
  fp:write(formatted)
  fp:close()
end


-- ==========================================================================
-- Core log function
-- ==========================================================================

local function log_write(level_idx, ...)
  -- Level check: resolve current threshold
  local threshold = levels[log.level]
  if not threshold then
    threshold = 1  -- default to trace if misconfigured
  end
  if level_idx < threshold then
    return
  end

  local mode = modes[level_idx]
  local msg = tostring(...)
  local lineinfo = get_lineinfo()
  local time_str = os.date("%H:%M:%S")

  -- Console output
  local console_str = format_console(
    mode.name:upper(), mode.color, time_str, lineinfo, msg, log.usecolor)
  write_console(console_str)

  -- File output
  if log.outfile then
    local date_str = os.date()
    local file_str = format_file(mode.name:upper(), date_str, lineinfo, msg)
    write_file(log.outfile, file_str)
  end
end


-- ==========================================================================
-- Public API
-- ==========================================================================

for i, x in ipairs(modes) do
  log[x.name] = function(...)
    log_write(i, ...)
  end
end


return log
