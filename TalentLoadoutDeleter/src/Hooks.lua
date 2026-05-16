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

  -- Inline [X] injection: hook the DropdownLoadSystemMixin directly
  -- (not the instance — instance lookup goes through the mixin via
  -- __index, and hooksecurefunc on an instance with mixin-derived
  -- methods can be flaky). Filter to our specific instance inside.
  -- After our hook installs, trigger one refresh so our wrap takes
  -- effect immediately (Blizzard only re-runs UpdateSelectionOptions
  -- on events like TRAIT_CONFIG_LIST_UPDATED that may have already
  -- passed before our addon loaded).
  local LoadSystem = PlayerSpellsFrame.TalentsFrame.LoadSystem
  hooksecurefunc(DropdownLoadSystemMixin, "UpdateSelectionOptions", function(self)
    if self ~= LoadSystem then return end
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

            -- Cache one X-button per pooled menu button to avoid creating
            -- a fresh frame on every menu open (the compositor does NOT
            -- manage children created via plain CreateFrame — only those
            -- attached via button:AttachTexture / AttachFontString are
            -- pool-aware). Reusing the cached frame bounds the number of
            -- X buttons to the size of Blizzard's menu button pool.
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
    end
    wrapped._tld_wrapped = true
    self.Dropdown:SetupMenu(wrapped)
  end)

  -- Trigger one refresh immediately so the wrap is installed even if
  -- Blizzard's events (TRAIT_CONFIG_LIST_UPDATED etc.) fired before
  -- our addon loaded. Only safe to call if possibleSelections is set,
  -- otherwise UpdateSelectionOptions's generator would crash on an
  -- ipairs of nil when the dropdown opens.
  if LoadSystem.possibleSelections then
    LoadSystem:UpdateSelectionOptions()
  end
end

ns.Hooks = Hooks
