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


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
local level_names = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
  level_names[i] = v.name
end
local level_list = table.concat(level_names, ", ")


-- The active minimum level is kept private so that assigning an invalid value
-- to `log.level` is rejected immediately (see the metatable at the bottom of
-- this file) instead of blowing up with a cryptic comparison error the next
-- time something is logged. The logging functions read this upvalue directly
-- so the common path stays a plain table lookup.
local _level = "trace"


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


-- Outfiles we have already failed to open, so the fallback warning is emitted
-- once per path instead of on every single log call.
local outfile_failed = {}


for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)

    -- Return early if we're below the log level
    if i < levels[_level] then
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
    local outfile = log.outfile
    if outfile then
      local fp, err = io.open(outfile, "a")
      if fp then
        fp:write(string.format("[%-6s%s] %s: %s\n",
                               nameupper, os.date(), lineinfo, msg))
        fp:close()
      elseif not outfile_failed[outfile] then
        -- Degrade gracefully: console logging above already happened, so just
        -- warn once and keep going rather than crashing the caller.
        outfile_failed[outfile] = true
        io.stderr:write(string.format(
          "log.lua: unable to open outfile %q for writing (%s); "
            .. "file logging is disabled for this path\n",
          _tostring(outfile), _tostring(err)))
      end
    end

  end
end


setmetatable(log, {
  __index = function(_, k)
    -- `level` is stored privately; expose it for reads so callers can still
    -- inspect the current value via `log.level`.
    if k == "level" then
      return _level
    end
    return nil
  end,
  __newindex = function(t, k, v)
    if k == "level" then
      -- Reject bad configuration at assignment time with a clear message
      -- instead of deferring an opaque crash to the next log call.
      if levels[v] == nil then
        error(string.format(
          "log.lua: invalid log level %s (valid levels: %s)",
          _tostring(v), level_list), 2)
      end
      _level = v
    else
      rawset(t, k, v)
    end
  end,
})


return log
