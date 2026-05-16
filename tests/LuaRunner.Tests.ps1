Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Lua test runner harness" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "LuaRunner.ps1")
    $script:smokePath = Join-Path $PSScriptRoot "lua\smoke.lua"
  }

  It "executes the smoke Lua script without errors" {
    Assert-LuaScriptPasses -ScriptPath $script:smokePath -Context "harness smoke"
  }
}
