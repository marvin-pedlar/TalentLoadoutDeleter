-- TalentLoadoutDeleter / Core.lua
-- Bootstrap + event dispatch.

local _, ns = ...

local TLD = ns or {}
_G.TalentLoadoutDeleter = TLD  -- top-level handle for debug only; not API

TLD.state = {
  listReady = false,
  isBulkDeleting = false,
}

local dispatcher = CreateFrame("Frame", "TalentLoadoutDeleterDispatcher")
dispatcher:RegisterEvent("ADDON_LOADED")
dispatcher:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
dispatcher:RegisterEvent("TRAIT_CONFIG_DELETED")
dispatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

local function tryInstallHooks()
  if TLD.Hooks and TLD.Hooks.Install then
    TLD.Hooks.Install()
  end
end

dispatcher:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "TalentLoadoutDeleter" then
      -- Self-init: check if PlayerSpells is already up (e.g., reloadui
      -- after talent tab was opened earlier in the session).
      if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        tryInstallHooks()
      end
    elseif arg1 == "Blizzard_PlayerSpells" then
      -- Talent UI loaded — dispatch TLD.Hooks.Install via the helper.
      tryInstallHooks()
    end
  elseif event == "TRAIT_CONFIG_LIST_UPDATED" then
    TLD.state.listReady = true
    if TLD.OnLoadoutsChanged then
      TLD.OnLoadoutsChanged()
    end
  elseif event == "TRAIT_CONFIG_DELETED" then
    if not TLD.state.isBulkDeleting and TLD.OnLoadoutsChanged then
      TLD.OnLoadoutsChanged()
    end
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    if TLD.OnSpecChanged then
      TLD.OnSpecChanged()
    end
  end
end)

TLD.dispatcher = dispatcher
