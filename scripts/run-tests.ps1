Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$testsDir = Join-Path $repoRoot "tests"

if (-not (Get-Module -ListAvailable Pester)) {
  throw "Pester module not found. Install Pester to run tests."
}

$pesterModule = Get-Module -ListAvailable Pester |
  Sort-Object Version -Descending |
  Select-Object -First 1
Import-Module Pester -RequiredVersion $pesterModule.Version -Force

if ((Get-Module Pester).Version.Major -lt 5) {
  throw "Pester 5+ is required. Found $($pesterModule.Version). Run: Install-Module Pester -Force -SkipPublisherCheck"
}

$config = New-PesterConfiguration
$config.Run.Path = $testsDir
$config.Run.PassThru = $true
$config.Output.Verbosity = "Detailed"

$result = Invoke-Pester -Configuration $config
if (($result.FailedCount -gt 0) -or ($result.Result -ne "Passed")) {
  exit 1
}
