Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-LuaExe {
  $cmd = Get-Command lua -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command lua54 -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  $cmd = Get-Command lua51 -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Invoke-LuaScript {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath
  )
  $exe = Get-LuaExe
  if (-not $exe) {
    return [pscustomobject]@{
      Skipped = $true
      ExitCode = -1
      StdOut = ""
      StdErr = "lua interpreter not found on PATH (tried 'lua', 'lua54', 'lua51')"
    }
  }
  if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "Lua script not found: $ScriptPath"
  }
  $tmpOut = New-TemporaryFile
  $tmpErr = New-TemporaryFile
  try {
    $proc = Start-Process -FilePath $exe `
      -ArgumentList @("`"$ScriptPath`"") `
      -NoNewWindow -Wait -PassThru `
      -RedirectStandardOutput $tmpOut.FullName `
      -RedirectStandardError $tmpErr.FullName
    $stdout = Get-Content -LiteralPath $tmpOut.FullName -Raw
    $stderr = Get-Content -LiteralPath $tmpErr.FullName -Raw
    return [pscustomobject]@{
      Skipped = $false
      ExitCode = $proc.ExitCode
      StdOut = if ($stdout) { $stdout } else { "" }
      StdErr = if ($stderr) { $stderr } else { "" }
    }
  } finally {
    Remove-Item -LiteralPath $tmpOut.FullName -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tmpErr.FullName -ErrorAction SilentlyContinue
  }
}

function Assert-LuaScriptPasses {
  param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$Context
  )
  $result = Invoke-LuaScript -ScriptPath $ScriptPath
  if ($result.Skipped) {
    if ($env:TLD_REQUIRE_BEHAVIOR_TESTS -eq "1") {
      throw "Behavior tests required but lua.exe not on PATH. Install: scoop install lua. Context: $Context"
    }
    Set-ItResult -Skipped -Because $result.StdErr
    return
  }
  if ($result.ExitCode -ne 0) {
    throw @"
Lua script failed (exit $($result.ExitCode)). Context: $Context
--- stdout ---
$($result.StdOut)
--- stderr ---
$($result.StdErr)
"@
  }
}
