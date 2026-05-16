-- TalentLoadoutDeleter / Window.lua
-- Bulk-manager window.

local _, ns = ...
ns = ns or {}

local Window = {}
local frame

local function createFrame()
  local f = CreateFrame("Frame", "TalentLoadoutDeleterWindow",
    UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(380, 480)
  f:SetPoint("TOPRIGHT", PlayerSpellsFrame or UIParent, "TOPLEFT", -4, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  f.TitleText = f.TitleText or _G[f:GetName() .. "TitleText"]
  if f.TitleText then
    f.TitleText:SetText("Talent Loadouts")
  end

  f:Hide()
  return f
end

local function currentSpecName()
  local specIndex = GetSpecialization()
  if not specIndex then return "" end
  local _, name = GetSpecializationInfo(specIndex)
  return name or ""
end

function Window.Refresh()
  if not frame then return end
  if frame.TitleText then
    local specName = currentSpecName()
    if specName ~= "" then
      frame.TitleText:SetText("Talent Loadouts — " .. specName)
    else
      frame.TitleText:SetText("Talent Loadouts")
    end
  end
  -- Row + footer refresh added in later tasks.
end

function Window.Toggle()
  if not frame then
    frame = createFrame()
  end
  if frame:IsShown() then
    frame:Hide()
  else
    Window.Refresh()
    frame:Show()
  end
end

ns.Window = Window
