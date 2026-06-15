local log = require "log"

-- 1. Default/global logger: unchanged behaviour, colored, level "trace".
log.info("global logger, colored, trace level")

-- 2. Custom logger "alpha": no colors, level "warn", writes to alpha.log.
local alpha = log.new { name = "alpha", usecolor = false, level = "warn",
                        outfile = "alpha.log" }
alpha.info("filtered out (below warn)")   -- not shown / not written
alpha.error("alpha error -> console + alpha.log")

-- 3. Custom logger "beta": colored, level "trace", writes to beta.log.
local beta = log.new { name = "beta", outfile = "beta.log" }
beta.trace("beta trace -> console + beta.log")

-- Independence checks.
assert(log.usecolor == true,  "global keeps color")
assert(alpha.usecolor == false, "alpha disabled color independently")
assert(beta.usecolor == true,  "beta keeps color independently")
assert(log.name == nil and alpha.name == "alpha" and beta.name == "beta")

-- alpha.log must only contain the error (info was below its level)...
local fa = assert(io.open("alpha.log")); local a = fa:read("*a"); fa:close()
assert(a:find("alpha error") and not a:find("filtered out"), "alpha.log filtered")
-- ...and beta.log must be a separate file with beta's trace line.
local fb = assert(io.open("beta.log")); local b = fb:read("*a"); fb:close()
assert(b:find("beta trace") and not b:find("alpha"), "beta.log is independent")

print("OK: global and custom loggers are independent")
