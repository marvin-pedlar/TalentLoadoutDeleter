param(
  [string]$LiveAddonDir = "F:\World of Warcraft\_retail_\Interface\AddOns\TalentLoadoutDeleter"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceDir = $repoRoot
$runTests = Join-Path $repoRoot "scripts\run-tests.ps1"

if (-not (Test-Path -LiteralPath $LiveAddonDir)) {
  Write-Host "Live addon directory does not exist; creating: $LiveAddonDir"
  New-Item -ItemType Directory -Path $LiveAddonDir -Force | Out-Null
}

# Behavior tests must run when deploying. Skipping = blocked.
$env:TLD_REQUIRE_BEHAVIOR_TESTS = "1"
try {
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runTests
  if ($LASTEXITCODE -ne 0) {
    throw "Refusing deploy: tests failed."
  }
} finally {
  Remove-Item Env:\TLD_REQUIRE_BEHAVIOR_TESTS -ErrorAction SilentlyContinue
}

# Copy source files into the live addon folder. Stage explicit paths only.
$filesToCopy = @(
  "TalentLoadoutDeleter.toc",
  "src\Core.lua",
  "src\Data.lua",
  "src\Hooks.lua",
  "src\Window.lua"
)

foreach ($rel in $filesToCopy) {
  $src = Join-Path $sourceDir $rel
  $dst = Join-Path $LiveAddonDir $rel
  $dstDir = Split-Path -Parent $dst
  if (-not (Test-Path -LiteralPath $dstDir)) {
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
  }
  Copy-Item -LiteralPath $src -Destination $dst -Force
}

Write-Host ""
Write-Host "Deployed to $LiveAddonDir"
Get-FileHash -Algorithm SHA256 -LiteralPath ($filesToCopy | ForEach-Object {
  Join-Path $LiveAddonDir $_
}) | Format-List Path, Hash
