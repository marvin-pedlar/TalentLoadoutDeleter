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

t.test("single combat loadout is returned", function()
  stub_blizzard(
    {101},
    { [101] = { ID = 101, name = "Raid", type = 1, treeIDs = {} } },
    nil
  )
  local Data = load_data()
  local rows = Data.GetLoadouts(62, nil)
  t.assert_len(rows, 1, "expected one row")
  t.assert_eq(rows[1].id, 101, "id")
  t.assert_eq(rows[1].name, "Raid", "name")
  t.assert_eq(rows[1].isActive, false, "isActive when activeConfigID nil")
end)

t.test("profession loadout is filtered out", function()
  stub_blizzard(
    {201, 202},
    {
      [201] = { ID = 201, name = "Raid",   type = 1, treeIDs = {} },
      [202] = { ID = 202, name = "Mining", type = 2, treeIDs = {} },
    },
    nil
  )
  local Data = load_data()
  local rows = Data.GetLoadouts(62, nil)
  t.assert_len(rows, 1, "only the combat row should survive")
  t.assert_eq(rows[1].name, "Raid", "name of surviving row")
end)

t.test("generic loadout (type 3) is filtered out", function()
  stub_blizzard(
    {301, 302},
    {
      [301] = { ID = 301, name = "Raid",         type = 1, treeIDs = {} },
      [302] = { ID = 302, name = "Dragonflight", type = 3, treeIDs = {} },
    },
    nil
  )
  local Data = load_data()
  local rows = Data.GetLoadouts(62, nil)
  t.assert_len(rows, 1, "only the combat row should survive")
  t.assert_eq(rows[1].id, 301, "id of surviving row")
end)

t.test("nil GetConfigInfo result is skipped", function()
  stub_blizzard(
    {401, 402},
    {
      [401] = { ID = 401, name = "Raid", type = 1, treeIDs = {} },
      -- [402] intentionally absent -> GetConfigInfo returns nil
    },
    nil
  )
  local Data = load_data()
  local rows = Data.GetLoadouts(62, nil)
  t.assert_len(rows, 1, "nil entry must not break the surrounding rows")
  t.assert_eq(rows[1].name, "Raid", "valid row preserved")
end)

t.run()
