Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) { throw $Message }
}

function Assert-False {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Condition) { throw $Message }
}

function Assert-GreaterThan {
  param(
    [Parameter(Mandatory = $true)][double]$Actual,
    [Parameter(Mandatory = $true)][double]$Threshold,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not ($Actual -gt $Threshold)) {
    throw "$Message (actual: $Actual, threshold: $Threshold)"
  }
}

function Assert-Match {
  param(
    [Parameter(Mandatory = $true)][string]$Actual,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Actual -notmatch $Pattern) {
    throw "$Message (pattern: $Pattern)"
  }
}

function Assert-NotMatch {
  param(
    [Parameter(Mandatory = $true)][string]$Actual,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Actual -match $Pattern) {
    throw "$Message (pattern unexpectedly matched: $Pattern)"
  }
}

function Assert-Equal {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Actual -ne $Expected) {
    throw "$Message (actual: $Actual, expected: $Expected)"
  }
}
