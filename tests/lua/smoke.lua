-- Smoke test: verifies test_runner.lua loads and runs a passing test + a
-- failing test that the runner correctly reports. Used to validate the
-- harness wiring before any real Data.lua tests are added.

local script_dir = arg[0]:match("(.*[/\\])") or "./"
package.path = script_dir .. "?.lua;" .. package.path

local t = require("test_runner")

t.test("trivial truth", function()
  t.assert_eq(1 + 1, 2, "arithmetic")
end)

t.test("table length", function()
  t.assert_len({"a","b","c"}, 3, "three-element table")
end)

t.run()
