-- test_log.lua
--
-- Verification script for log.lua:
-- 1. Default (global) logger works and respects log.level
-- 2. Independent logger instances with their own level/color/outfile/name
-- 3. Changing one logger's settings does not affect others

local log = require "log"

-- Clean up any leftover test files
os.remove("test_a.log")
os.remove("test_b.log")

print("============================================================")
print(" log.lua verification")
print("============================================================")
print()

---------------------------------------------------------------------------
-- 1. Default logger (module-level API, backward compatible)
---------------------------------------------------------------------------
print("--- [1] Default logger (level=trace, usecolor=true, no outfile) ---")
log.level    = "trace"
log.usecolor = true
log.outfile  = nil

log.trace("default trace message")
log.debug("default debug message")
log.info("default info message")
log.warn("default warn message")
log.error("default error message")
log.fatal("default fatal message")
print()

---------------------------------------------------------------------------
-- 2. Custom logger A — level=debug, outfile=test_a.log, name="SVC-A"
---------------------------------------------------------------------------
print("--- [2] Logger A (level=debug, usecolor=true, outfile=test_a.log, name=SVC-A) ---")
local logger_a = log.new({
  level    = "debug",
  usecolor = true,
  outfile  = "test_a.log",
  name     = "SVC-A",
})

logger_a:trace("this should NOT appear (trace < debug)")
logger_a:debug("debug from A — should appear")
logger_a:info("info from A — should appear")
logger_a:warn("warn from A — should appear")
logger_a:error("error from A — should appear")
print()

---------------------------------------------------------------------------
-- 3. Custom logger B — level=error, outfile=test_b.log, name="SVC-B",
--    usecolor=false
---------------------------------------------------------------------------
print("--- [3] Logger B (level=error, usecolor=false, outfile=test_b.log, name=SVC-B) ---")
local logger_b = log.new({
  level    = "error",
  usecolor = false,
  outfile  = "test_b.log",
  name     = "SVC-B",
})

logger_b:trace("this should NOT appear")
logger_b:debug("this should NOT appear")
logger_b:info("this should NOT appear")
logger_b:warn("this should NOT appear")
logger_b:error("error from B — should appear (no color)")
logger_b:fatal("fatal from B — should appear (no color)")
print()

---------------------------------------------------------------------------
-- 4. Changing default logger settings does NOT affect logger A or B
---------------------------------------------------------------------------
print("--- [4] Raise default level to error; A and B must be unchanged ---")
log.level = "error"

print("Default logger (level=error now):")
log.info("this default info should NOT appear (info < error)")
log.error("this default error SHOULD appear")

print()
print("Logger A (still level=debug):")
logger_a:debug("A debug — should still appear")

print()
print("Logger B (still level=error):")
logger_b:error("B error — should still appear")
print()

---------------------------------------------------------------------------
-- 5. Changing logger A settings does NOT affect default or B
---------------------------------------------------------------------------
print("--- [5] Raise logger A level to fatal; default and B unchanged ---")
logger_a._level = "fatal"

logger_a:warn("A warn — should NOT appear (warn < fatal)")
logger_a:fatal("A fatal — should appear")

print()
print("Default logger (still level=error):")
log.error("default error — should still appear")

print()
print("Logger B (still level=error):")
logger_b:error("B error — should still appear")
print()

---------------------------------------------------------------------------
-- 6. Verify log files
---------------------------------------------------------------------------
print("--- [6] Verify output files ---")

local function file_contents(path)
  local fp = io.open(path, "r")
  if not fp then return nil end
  local data = fp:read("*a")
  fp:close()
  return data
end

local a_data = file_contents("test_a.log")
local b_data = file_contents("test_b.log")

local pass_count = 0
local fail_count = 0

local function check(desc, ok)
  if ok then
    pass_count = pass_count + 1
    print("  PASS  " .. desc)
  else
    fail_count = fail_count + 1
    print("  FAIL  " .. desc)
  end
end

-- Logger A file checks
check("test_a.log exists",                a_data ~= nil)
if a_data then
  check("test_a.log contains [SVC-A]",    a_data:find("%[SVC%-A%]") ~= nil)
  check("test_a.log has DEBUG line",      a_data:find("DEBUG") ~= nil)
  check("test_a.log has INFO line",       a_data:find("INFO")  ~= nil)
  check("test_a.log has no TRACE line",   a_data:find("TRACE") == nil)
end

-- Logger B file checks
check("test_b.log exists",                b_data ~= nil)
if b_data then
  check("test_b.log contains [SVC-B]",    b_data:find("%[SVC%-B%]") ~= nil)
  check("test_b.log has ERROR line",      b_data:find("ERROR") ~= nil)
  check("test_b.log has FATAL line",      b_data:find("FATAL") ~= nil)
  check("test_b.log has no INFO line",    b_data:find("INFO")  == nil)
  check("test_b.log has no WARN line",    b_data:find("WARN")  == nil)
end

print()
print("============================================================")
print(string.format(" Results: %d passed, %d failed", pass_count, fail_count))
print("============================================================")

-- Clean up
os.remove("test_a.log")
os.remove("test_b.log")

if fail_count > 0 then
  os.exit(1)
end
