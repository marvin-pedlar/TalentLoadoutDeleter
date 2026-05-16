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
}
