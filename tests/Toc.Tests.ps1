Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Per reference_pester5_scope_gotcha: dot-source helpers from BeforeAll only.
# Top-level helpers are invisible to It blocks on Pester 5 during Run phase.

Describe "TOC compatibility" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "TestContext.ps1")
    Initialize-TestContext
  }

  It "has a usable build info source path" {
    Assert-True (Test-Path -LiteralPath $script:buildInfoPath) "Expected build info path to exist"
  }

  It "includes the active client interface number from .build.info" {
    Assert-True (@($script:tocInterfaces) -contains $script:clientInterface) `
      "Expected TOC interfaces to include $($script:clientInterface)"
  }

  It "lists Lua files in load order: Data -> Hooks -> Window -> Core" {
    $tocLines = Get-Content -LiteralPath $script:tocPath
    $luaLines = $tocLines | Where-Object { $_ -match '\.lua\s*$' }
    Assert-Match $luaLines[0] 'Data\.lua' "Expected Data.lua first"
    Assert-Match $luaLines[1] 'Hooks\.lua' "Expected Hooks.lua second"
    Assert-Match $luaLines[2] 'Window\.lua' "Expected Window.lua third"
    Assert-Match $luaLines[3] 'Core\.lua' "Expected Core.lua last"
  }
}
