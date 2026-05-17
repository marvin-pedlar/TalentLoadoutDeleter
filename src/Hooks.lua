-- TalentLoadoutDeleter / Hooks.lua
-- Blizzard talent UI integration: Manage button + inline [X].

local _, ns = ...
ns = ns or {}

local Hooks = {}
local installed = false

-- Weak-keyed set of functions we've produced as menuGenerator wrappers.
-- Lua functions are NOT tables — `wrapped._tld_wrapped = true` and the
-- corresponding read would both error. Using a side table avoids that.
local isOurWrapper = setmetatable({}, { __mode = "k" })

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

  local function buildWrappedGenerator(origGenerator)
    if isOurWrapper[origGenerator] then return origGenerator end
    local wrapped
    wrapped = function(dropdown, rootDescription)
      origGenerator(dropdown, rootDescription)

      for _, desc in rootDescription:EnumerateElementDescriptions() do
        local configID = desc:GetData()
        -- Add an initializer for EVERY desc, not just loadout rows.
        -- The menu button-widget pool reuses buttons across renders, so a
        -- button that rendered a loadout last time may render a sentinel
        -- this time — and our cached `button._tldX` would still be
        -- visible from the prior render. The initializer below hides the
        -- cached X on non-loadout rows.
        desc:AddInitializer(function(menuButton, description, menu)
          local STARTER_BUILD = Constants and Constants.TraitConsts
            and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID
          local isLoadout = type(configID) == "number"
            and configID ~= STARTER_BUILD

          -- Hide ALL prior X buttons attached to this menu button. Blizzard
          -- pools menu buttons across renders (and across /reload — the
          -- Blizzard_Menu addon stays loaded), so orphans from earlier
          -- code paths or earlier addon versions can persist. Two signals:
          --   1) child._tldOwned (set by our current code on every X we
          --      create — exact, reliable).
          --   2) NormalTexture path contains "UI-StopButton" (catches
          --      unmarked orphans from older addon versions, robust
          --      against in-game path normalization that may differ from
          --      the literal we passed to SetNormalTexture).
          local children = { menuButton:GetChildren() }
          for _, child in ipairs(children) do
            local shouldHide = child._tldOwned == true
            if not shouldHide then
              local getTex = child.GetNormalTexture
              if getTex then
                local tex = getTex(child)
                local path = tex and tex.GetTexture and tex:GetTexture()
                if type(path) == "string" and path:find("UI%-StopButton") then
                  shouldHide = true
                end
              end
            end
            if shouldHide then child:Hide() end
          end
          local x = menuButton._tldX

          if not isLoadout then
            return
          end

          local activeID = C_ClassTalents.GetActiveConfigID()
          local isActive = (configID == activeID)

          if not x then
            x = CreateFrame("Button", nil, menuButton)
            x:SetSize(16, 16)
            x:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
            x._tldOwned = true  -- reliable signal for the orphan scan above
            menuButton._tldX = x
          end
          x:ClearAllPoints()
          x:SetPoint("RIGHT", menuButton, "RIGHT", -22, 0)
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
    isOurWrapper[wrapped] = true
    return wrapped
  end

  -- 1) Hook the instance method for any future UpdateSelectionOptions calls
  --    (e.g. after TRAIT_CONFIG_LIST_UPDATED fires).
  hooksecurefunc(LoadSystem, "UpdateSelectionOptions", function(self)
    local orig = self.Dropdown.menuGenerator
    if not orig or isOurWrapper[orig] then return end
    self.Dropdown:SetupMenu(buildWrappedGenerator(orig))
  end)

  -- 2) Wrap any pre-existing menuGenerator that Blizzard set before our
  --    hook installed (common case: SetSelectionOptions ran during the
  --    talents frame's initial setup before our ADDON_LOADED fired).
  local dropdown = LoadSystem.Dropdown
  if dropdown and dropdown.menuGenerator and not isOurWrapper[dropdown.menuGenerator] then
    dropdown:SetupMenu(buildWrappedGenerator(dropdown.menuGenerator))
  end
end

ns.Hooks = Hooks
