-- TalentLoadoutDeleter / Hooks.lua
-- Blizzard talent UI integration: Manage button + inline [X].

local _, ns = ...
ns = ns or {}

local Hooks = {}
local installed = false

local function createManageButton(parent)
  local button = CreateFrame("Button", "TalentLoadoutDeleterManageButton",
    parent, "UIPanelButtonTemplate")
  button:SetText("Manage")
  button:SetSize(80, 22)
  button:SetScript("OnClick", function()
    if ns.Window and ns.Window.Toggle then
      ns.Window.Toggle()
    end
  end)
  return button
end

local function anchorManageButton(button)
  local dropdown = PlayerSpellsFrame
    and PlayerSpellsFrame.TalentsFrame
    and PlayerSpellsFrame.TalentsFrame.LoadoutDropdown
  if dropdown then
    button:ClearAllPoints()
    button:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
    button:Show()
  else
    button:Hide()
  end
end

function Hooks.Install()
  if installed then return end
  if not (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame) then return end

  installed = true

  local button = createManageButton(PlayerSpellsFrame.TalentsFrame)
  ns._manageButton = button

  hooksecurefunc(PlayerSpellsFrame.TalentsFrame, "Show", function()
    anchorManageButton(button)
  end)
  anchorManageButton(button)
end

ns.Hooks = Hooks
