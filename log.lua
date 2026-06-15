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


-- Internal: validate the current log.level; fall back to "trace" if invalid.
-- Emits a one-time direct stderr warning so misconfiguration is visible
-- without relying on the logging path itself (which would recurse).
local _level_warned = false

local function get_level()
  local lvl = levels[log.level]
  if lvl then
    return lvl
  end
  if not _level_warned then
    _level_warned = true
    io.stderr:write(string.format(
      "[log.lua] WARNING: unknown log.level '%s' (type=%s); falling back to 'trace'\n",
      _tostring(log.level), type(log.level)))
    log.level = "trace"
  end
  return 1
end


-- Internal: append a formatted line to log.outfile.
-- All I/O is wrapped in pcall so a bad path, missing directory, permission
-- error, or full disk never propagates an exception to the caller.
local _file_error_reported = {}

local function write_to_file(nameupper, lineinfo, msg)
  if not log.outfile then
    return
  end
  -- Treat empty / whitespace-only paths as misconfiguration
  if type(log.outfile) ~= "string" or log.outfile:match("^%s*$") then
    if not _file_error_reported["__empty__"] then
      _file_error_reported["__empty__"] = true
      io.stderr:write("[log.lua] WARNING: log.outfile is empty or not a string; file output disabled\n")
    end
    return
  end

  local fp, open_err = io.open(log.outfile, "a")
  if not fp then
    if not _file_error_reported[log.outfile] then
      _file_error_reported[log.outfile] = true
      io.stderr:write(string.format(
        "[log.lua] WARNING: cannot open log.outfile '%s': %s; file output disabled for this path\n",
        log.outfile, _tostring(open_err)))
    end
    return
  end

  local str = string.format("[%-6s%s] %s: %s\n",
                            nameupper, os.date(), lineinfo, msg)
  local ok, write_err = pcall(function()
    fp:write(str)
    fp:close()
  end)
  if not ok and not _file_error_reported[log.outfile .. ":write"] then
    _file_error_reported[log.outfile .. ":write"] = true
    io.stderr:write(string.format(
      "[log.lua] WARNING: error writing to log.outfile '%s': %s\n",
      log.outfile, _tostring(write_err)))
  end
end


for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)

    -- Return early if we're below the log level
    if i < get_level() then
      return
    end

    local msg = tostring(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    -- Output to console
    print(string.format("%s[%-6s%s]%s %s: %s",
                        log.usecolor and x.color or "",
                        nameupper,
                        os.date("%H:%M:%S"),
                        log.usecolor and "\27[0m" or "",
                        lineinfo,
                        msg))

    -- Output to log file
    write_to_file(nameupper, lineinfo, msg)

  end
end


return log
