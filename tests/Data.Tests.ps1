Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Data.lua behavior" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "LuaRunner.ps1")
    $script:luaTestPath = Join-Path $PSScriptRoot "lua\data_tests.lua"
  }

  It "passes all Data.lua behavior tests" {
    Assert-LuaScriptPasses -ScriptPath $script:luaTestPath -Context "Data.lua behavior suite"
  }
}
