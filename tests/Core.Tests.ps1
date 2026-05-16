Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Core.lua structure" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "TestContext.ps1")
    Initialize-TestContext
  }

  It "creates an event dispatch frame" {
    Assert-Match $script:coreSource 'CreateFrame\s*\(\s*"Frame"' `
      "Expected Core.lua to call CreateFrame(`"Frame`", ...)"
  }

  It "registers ADDON_LOADED" {
    Assert-Match $script:coreSource 'RegisterEvent\s*\(\s*"ADDON_LOADED"' `
      "Expected ADDON_LOADED registration"
  }

  It "branches on the addon's own name in ADDON_LOADED" {
    Assert-Match $script:coreSource 'TalentLoadoutDeleter' `
      "Expected Core.lua to gate self-init on addon name"
  }

  It "registers TRAIT_CONFIG_LIST_UPDATED" {
    Assert-Match $script:coreSource 'RegisterEvent\s*\(\s*"TRAIT_CONFIG_LIST_UPDATED"' `
      "Expected TRAIT_CONFIG_LIST_UPDATED registration"
  }

  It "sets state.listReady when TRAIT_CONFIG_LIST_UPDATED fires" {
    Assert-Match $script:coreSource 'TRAIT_CONFIG_LIST_UPDATED[\s\S]*listReady\s*=\s*true' `
      "Expected listReady to be set true on TRAIT_CONFIG_LIST_UPDATED"
  }

  It "registers TRAIT_CONFIG_DELETED" {
    Assert-Match $script:coreSource 'RegisterEvent\s*\(\s*"TRAIT_CONFIG_DELETED"' `
      "Expected TRAIT_CONFIG_DELETED registration"
  }

  It "suppresses refresh during bulk delete" {
    Assert-Match $script:coreSource 'TRAIT_CONFIG_DELETED[\s\S]*isBulkDeleting' `
      "Expected TRAIT_CONFIG_DELETED to consult isBulkDeleting"
  }

  It "registers PLAYER_SPECIALIZATION_CHANGED" {
    Assert-Match $script:coreSource 'RegisterEvent\s*\(\s*"PLAYER_SPECIALIZATION_CHANGED"' `
      "Expected PLAYER_SPECIALIZATION_CHANGED registration"
  }

  It "delegates spec change to TLD.OnSpecChanged" {
    Assert-Match $script:coreSource 'PLAYER_SPECIALIZATION_CHANGED[\s\S]*OnSpecChanged' `
      "Expected OnSpecChanged delegate"
  }

  It "branches on Blizzard_PlayerSpells in ADDON_LOADED" {
    Assert-Match $script:coreSource 'Blizzard_PlayerSpells' `
      "Expected Core.lua to detect Blizzard_PlayerSpells load"
  }

  It "delegates Blizzard_PlayerSpells install to TLD.Hooks.Install" {
    Assert-Match $script:coreSource 'Blizzard_PlayerSpells[\s\S]*Hooks\.Install' `
      "Expected Hooks.Install dispatch on Blizzard_PlayerSpells load"
  }

  It "fires Install immediately when Blizzard_PlayerSpells is already loaded" {
    Assert-Match $script:coreSource 'C_AddOns\.IsAddOnLoaded\(\s*"Blizzard_PlayerSpells"\s*\)' `
      "Expected pre-check via C_AddOns.IsAddOnLoaded for already-loaded case"
  }
}
