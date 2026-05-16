Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Window.lua structure" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "TestContext.ps1")
    Initialize-TestContext
  }

  It "exposes Window.Toggle via ns.Window" {
    Assert-Match $script:windowSource 'function\s+Window\.Toggle' `
      "Expected Window.Toggle function"
    Assert-Match $script:windowSource 'ns\.Window\s*=\s*Window' `
      "Expected ns.Window assignment"
  }

  It "uses BasicFrameTemplateWithInset template" {
    Assert-Match $script:windowSource 'BasicFrameTemplateWithInset' `
      "Expected BasicFrameTemplateWithInset frame template"
  }

  It "creates the frame lazily" {
    Assert-Match $script:windowSource 'local\s+frame\s*$|local\s+frame\s*=\s*nil|if\s+not\s+frame' `
      "Expected lazy frame creation"
  }

  It "exposes Window.Refresh" {
    Assert-Match $script:windowSource 'function\s+Window\.Refresh' `
      "Expected Window.Refresh function"
  }

  It "uses GetSpecializationInfo for title" {
    Assert-Match $script:windowSource 'GetSpecializationInfo' `
      "Expected GetSpecializationInfo for title text"
  }

  It "renders loadout rows via Data.GetLoadouts" {
    Assert-Match $script:windowSource 'ns\.Data\.GetLoadouts' `
      "Expected the window to consume the Data module"
  }

  It "uses a scroll surface (ScrollFrame or ScrollBox)" {
    Assert-Match $script:windowSource 'CreateFrame\(\s*"ScrollFrame"|WowScrollBoxList' `
      "Expected ScrollFrame or WowScrollBoxList"
  }

  It "has a Delete Selected button" {
    Assert-Match $script:windowSource 'SetText\(\s*"Delete Selected' `
      "Expected button labeled 'Delete Selected'"
  }

  It "calls C_ClassTalents.DeleteConfig from the delete handler" {
    Assert-Match $script:windowSource 'C_ClassTalents\.DeleteConfig' `
      "Expected DeleteConfig invocation"
  }

  It "guards bulk delete with isBulkDeleting flag" {
    Assert-Match $script:windowSource 'isBulkDeleting\s*=\s*true' `
      "Expected isBulkDeleting flag set to true"
    Assert-Match $script:windowSource 'isBulkDeleting\s*=\s*false' `
      "Expected isBulkDeleting flag reset to false"
  }

  It "has a Select All checkbox" {
    Assert-Match $script:windowSource 'Select all|Select All' `
      "Expected a 'Select All' label in the header"
  }
}
