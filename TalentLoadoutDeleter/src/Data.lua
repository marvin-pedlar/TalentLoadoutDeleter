-- TalentLoadoutDeleter / Data.lua
-- Pure functions: enumerate, filter, sort talent loadouts.
-- Returns the module table (also attaches to ns.Data for in-game use).

local _, ns = ...
ns = ns or {}

local Data = {}

function Data.GetLoadouts(specID, activeConfigID)
  local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
  local rows = {}
  -- Filtering and sorting added in later tasks.
  return rows
end

ns.Data = Data
return Data
