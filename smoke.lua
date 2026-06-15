--
-- smoke.lua
--
-- Minimal smoke test / contract check for log.lua.
--
-- Exercises every log level, the colour on/off switch, level filtering,
-- number formatting, file output, and the configuration-boundary guards.
-- Run with:  lua smoke.lua
-- Exits non-zero if any assertion fails.
--

-- Load log.lua from this script's own directory regardless of the cwd.
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path
local log = require("log")

local OUTFILE = here .. "/.smoke_log_out.tmp"

-- --------------------------------------------------------------------------
-- Tiny assertion + capture harness
-- --------------------------------------------------------------------------

local pass, fail = 0, 0

local function check(name, cond, detail)
  if cond then
    pass = pass + 1
    io.write(string.format("  ok   - %s\n", name))
  else
    fail = fail + 1
    io.write(string.format("  FAIL - %s%s\n",
      name, detail and ("  [" .. tostring(detail) .. "]") or ""))
  end
end

-- Run `fn` with the global `print` redirected into a buffer, returning the
-- captured lines. Unexpected errors inside `fn` are re-raised.
local real_print = print
local function with_capture(fn)
  local buf = {}
  _G.print = function(...)
    local p = {}
    for i = 1, select("#", ...) do p[#p + 1] = tostring(select(i, ...)) end
    buf[#buf + 1] = table.concat(p, "\t")
  end
  local ok, err = pcall(fn)
  _G.print = real_print
  if not ok then error(err) end
  return buf
end

local function count_containing(buf, needle)
  local n = 0
  for _, line in ipairs(buf) do
    if line:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

local function reset_config()
  log.usecolor = true
  log.outfile = nil
  log.level = "trace"
end

local function read_file(path)
  local fp = io.open(path, "r")
  if not fp then return nil end
  local data = fp:read("*a")
  fp:close()
  return data
end

-- --------------------------------------------------------------------------
-- Visual demo (real output) so a human can eyeball the style
-- --------------------------------------------------------------------------

local names = { "trace", "debug", "info", "warn", "error", "fatal" }

io.write("== DEMO: colour ON ==\n")
reset_config()
for _, n in ipairs(names) do log[n](n .. " message", 1, 2.5) end

io.write("== DEMO: colour OFF ==\n")
log.usecolor = false
for _, n in ipairs(names) do log[n](n .. " message", 1, 2.5) end
reset_config()

-- --------------------------------------------------------------------------
-- Assertions
-- --------------------------------------------------------------------------

io.write("\n== ASSERTIONS ==\n")

-- 1) Default level (trace): all six levels emit, in order, with the right
--    uppercased label and a caller location pointing back at this file.
do
  reset_config()
  log.usecolor = false
  local buf = with_capture(function()
    for _, n in ipairs(names) do log[n]("hi") end
  end)
  check("all six levels emit at default level", #buf == 6, "#buf=" .. #buf)
  local labels = { "[TRACE ", "[DEBUG ", "[INFO  ", "[WARN  ", "[ERROR ", "[FATAL " }
  local all_ok = (#buf == 6)
  for i, lbl in ipairs(labels) do
    if not (buf[i] and buf[i]:find(lbl, 1, true) == 1) then all_ok = false end
  end
  check("each level uses correct padded label", all_ok, buf[1])
  check("caller location points at smoke.lua",
    count_containing(buf, "smoke.lua:") == 6,
    count_containing(buf, "smoke.lua:"))
  reset_config()
end

-- 2) Colour ON: the bracket is wrapped in the level colour + reset code.
do
  reset_config()
  local buf = with_capture(function() log.info("colored") end)
  local line = buf[1] or ""
  check("colour ON prefixes ANSI colour", line:find("\27[32m[INFO  ", 1, true) == 1, line)
  check("colour ON contains ANSI reset", line:find("\27[0m", 1, true) ~= nil, line)
  reset_config()
end

-- 3) Colour OFF: no ANSI escape codes at all.
do
  reset_config()
  log.usecolor = false
  local buf = with_capture(function() log.info("plain") end)
  local line = buf[1] or ""
  check("colour OFF emits no ANSI codes", line:find("\27", 1, true) == nil, line)
  reset_config()
end

-- 4) Level filtering: level="warn" suppresses trace/debug/info.
do
  reset_config()
  log.usecolor = false
  log.level = "warn"
  local buf = with_capture(function()
    for _, n in ipairs(names) do log[n]("x") end
  end)
  check("level filter keeps only warn/error/fatal", #buf == 3, "#buf=" .. #buf)
  check("level filter drops trace/debug/info",
    count_containing(buf, "[TRACE ") == 0
    and count_containing(buf, "[DEBUG ") == 0
    and count_containing(buf, "[INFO  ") == 0)
  reset_config()
end

-- 5) Message building: numbers rounded to 2 dp, args joined with spaces.
do
  reset_config()
  log.usecolor = false
  local buf = with_capture(function() log.info("x", 3.14159, "y") end)
  local line = buf[1] or ""
  check("numbers rounded to 2 decimals and args space-joined",
    line:find("x 3.14 y", 1, true) ~= nil, line)
  reset_config()
end

-- 6) File output: no colour, full date, correct format, appended.
do
  reset_config()
  os.remove(OUTFILE)
  log.usecolor = true            -- colour must NOT leak into the file
  log.outfile = OUTFILE
  log.info("hello file")
  log.warn("second line")
  log.outfile = nil
  local data = read_file(OUTFILE) or ""
  local first = data:match("([^\n]*)\n") or ""
  check("file line has no ANSI codes", first:find("\27", 1, true) == nil, first)
  check("file line matches format and message",
    first:match("^%[INFO%s+.-%]%s.-: hello file$") ~= nil, first)
  local bracket = first:match("^(%b[])") or ""
  check("file uses full date (year present in bracket)",
    bracket:find("%d%d%d%d") ~= nil, bracket)
  local lines = select(2, data:gsub("\n", "\n"))
  check("file appends each message (2 lines)", lines == 2, "lines=" .. tostring(lines))
  os.remove(OUTFILE)
  reset_config()
end

-- 7) Config boundary: an unknown level falls back to logging everything.
do
  reset_config()
  log.usecolor = false
  log.level = "bogus-level"
  local buf = with_capture(function() log.trace("still here") end)
  check("unknown log.level does not crash and logs", #buf == 1, "#buf=" .. #buf)
  reset_config()
end

-- 8) Config boundary: an unopenable outfile is skipped, not fatal.
do
  reset_config()
  log.usecolor = false
  log.outfile = "/this/path/does/not/exist/nope.log"
  local crashed = false
  local buf = with_capture(function()
    local ok = pcall(function() log.info("survives bad outfile") end)
    crashed = not ok
  end)
  check("bad outfile path does not crash logging", not crashed)
  check("console still emits when outfile fails", #buf == 1, "#buf=" .. #buf)
  reset_config()
end

-- --------------------------------------------------------------------------
-- Summary
-- --------------------------------------------------------------------------

io.write(string.format("\n%d passed, %d failed\n", pass, fail))
os.remove(OUTFILE)
if fail > 0 then os.exit(1) end
