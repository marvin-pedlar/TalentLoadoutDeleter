-- TalentLoadoutDeleter / Data.lua
-- Pure functions: enumerate, filter, sort talent loadouts.
-- Returns the module table (also attaches to ns.Data for in-game use).

local _, ns = ...
ns = ns or {}

local Data = {}

function Data.GetLoadouts(specID, activeConfigID)
  local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID) or {}
  local rows = {}
  for _, id in ipairs(configIDs) do
    local info = C_Traits.GetConfigInfo(id)
    if info ~= nil and info.type == Enum.TraitConfigType.Combat then
      table.insert(rows, {
        id = id,
        name = info.name,
        isActive = (id == activeConfigID),
      })
    end
  end

  table.sort(rows, function(a, b)
    if a.isActive ~= b.isActive then
      return a.isActive  -- active goes first
    end
    return string.lower(a.name) < string.lower(b.name)
  end)

  return rows
end

ns.Data = Data
return Data
