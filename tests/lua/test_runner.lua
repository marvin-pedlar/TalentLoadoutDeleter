-- Minimal test harness for behavior tests.
-- Each test function runs in a fresh global environment to keep stubs isolated.
-- Tests print "OK <name>" on pass, "FAIL <name>: <reason>" on failure, then
-- the runner exits with code 0 (all pass) or 1 (any failure).

local M = {}

M.tests = {}
M.failures = {}

function M.test(name, fn)
  table.insert(M.tests, { name = name, fn = fn })
end

function M.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s (actual: %s, expected: %s)",
      msg or "assert_eq", tostring(actual), tostring(expected)), 2)
  end
end

function M.assert_true(cond, msg)
  if not cond then
    error(msg or "assert_true failed", 2)
  end
end

function M.assert_false(cond, msg)
  if cond then
    error(msg or "assert_false failed", 2)
  end
end

function M.assert_len(t, expected, msg)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  if n ~= expected then
    error(string.format("%s (length actual: %d, expected: %d)",
      msg or "assert_len", n, expected), 2)
  end
end

function M.run()
  local pass = 0
  for _, t in ipairs(M.tests) do
    local ok, err = pcall(t.fn)
    if ok then
      io.write("OK ", t.name, "\n")
      pass = pass + 1
    else
      io.write("FAIL ", t.name, ": ", tostring(err), "\n")
      table.insert(M.failures, { name = t.name, err = err })
    end
  end
  io.write(string.format("--- %d/%d passed ---\n", pass, #M.tests))
  if #M.failures > 0 then os.exit(1) end
  os.exit(0)
end

return M
