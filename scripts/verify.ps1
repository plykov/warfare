[CmdletBinding()]
param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot "build\logs"
$godotCommand = Get-Command $Godot -ErrorAction Stop

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

$checks = @(
    @{ Name = "unit"; Scene = "res://tests/test_runner.tscn" },
    @{ Name = "gameplay-smoke"; Scene = "res://tests/smoke_game.tscn" },
    @{ Name = "campaign-smoke"; Scene = "res://tests/campaign_smoke.tscn" }
)

foreach ($check in $checks) {
    $logPath = Join-Path $logDirectory ("{0}.log" -f $check.Name)
    Write-Host ("Running {0}..." -f $check.Name)
    & $godotCommand.Source --headless --path $projectRoot --log-file $logPath $check.Scene
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} failed with exit code {1}. See {2}." -f $check.Name, $LASTEXITCODE, $logPath)
    }
}

Write-Host "All Garden Reclaimed checks passed."
