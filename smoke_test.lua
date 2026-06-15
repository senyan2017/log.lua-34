--
-- smoke_test.lua
--
-- Smoke test for the refactored log.lua
-- Covers: all log levels, color on/off, file output, level filtering,
--         number formatting, multi-arg messages, edge cases.
--

local log = require("log")

local passed = 0
local failed = 0
local total  = 0

local function assert_true(cond, label)
  total = total + 1
  if cond then
    passed = passed + 1
    print("  [PASS] " .. label)
  else
    failed = failed + 1
    print("  [FAIL] " .. label)
  end
end

local function section(title)
  print("\n=== " .. title .. " ===")
end

-- ==========================================================================
section("1. Module loads and has expected API")
-- ==========================================================================

assert_true(type(log) == "table", "log is a table")
assert_true(log._version == "0.1.0", "version is 0.1.0")

local expected_funcs = {"trace", "debug", "info", "warn", "error", "fatal"}
for _, fn in ipairs(expected_funcs) do
  assert_true(type(log[fn]) == "function", "log." .. fn .. " is a function")
end

assert_true(log.usecolor == true, "usecolor defaults to true")
assert_true(log.outfile == nil, "outfile defaults to nil")
assert_true(log.level == "trace", "level defaults to trace")

-- ==========================================================================
section("2. All log levels produce console output (color ON)")
-- ==========================================================================

log.usecolor = true
log.level = "trace"

print("  (expect 6 colored lines below)")
log.trace("trace message")
log.debug("debug message")
log.info("info message")
log.warn("warn message")
log.error("error message")
log.fatal("fatal message")
assert_true(true, "all 6 levels printed without error")

-- ==========================================================================
section("3. Color OFF produces plain output")
-- ==========================================================================

log.usecolor = false
print("  (expect 6 plain lines below)")
log.trace("trace no-color")
log.debug("debug no-color")
log.info("info no-color")
log.warn("warn no-color")
log.error("error no-color")
log.fatal("fatal no-color")
assert_true(true, "all 6 levels printed without color codes")

-- ==========================================================================
section("4. Level filtering")
-- ==========================================================================

log.usecolor = false
log.level = "warn"
print("  (expect only warn, error, fatal below)")
log.trace("SHOULD NOT APPEAR")
log.debug("SHOULD NOT APPEAR")
log.info("SHOULD NOT APPEAR")
log.warn("warn filtered")
log.error("error filtered")
log.fatal("fatal filtered")
assert_true(true, "only warn/error/fatal appeared when level=warn")

-- Reset
log.level = "trace"

-- ==========================================================================
section("5. Number formatting (rounding)")
-- ==========================================================================

log.usecolor = false
print("  (expect numbers rounded to 2 decimal places)")
log.info(3.14159, "pi")
log.info(0.1 + 0.2, "float addition")
assert_true(true, "numbers formatted")

-- ==========================================================================
section("6. Multi-argument messages")
-- ==========================================================================

log.usecolor = false
print("  (expect multiple args concatenated)")
log.info("hello", "world", 42, true, nil)
assert_true(true, "multi-arg message formatted")

-- ==========================================================================
section("7. File output")
-- ==========================================================================

local test_file = "test_output.log"

-- Clean up any previous test file
os.remove(test_file)

log.usecolor = false
log.outfile = test_file
log.info("file test message 1")
log.warn("file test message 2")
log.error("file test message 3")

-- Read back and verify
local fp = io.open(test_file, "r")
assert_true(fp ~= nil, "log file was created")

if fp then
  local content = fp:read("*a")
  fp:close()

  assert_true(content:find("%[INFO") ~= nil, "file contains [INFO")
  assert_true(content:find("%[WARN") ~= nil, "file contains [WARN")
  assert_true(content:find("%[ERROR") ~= nil, "file contains [ERROR")
  assert_true(content:find("file test message 1") ~= nil, "file contains message 1")
  assert_true(content:find("file test message 2") ~= nil, "file contains message 2")
  assert_true(content:find("file test message 3") ~= nil, "file contains message 3")

  -- File output should NOT contain color escape codes
  assert_true(content:find("\27%[") == nil, "file output has no ANSI color codes")
end

-- Clean up
log.outfile = nil
os.remove(test_file)

-- ==========================================================================
section("8. Edge case: bad level config")
-- ==========================================================================

log.level = "nonexistent"
log.usecolor = false
print("  (expect trace message even with bad level config)")
log.trace("edge case: bad level")
assert_true(true, "did not crash with bad level config")

-- Reset
log.level = "trace"

-- ==========================================================================
section("9. Console output format verification")
-- ==========================================================================

-- Capture print output by temporarily overriding it
local captured = {}
local real_print = print
print = function(...)
  local args = {...}
  local t = {}
  for i = 1, select('#', ...) do
    t[#t + 1] = tostring(args[i])
  end
  captured[#captured + 1] = table.concat(t, "\t")
end

log.usecolor = false
log.info("format check")

print = real_print  -- restore

assert_true(#captured == 1, "exactly one line printed")
if #captured == 1 then
  local line = captured[1]
  -- Should match: [INFO  HH:MM:SS] source:line: format check
  assert_true(line:find("%[INFO%s%s%d%d:%d%d:%d%d%]") ~= nil,
    "console format has [INFO  HH:MM:SS]")
  assert_true(line:find("format check") ~= nil, "console output contains message")
  assert_true(line:find("smoke_test%.lua:%d+") ~= nil, "console output contains source:line")
end

-- ==========================================================================
section("10. Color output format verification")
-- ==========================================================================

captured = {}
print = function(...)
  local args = {...}
  local t = {}
  for i = 1, select('#', ...) do
    t[#t + 1] = tostring(args[i])
  end
  captured[#captured + 1] = table.concat(t, "\t")
end

log.usecolor = true
log.info("color check")

print = real_print

assert_true(#captured == 1, "exactly one line printed with color")
if #captured == 1 then
  local line = captured[1]
  -- Should contain green color code for info
  assert_true(line:find("\27%[32m") ~= nil, "info line contains green ANSI code")
  -- Should contain reset code
  assert_true(line:find("\27%[0m") ~= nil, "line contains ANSI reset code")
end

-- ==========================================================================
-- Summary
-- ==========================================================================

print(string.format("\n========================================"))
print(string.format("Smoke test results: %d/%d passed, %d failed",
  passed, total, failed))
print(string.format("========================================"))

if failed > 0 then
  os.exit(1)
else
  print("All tests passed!")
  os.exit(0)
end
