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

  -- Inline [X] injection: hook the LoadSystem's UpdateSelectionOptions
  -- and wrap its menuGenerator so each loadout radio gets an [X] initializer.
  -- The compositor releases attached children when the menu closes.
  local LoadSystem = PlayerSpellsFrame.TalentsFrame.LoadSystem
  hooksecurefunc(LoadSystem, "UpdateSelectionOptions", function(self)
    local origGenerator = self.Dropdown.menuGenerator
    if not origGenerator or origGenerator._tld_wrapped then return end

    local wrapped = function(dropdown, rootDescription)
      origGenerator(dropdown, rootDescription)

      for _, desc in rootDescription:EnumerateElementDescriptions() do
        local configID = desc:GetData()
        if type(configID) == "number" then
          desc:AddInitializer(function(button, description, menu)
            local activeID = C_ClassTalents.GetActiveConfigID()
            local isActive = (configID == activeID)

            local x = CreateFrame("Button", nil, button)
            x:SetSize(16, 16)
            x:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
            x:SetPoint("RIGHT", button, "RIGHT", -22, 0)

            if isActive then
              local tex = x:GetNormalTexture()
              tex:SetDesaturated(true)
              tex:SetVertexColor(0.5, 0.5, 0.5)
              x:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Cannot delete the active loadout — switch first.")
                GameTooltip:Show()
              end)
              x:SetScript("OnLeave", function() GameTooltip:Hide() end)
            else
              x:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Shift-click to delete this loadout.")
                GameTooltip:Show()
              end)
              x:SetScript("OnLeave", function() GameTooltip:Hide() end)
              x:SetScript("OnClick", function(self)
                if not IsShiftKeyDown() then
                  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                  GameTooltip:SetText("Hold Shift and click to delete.")
                  GameTooltip:Show()
                  return
                end
                C_ClassTalents.DeleteConfig(configID)
                menu:Close()
              end)
            end
          end)
        end
      end
    end
    wrapped._tld_wrapped = true
    self.Dropdown:SetupMenu(wrapped)
  end)
end

ns.Hooks = Hooks
