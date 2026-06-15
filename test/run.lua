--
-- test/run.lua
--
-- Regression tests for log.lua focused on the "bad configuration" cases that
-- used to crash the caller: unknown log levels and broken outfile paths.
--
-- Run from the project root with:  lua test/run.lua
--

-- Make `require "log"` work no matter where this is launched from.
local here = (arg and arg[0] or ""):match("^(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. here .. "../?.lua;" .. package.path

local log = require("log")


----------------------------------------------------------------------
-- Tiny test harness
----------------------------------------------------------------------
local real_print = print
local passed, failed = 0, 0

local function check(name, cond, detail)
  if cond then
    passed = passed + 1
    real_print("ok   - " .. name)
  else
    failed = failed + 1
    real_print("FAIL - " .. name .. (detail and ("  (" .. detail .. ")") or ""))
  end
end

-- Capture everything log.lua sends to the console via the global `print`.
local function with_console_capture(fn)
  local lines = {}
  _G.print = function(...)
    local parts = {}
    for i = 1, select("#", ...) do
      parts[i] = tostring(select(i, ...))
    end
    lines[#lines + 1] = table.concat(parts, "\t")
  end
  local ok, err = pcall(fn)
  _G.print = real_print
  return ok, lines, err
end

-- Capture the fallback warnings log.lua sends to io.stderr.
local function with_stderr_capture(fn)
  local real_stderr = io.stderr
  local buf = {}
  io.stderr = { write = function(_, s) buf[#buf + 1] = s end }
  local ok, lines, err = with_console_capture(fn)
  io.stderr = real_stderr
  return ok, lines, table.concat(buf), err
end


----------------------------------------------------------------------
-- Unknown log level: rejected at assignment, module stays usable
----------------------------------------------------------------------
log.usecolor = false
log.outfile = nil
log.level = "trace"

local ok, err = pcall(function() log.level = "verbose" end)
check("unknown level is rejected on assignment", not ok, "no error raised")
check("unknown level error is descriptive",
  type(err) == "string" and err:find("valid levels", 1, true) ~= nil,
  tostring(err))
check("rejected level does not corrupt log.level", log.level == "trace",
  "log.level = " .. tostring(log.level))

local ok2, lines2 = with_console_capture(function() log.info("still alive") end)
check("logging keeps working after a rejected level", ok2 and #lines2 == 1,
  "ok=" .. tostring(ok2) .. " lines=" .. #lines2)

local ok3 = pcall(function() log.level = "debug" end)
check("valid level assignment is accepted", ok3 and log.level == "debug",
  "log.level = " .. tostring(log.level))
log.level = "trace"


----------------------------------------------------------------------
-- Empty outfile path: must not crash, console must still work
----------------------------------------------------------------------
log.outfile = ""
local okE, linesE = with_stderr_capture(function() log.info("empty path") end)
check("empty outfile path does not crash the caller", okE, "pcall failed")
check("console still logs with an empty outfile", #linesE == 1, "lines=" .. #linesE)


----------------------------------------------------------------------
-- Unopenable outfile path: graceful degradation + warn once
----------------------------------------------------------------------
log.outfile = "/no_such_dir_for_log_test_42/nested/app.log"
local okU, linesU, errU = with_stderr_capture(function()
  log.info("one")
  log.info("two")
end)
check("unopenable outfile does not crash the caller", okU, "pcall failed")
check("console still logs when the file cannot be opened", #linesU == 2,
  "lines=" .. #linesU)
check("a clear warning is emitted on open failure",
  errU:find("unable to open outfile", 1, true) ~= nil, errU)
local _, warnCount = errU:gsub("unable to open outfile", "")
check("open failure is reported once per path, not per call", warnCount == 1,
  "warnings=" .. warnCount)
log.outfile = nil


----------------------------------------------------------------------
-- Colour toggle: both branches of the console formatter
----------------------------------------------------------------------
log.usecolor = false
local _, linesNC = with_console_capture(function() log.info("no color") end)
check("usecolor=false emits no ANSI escape codes",
  linesNC[1] ~= nil and linesNC[1]:find("\27", 1, true) == nil, linesNC[1])

log.usecolor = true
local _, linesC = with_console_capture(function() log.info("with color") end)
check("usecolor=true emits ANSI escape codes",
  linesC[1] ~= nil and linesC[1]:find("\27", 1, true) ~= nil, linesC[1])
log.usecolor = false


----------------------------------------------------------------------
-- Level filtering still behaves on the normal path
----------------------------------------------------------------------
log.level = "warn"
local _, linesF = with_console_capture(function()
  log.trace("hidden")
  log.debug("hidden")
  log.info("hidden")
  log.warn("shown")
  log.error("shown")
end)
check("messages below the active level are suppressed", #linesF == 2,
  "lines=" .. #linesF)
log.level = "trace"


----------------------------------------------------------------------
-- Summary
----------------------------------------------------------------------
real_print(string.format("\n%d passed, %d failed", passed, failed))
if os.exit then
  os.exit(failed == 0)
end
