Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Hooks.lua structure" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "TestContext.ps1")
    Initialize-TestContext
  }

  It "exposes Install function via ns.Hooks" {
    Assert-Match $script:hooksSource 'function\s+Hooks\.Install' `
      "Expected Hooks.Install function"
    Assert-Match $script:hooksSource 'ns\.Hooks\s*=\s*Hooks' `
      "Expected ns.Hooks assignment"
  }

  It "guards against double-install" {
    Assert-Match $script:hooksSource 'installed' `
      "Expected an 'installed' guard variable"
  }

  It "uses hooksecurefunc only (no method replacement)" {
    Assert-Match $script:hooksSource 'hooksecurefunc' `
      "Expected at least one hooksecurefunc call"
    # Negative: no direct method overwrites on Blizzard frames.
    Assert-NotMatch $script:hooksSource 'PlayerSpellsFrame\.[A-Za-z]+\s*=\s*function' `
      "Did not expect direct method replacement on PlayerSpellsFrame"
  }
}
