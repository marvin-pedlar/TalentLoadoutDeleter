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

dispatcher:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == "TalentLoadoutDeleter" then
      -- Self-init hook: nothing to do yet. Listeners for talent events
      -- are registered in later tasks once Blizzard_PlayerSpells loads.
    end
  end
end)

TLD.dispatcher = dispatcher
