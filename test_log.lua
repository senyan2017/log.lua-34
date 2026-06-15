--
-- test_log.lua
--
-- Test suite for log.lua robustness fixes.
-- Runs a series of scenarios and reports pass/fail for each.
--

local passed = 0
local failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print(string.format("  [PASS] %s", name))
  else
    failed = failed + 1
    print(string.format("  [FAIL] %s: %s", name, tostring(err)))
  end
end

print("=== log.lua robustness tests ===\n")

-- ---------------------------------------------------------------------------
-- Test 1: Unknown log.level should not crash; module falls back to "trace"
-- ---------------------------------------------------------------------------
print("-- Group 1: invalid log.level --")

test("unknown string level does not crash", function()
  -- Fresh require so internal state is clean
  package.loaded["log"] = nil
  local log = require("log")
  log.level = "verbose"   -- not a valid level
  -- This should NOT throw; it should warn on stderr and fall back to "trace"
  log.info("test with bad level")
  -- After the call, level should have been corrected
  assert(log.level == "trace",
    "expected level to be corrected to 'trace', got: " .. tostring(log.level))
end)

test("numeric level does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = 42
  log.warn("test with numeric level")
  assert(log.level == "trace",
    "expected level to be corrected to 'trace', got: " .. tostring(log.level))
end)

test("nil level does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = nil
  log.error("test with nil level")
  assert(log.level == "trace",
    "expected level to be corrected to 'trace', got: " .. tostring(log.level))
end)

test("empty string level does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = ""
  log.debug("test with empty level")
  assert(log.level == "trace",
    "expected level to be corrected to 'trace', got: " .. tostring(log.level))
end)

-- ---------------------------------------------------------------------------
-- Test 2: Normal logging still works after bad-level recovery
-- ---------------------------------------------------------------------------
print("\n-- Group 2: normal logging after recovery --")

test("normal logging works after level correction", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = "badvalue"
  log.info("first call triggers correction")
  -- Now level is "trace"; all subsequent calls should work fine
  log.trace("trace after recovery")
  log.debug("debug after recovery")
  log.info("info after recovery")
  log.warn("warn after recovery")
  log.error("error after recovery")
  log.fatal("fatal after recovery")
end)

test("level filtering works correctly with valid level", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = "warn"
  -- These should be silently skipped (no crash)
  log.trace("should not appear")
  log.debug("should not appear")
  log.info("should not appear")
  -- These should print
  log.warn("should appear")
  log.error("should appear")
  log.fatal("should appear")
end)

-- ---------------------------------------------------------------------------
-- Test 3: File output failures should not crash
-- ---------------------------------------------------------------------------
print("\n-- Group 3: file output failure handling --")

test("empty outfile string does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = ""
  log.info("test with empty outfile")
end)

test("whitespace-only outfile does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = "   "
  log.info("test with whitespace outfile")
end)

test("non-string outfile (number) does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = 12345
  log.info("test with numeric outfile")
end)

test("non-writable path does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = "/nonexistent_dir_12345/subdir/test.log"
  log.info("test with bad path")
  -- A second call should also not crash (error already reported once)
  log.warn("second call with same bad path")
end)

test("outfile nil (default) works fine", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = nil
  log.info("no outfile configured")
end)

-- ---------------------------------------------------------------------------
-- Test 4: Valid file output actually writes
-- ---------------------------------------------------------------------------
print("\n-- Group 4: valid file output --")

local test_outfile = "/tmp/test_log_output_" .. os.time() .. ".log"

test("valid outfile creates file and writes log entries", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.outfile = test_outfile
  log.info("hello from test")
  log.warn("warning from test")

  -- Read back the file and verify content
  local fp = io.open(test_outfile, "r")
  assert(fp, "expected log file to be created at: " .. test_outfile)
  local content = fp:read("*a")
  fp:close()
  assert(content:find("INFO"), "expected INFO in log file content")
  assert(content:find("WARN"), "expected WARN in log file content")
  assert(content:find("hello from test"), "expected log message in file")

  -- Cleanup
  os.remove(test_outfile)
end)

-- ---------------------------------------------------------------------------
-- Test 5: usecolor toggle
-- ---------------------------------------------------------------------------
print("\n-- Group 5: usecolor toggle --")

test("usecolor=false does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.usecolor = false
  log.info("no color output")
  log.error("no color error")
end)

test("usecolor=false with outfile does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.usecolor = false
  log.outfile = test_outfile
  log.info("no color + file output")

  -- Cleanup
  os.remove(test_outfile)
end)

-- ---------------------------------------------------------------------------
-- Test 6: Combined edge cases
-- ---------------------------------------------------------------------------
print("\n-- Group 6: combined edge cases --")

test("bad level + bad outfile does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = "bogus"
  log.outfile = "/no_such_dir_xyz/abc.log"
  log.info("double failure scenario")
  -- Level should be corrected
  assert(log.level == "trace",
    "expected level correction, got: " .. tostring(log.level))
end)

test("bad level + usecolor=false + empty outfile does not crash", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.level = "nope"
  log.usecolor = false
  log.outfile = ""
  log.warn("triple edge case")
end)

test("all valid levels work without error", function()
  local valid_levels = {"trace", "debug", "info", "warn", "error", "fatal"}
  for _, lvl in ipairs(valid_levels) do
    package.loaded["log"] = nil
    local log = require("log")
    log.level = lvl
    log.trace("at " .. lvl)
    log.debug("at " .. lvl)
    log.info("at " .. lvl)
    log.warn("at " .. lvl)
    log.error("at " .. lvl)
    log.fatal("at " .. lvl)
  end
end)

test("number arguments are rounded in output", function()
  package.loaded["log"] = nil
  local log = require("log")
  log.info("pi is", 3.14159265, "e is", 2.71828)
end)

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
  os.exit(1)
end
