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

  It "guards bulk delete with isBulkDeleting set true before DeleteConfig and false after" {
    # Pin the control flow: true must precede the DeleteConfig call, false
    # must follow it. Co-occurrence alone (which the prior regex pair tested)
    # could pass even if the flag was flipped in a dead branch or in the
    # wrong order. Same class of bug as the Phase 2 TRAIT_CONFIG_DELETED
    # regex tightening (commit c177012).
    Assert-Match $script:windowSource 'isBulkDeleting\s*=\s*true[\s\S]{0,400}C_ClassTalents\.DeleteConfig[\s\S]{0,400}isBulkDeleting\s*=\s*false' `
      "Expected isBulkDeleting=true to precede DeleteConfig and =false to follow"
  }

  It "has a Select All checkbox" {
    Assert-Match $script:windowSource 'Select all|Select All' `
      "Expected a 'Select All' label in the header"
  }

  It "shows an empty-state message when no rows" {
    Assert-Match $script:windowSource 'No deletable loadouts' `
      "Expected empty-state string"
  }

  It "installs the OnLoadoutsChanged callback that triggers a Refresh" {
    Assert-Match $script:windowSource 'OnLoadoutsChanged\s*=\s*function' `
      "Expected ns.OnLoadoutsChanged assignment"
    # Pin the call to Window.Refresh, not just the assignment existing.
    Assert-Match $script:windowSource 'OnLoadoutsChanged\s*=\s*function[\s\S]{0,200}Window\.Refresh' `
      "Expected the callback to call Window.Refresh()"
  }

  It "installs the OnSpecChanged callback that hides the window" {
    Assert-Match $script:windowSource 'OnSpecChanged\s*=\s*function' `
      "Expected ns.OnSpecChanged assignment"
    # Pin the actual Hide() call, not the bare string "Hide" which could
    # appear in a comment or local label.
    Assert-Match $script:windowSource 'OnSpecChanged\s*=\s*function[\s\S]{0,200}:Hide\(' `
      "Expected the callback to call :Hide() on the frame"
  }
}
