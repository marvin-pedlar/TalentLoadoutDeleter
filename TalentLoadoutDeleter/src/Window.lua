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

function Window.Toggle()
  if not frame then
    frame = createFrame()
  end
  if frame:IsShown() then
    frame:Hide()
  else
    frame:Show()
  end
end

ns.Window = Window
