-- TalentLoadoutDeleter / Hooks.lua
-- Blizzard talent UI integration: Manage button + inline [X].
--
-- Inline X uses Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE", cb) +
-- MenuTemplates.Attach* helpers exclusively. The compositor cleans every
-- attachment on menu close, so there are no orphans across pool reuse and
-- no taint leaks onto the session-wide menu button pool. Raw key writes
-- (button._foo = x), iteration of pooled children (button:GetChildren()),
-- or CreateFrame with a pooled parent would all taint the pool — see
-- addon-dev-learning.md B1 for the incident this design avoids.

local _, ns = ...
ns = ns or {}

local Hooks = {}
local installed = false

local STOP_TEXTURE = "Interface\\Buttons\\UI-StopButton"
local TIP_DELETE = "Shift-click to delete this loadout."
local TIP_ACTIVE = "Cannot delete the active loadout — switch first."

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

local function isDeletableLoadoutData(data)
  if type(data) ~= "number" then return false end
  local starter = Constants and Constants.TraitConsts
    and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
  if starter ~= nil and data == starter then return false end
  return true
end

local function decorateLoadoutMenu(ownerRegion, rootDescription, contextData)
  if not (rootDescription and rootDescription.EnumerateElementDescriptions) then return end
  for _, desc in rootDescription:EnumerateElementDescriptions() do
    local configID = desc:GetData()
    if isDeletableLoadoutData(configID) then
      desc:AddInitializer(function(menuButton, description, menu)
        local activeID = C_ClassTalents and C_ClassTalents.GetActiveConfigID
          and C_ClassTalents.GetActiveConfigID()
        local isActive = (configID == activeID)

        local x = MenuTemplates.AttachUtilityButton(menuButton, STOP_TEXTURE, 16, 16)

        if isActive then
          -- Lock disabled → MenuTemplates.SetHierarchyEnabled desaturates
          -- the texture automatically (see MenuTemplates_base.lua line ~209).
          MenuTemplates.SetUtilityButtonLockedEnabledState(x, false)
          MenuTemplates.SetUtilityButtonTooltipText(x, TIP_ACTIVE)
        else
          MenuTemplates.SetUtilityButtonTooltipText(x, TIP_DELETE)
          MenuTemplates.SetUtilityButtonClickHandler(x, function()
            if not IsShiftKeyDown() then return end
            C_ClassTalents.DeleteConfig(configID)
            if menu and menu.Close then menu:Close() end
          end)
        end
      end)
    end
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

  -- Inline [X] via the Menu.ModifyMenu compositor-aware path. Blizzard
  -- tags the loadout dropdown's menu at Blizzard_ClassTalentsFrame.lua
  -- line ~475: self.LoadSystem:SetMenuTag("MENU_CLASS_TALENT_PROFILE").
  -- The callback fires immediately if Blizzard already generated the
  -- menu, AND on every future regeneration (TRAIT_CONFIG_LIST_UPDATED,
  -- spec change, new loadout created, etc).
  Menu.ModifyMenu("MENU_CLASS_TALENT_PROFILE", decorateLoadoutMenu)
end

ns.Hooks = Hooks
