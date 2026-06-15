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


-- ---------------------------------------------------------------------------
-- Level definitions
--
-- `modes` is the ordered list of log levels (lowest first); `levels` maps a
-- level name back to its numeric rank so `log.level` can be compared cheaply.
-- ---------------------------------------------------------------------------

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


-- ---------------------------------------------------------------------------
-- Internal helpers
--
-- Small, single-purpose utilities for the cross-cutting concerns (number
-- rounding, message building, caller location, colour, timestamps). Keeping
-- them here means a tweak to one concern stays contained to one place.
-- ---------------------------------------------------------------------------

-- Round `x` to the nearest multiple of `increment` (defaults to 1).
local function round(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


-- Build the log message from arbitrary arguments: every value is stringified
-- and joined with a single space, with numbers rounded to two decimals so the
-- output stays tidy.
local function make_message(...)
  local t = {}
  for i = 1, select("#", ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = tostring(x)
  end
  return table.concat(t, " ")
end


-- Return "shortsource:line" for the call site. `levels_up` counts stack frames
-- above the function that calls caller_info (1 = that function's own caller).
local function caller_info(levels_up)
  -- +1 skips caller_info's own frame so callers count from their perspective.
  local info = debug.getinfo(levels_up + 1, "Sl")
  return info.short_src .. ":" .. info.currentline
end


-- Wrap `text` in the level colour when colour output is enabled, otherwise
-- return it untouched. Centralising this keeps the ANSI reset code in one spot.
local function colorize(color, text)
  if not log.usecolor then
    return text
  end
  return color .. text .. "\27[0m"
end


-- Current timestamp. The console uses just the time; the log file uses the
-- full date (matching the documented behaviour of each sink).
local function timestamp(full)
  if full then
    return os.date()
  end
  return os.date("%H:%M:%S")
end


-- ---------------------------------------------------------------------------
-- Output pipeline (writers)
--
-- Each writer owns exactly one sink. They receive the already-formatted pieces
-- (level name, caller location, message) and are responsible only for shaping
-- and emitting their line.
-- ---------------------------------------------------------------------------

-- Write a formatted line to the console, applying colour when enabled.
local function write_console(nameupper, color, lineinfo, msg)
  local label = string.format("[%-6s%s]", nameupper, timestamp(false))
  print(string.format("%s %s: %s", colorize(color, label), lineinfo, msg))
end


-- Append a formatted line to `log.outfile` when one is configured. Log files
-- never contain colour and always use the full date. A file that cannot be
-- opened is skipped rather than crashing the caller.
local function write_outfile(nameupper, lineinfo, msg)
  if not log.outfile then
    return
  end
  local fp = io.open(log.outfile, "a")
  if not fp then
    return
  end
  fp:write(string.format("[%-6s%s] %s: %s\n",
                         nameupper, timestamp(true), lineinfo, msg))
  fp:close()
end


-- Resolve the numeric threshold for the configured `log.level`. An unknown
-- level falls back to the lowest rank (log everything) instead of erroring.
local function level_threshold()
  return levels[log.level] or 1
end


-- ---------------------------------------------------------------------------
-- Level functions (public API)
--
-- Each generated function is a thin orchestrator: gate on the level, build the
-- message and caller location, then hand off to the writers. No formatting or
-- I/O logic lives in the closures themselves.
-- ---------------------------------------------------------------------------

for i, mode in ipairs(modes) do
  local nameupper = mode.name:upper()
  log[mode.name] = function(...)

    -- Return early if we're below the log level
    if i < level_threshold() then
      return
    end

    local msg = make_message(...)
    -- 2 = the function that called this closure (the actual call site).
    local lineinfo = caller_info(2)

    write_console(nameupper, mode.color, lineinfo, msg)
    write_outfile(nameupper, lineinfo, msg)

  end
end


return log
