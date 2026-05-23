Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Describe "Hooks.lua behavioral validation" {
  BeforeAll {
    . (Join-Path $PSScriptRoot "Assertions.ps1")
    . (Join-Path $PSScriptRoot "LuaRunner.ps1")
    $script:validationPath = Join-Path $PSScriptRoot "validation\hooks_inline_x.lua"
  }

  It "passes the inline [X] menu compositor validation (no taint anti-patterns)" {
    Assert-LuaScriptPasses -ScriptPath $script:validationPath `
      -Context "inline [X] taint regression guard (Menu.ModifyMenu + MenuTemplates.Attach*)"
  }
}
