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

  It "references C_ClassTalents.DeleteConfig" {
    Assert-Match $script:hooksSource 'C_ClassTalents\.DeleteConfig' `
      "Expected DeleteConfig call from Hooks.lua"
  }

  It "gates DeleteConfig on IsShiftKeyDown" {
    # Pattern allows up to 400 chars (a tooltip-explainer block fits between
    # the guard and the call). The verbatim hook code from the resolved Spike
    # #1 places a GameTooltip explainer between the `if not IsShiftKeyDown()`
    # check and the `C_ClassTalents.DeleteConfig` call (~240 chars). The plan's
    # original {0,200} window was too tight for that explainer block — this
    # range still asserts locality (no cross-function match) while admitting
    # the documented hook code.
    Assert-Match $script:hooksSource 'IsShiftKeyDown[\s\S]{0,400}C_ClassTalents\.DeleteConfig' `
      "Expected Shift modifier guard before DeleteConfig"
  }

  It "uses Interface\\Buttons\\UI-StopButton texture" {
    Assert-Match $script:hooksSource 'UI-StopButton' `
      "Expected the standard red X texture"
  }
}
