local script_dir = arg[0]:match("(.*[/\\])") or "./"
package.path = script_dir .. "?.lua;" .. package.path

local t = require("test_runner")

-- Path to the source file under test (relative to the script's launch dir).
local DATA_LUA = script_dir .. "../../TalentLoadoutDeleter/src/Data.lua"

-- Common stubs reset per test by stub_blizzard().
local function stub_blizzard(configIDs, infoByID, activeID)
  _G.C_ClassTalents = {
    GetConfigIDsBySpecID = function(_) return configIDs or {} end,
    GetActiveConfigID = function() return activeID end,
  }
  _G.C_Traits = {
    GetConfigInfo = function(id) return infoByID and infoByID[id] or nil end,
  }
  _G.Enum = {
    TraitConfigType = { Invalid = 0, Combat = 1, Profession = 2, Generic = 3 },
  }
end

local function load_data()
  return assert(loadfile(DATA_LUA))("TalentLoadoutDeleter", {})
end

t.test("empty configIDs returns empty list", function()
  stub_blizzard({}, {}, nil)
  local Data = load_data()
  local rows = Data.GetLoadouts(62, nil)
  t.assert_len(rows, 0, "expected zero rows")
end)

t.run()
