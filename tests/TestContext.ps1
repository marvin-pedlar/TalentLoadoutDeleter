Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Convert-VersionToInterface {
  param([Parameter(Mandatory = $true)][string]$Version)
  if ($Version -notmatch '^(\d+)\.(\d+)\.(\d+)') {
    throw "Unable to parse version string '$Version'"
  }
  $major = [int]$Matches[1]; $minor = [int]$Matches[2]; $patch = [int]$Matches[3]
  return ("{0}{1:D2}{2:D2}" -f $major, $minor, $patch)
}

function Get-ClientInterfaceFromBuildInfo {
  param([Parameter(Mandatory = $true)][string]$BuildInfoPath)
  if (-not (Test-Path -LiteralPath $BuildInfoPath)) {
    throw "Build info not found at '$BuildInfoPath'"
  }
  $lines = Get-Content -LiteralPath $BuildInfoPath
  if ($lines.Count -lt 2) { throw "Unexpected .build.info format" }
  $header = $lines[0] -split '\|'
  $activeIndex = -1; $versionIndex = -1
  for ($i = 0; $i -lt $header.Count; $i++) {
    if ($header[$i] -like "Active!*") { $activeIndex = $i }
    if ($header[$i] -like "Version!*") { $versionIndex = $i }
  }
  if ($activeIndex -lt 0 -or $versionIndex -lt 0) {
    throw "Could not locate Active/Version columns in .build.info header"
  }
  $activeRow = $null
  for ($i = 1; $i -lt $lines.Count; $i++) {
    $cols = $lines[$i] -split '\|'
    if ($cols.Count -gt $activeIndex -and $cols[$activeIndex] -eq "1") {
      $activeRow = $cols; break
    }
  }
  if (-not $activeRow) { throw "No active product row found in .build.info" }
  if ($activeRow.Count -le $versionIndex) { throw "Active row missing Version value" }
  return Convert-VersionToInterface -Version $activeRow[$versionIndex]
}

function Get-TocInterfaceValues {
  param([Parameter(Mandatory = $true)][string]$TocPath)
  $line = Get-Content -LiteralPath $TocPath |
    Where-Object { $_ -match '^##\s*Interface\s*:' } |
    Select-Object -First 1
  if (-not $line) { throw "TOC has no ## Interface line" }
  $rawValue = ($line -split ':', 2)[1]
  return @(
    $rawValue -split ',' |
      ForEach-Object { $_.Trim() } |
      Where-Object { $_ -match '^\d+$' }
  )
}

function Initialize-TestContext {
  $initializedVar = Get-Variable -Name testContextInitialized -Scope Script -ErrorAction SilentlyContinue
  if ($initializedVar -and $initializedVar.Value) { return }

  $script:repoRoot = Split-Path -Parent $PSScriptRoot
  $script:addonDir = Join-Path $script:repoRoot "TalentLoadoutDeleter"
  $script:srcDir = Join-Path $script:addonDir "src"
  $script:tocPath = Join-Path $script:addonDir "TalentLoadoutDeleter.toc"

  $script:coreLuaPath = Join-Path $script:srcDir "Core.lua"
  $script:dataLuaPath = Join-Path $script:srcDir "Data.lua"
  $script:hooksLuaPath = Join-Path $script:srcDir "Hooks.lua"
  $script:windowLuaPath = Join-Path $script:srcDir "Window.lua"

  $script:coreSource = Get-Content -LiteralPath $script:coreLuaPath -Raw
  $script:dataSource = Get-Content -LiteralPath $script:dataLuaPath -Raw
  $script:hooksSource = Get-Content -LiteralPath $script:hooksLuaPath -Raw
  $script:windowSource = Get-Content -LiteralPath $script:windowLuaPath -Raw

  $script:tocInterfaces = [string[]](Get-TocInterfaceValues -TocPath $script:tocPath)

  $localBuildInfoPath = "F:\World of Warcraft\.build.info"
  $fixtureBuildInfoPath = Join-Path $PSScriptRoot "fixtures\build.info"

  if ($env:TLD_BUILD_INFO_PATH -and (Test-Path -LiteralPath $env:TLD_BUILD_INFO_PATH)) {
    $script:buildInfoPath = $env:TLD_BUILD_INFO_PATH
  } elseif (Test-Path -LiteralPath $localBuildInfoPath) {
    $script:buildInfoPath = $localBuildInfoPath
  } else {
    $script:buildInfoPath = $fixtureBuildInfoPath
  }

  $script:clientInterface = Get-ClientInterfaceFromBuildInfo -BuildInfoPath $script:buildInfoPath
  $script:testContextInitialized = $true
}
