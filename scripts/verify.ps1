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
    @{
        Name = "unit"
        Scene = "res://tests/test_runner.tscn"
        Marker = "GARDEN RECLAIMED TESTS: 9 passed"
    },
    @{
        Name = "gameplay-smoke"
        Scene = "res://tests/smoke_game.tscn"
        Marker = "GARDEN RECLAIMED SMOKE: gameplay ran 300 frames"
    },
    @{
        Name = "campaign-smoke"
        Scene = "res://tests/campaign_smoke.tscn"
        Marker = "GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames"
    }
)

foreach ($check in $checks) {
    $logPath = Join-Path $logDirectory ("{0}.log" -f $check.Name)
    $arguments = @(
        "--headless",
        "--path",
        ('"{0}"' -f $projectRoot),
        "--log-file",
        ('"{0}"' -f $logPath),
        $check.Scene
    )

    Write-Host ("Running {0}..." -f $check.Name)
    $process = Start-Process -FilePath $godotCommand.Source -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw ("{0} failed with exit code {1}. See {2}." -f $check.Name, $process.ExitCode, $logPath)
    }

    if (-not (Select-String -LiteralPath $logPath -SimpleMatch $check.Marker -Quiet)) {
        throw ("{0} exited without its pass marker. See {1}." -f $check.Name, $logPath)
    }
}

Write-Host "All Garden Reclaimed checks passed."
