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
  -- Blizzard's SearchBox is anchored LEFT to LoadSystem.RIGHT + 20 (per
  -- Blizzard_ClassTalentsFrame.xml line 236), so we'd overlap it if we
  -- anchored next to LoadSystem itself. Prefer anchoring past the
  -- SearchBox; fall back to LoadSystem with a wide offset if SearchBox
  -- isn't available for some reason.
  local tf = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
  if not tf then
    button:Hide()
    return
  end
  local searchBox = tf.SearchBox
  local loadSystem = tf.LoadSystem
  button:ClearAllPoints()
  if searchBox then
    button:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
    button:Show()
  elseif loadSystem then
    button:SetPoint("LEFT", loadSystem, "RIGHT", 220, 0)
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

  -- Inline [X] injection. Blizzard's Mixin() copies the mixin's methods
  -- onto each frame instance, so hooking the global mixin doesn't
  -- intercept calls on the existing LoadSystem instance. We must hook
  -- the instance directly. Also: SetSelectionOptions may have run
  -- before our addon loaded, so wrap any pre-existing menuGenerator
  -- immediately without triggering UpdateSelectionOptions (which would
  -- error if possibleSelections happens to be nil).
  local LoadSystem = PlayerSpellsFrame.TalentsFrame.LoadSystem
  print("|cff00ff00TLD|r: Hooks.Install — LoadSystem =", LoadSystem and "frame" or "nil",
        "; existing menuGenerator =", LoadSystem.Dropdown and type(LoadSystem.Dropdown.menuGenerator) or "no Dropdown",
        "; possibleSelections =", LoadSystem.possibleSelections and "set" or "nil")

  local function buildWrappedGenerator(origGenerator)
    local wrapped = function(dropdown, rootDescription)
      origGenerator(dropdown, rootDescription)

      local seen = 0
      for _, desc in rootDescription:EnumerateElementDescriptions() do
        local configID = desc:GetData()
        seen = seen + 1
        if type(configID) == "number" then
          print("|cff00ff00TLD|r: adding initializer for configID", configID)
          desc:AddInitializer(function(button, description, menu)
            print("|cff00ff00TLD|r: initializer running for configID", configID, "; button =", button and button:GetName() or "anonymous")
            local activeID = C_ClassTalents.GetActiveConfigID()
            local isActive = (configID == activeID)

            local x = button._tldX
            if not x then
              x = CreateFrame("Button", nil, button)
              x:SetSize(16, 16)
              x:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
              button._tldX = x
            end
            x:ClearAllPoints()
            x:SetPoint("RIGHT", button, "RIGHT", -22, 0)
            local tex = x:GetNormalTexture()

            if isActive then
              tex:SetDesaturated(true)
              tex:SetVertexColor(0.5, 0.5, 0.5)
              x:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Cannot delete the active loadout — switch first.")
                GameTooltip:Show()
              end)
              x:SetScript("OnLeave", function() GameTooltip:Hide() end)
              x:SetScript("OnClick", nil)
            else
              tex:SetDesaturated(false)
              tex:SetVertexColor(1, 1, 1)
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
            x:Show()
          end)
        end
      end
      print("|cff00ff00TLD|r: enumerated", seen, "descs total")
    end
    wrapped._tld_wrapped = true
    return wrapped
  end

  -- 1) Hook the instance method for any future UpdateSelectionOptions calls
  --    (e.g. after TRAIT_CONFIG_LIST_UPDATED fires).
  hooksecurefunc(LoadSystem, "UpdateSelectionOptions", function(self)
    print("|cff00ff00TLD|r: hook fired (UpdateSelectionOptions)")
    local orig = self.Dropdown.menuGenerator
    if not orig or orig._tld_wrapped then return end
    self.Dropdown:SetupMenu(buildWrappedGenerator(orig))
    print("|cff00ff00TLD|r: wrapped generator installed via hook")
  end)

  -- 2) Wrap any pre-existing menuGenerator that Blizzard set before our
  --    hook installed (common case: SetSelectionOptions ran during the
  --    talents frame's initial setup before our ADDON_LOADED fired).
  local dropdown = LoadSystem.Dropdown
  if dropdown and dropdown.menuGenerator and not dropdown.menuGenerator._tld_wrapped then
    dropdown:SetupMenu(buildWrappedGenerator(dropdown.menuGenerator))
    print("|cff00ff00TLD|r: wrapped pre-existing menuGenerator inline")
  else
    print("|cff00ff00TLD|r: no pre-existing menuGenerator to wrap (waiting for hook)")
  end
end

ns.Hooks = Hooks
