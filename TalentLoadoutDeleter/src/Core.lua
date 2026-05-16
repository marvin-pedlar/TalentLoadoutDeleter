-- TalentLoadoutDeleter / Core.lua
-- Bootstrap + event dispatch.

local addonName, ns = ...

local TLD = ns or {}
ns = TLD
_G.TalentLoadoutDeleter = TLD  -- top-level handle for debug only; not API

TLD.state = {
  listReady = false,
  isBulkDeleting = false,
}

local dispatcher = CreateFrame("Frame", "TalentLoadoutDeleterDispatcher")
dispatcher:RegisterEvent("ADDON_LOADED")
dispatcher:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
dispatcher:RegisterEvent("TRAIT_CONFIG_DELETED")

dispatcher:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "TalentLoadoutDeleter" then
      -- Self-init hook.
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
  end
end)

TLD.dispatcher = dispatcher
