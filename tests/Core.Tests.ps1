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
}
