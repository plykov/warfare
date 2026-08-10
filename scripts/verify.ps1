[CmdletBinding()]
param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "godot_tools.ps1")

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot "build\logs"
$godotExecutable = Resolve-GodotExecutable -Godot $Godot

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

$importLogPath = Join-Path $logDirectory "import.log"
$importArguments = @(
    "--headless",
    "--path",
    ('"{0}"' -f $projectRoot),
    "--log-file",
    ('"{0}"' -f $importLogPath),
    "--import"
)

Write-Host "Importing project metadata..."
$importProcess = Start-Process -FilePath $godotExecutable -ArgumentList $importArguments -WindowStyle Hidden -Wait -PassThru
$classCachePath = Join-Path $projectRoot ".godot\global_script_class_cache.cfg"
if ($importProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $classCachePath -PathType Leaf)) {
    if (Test-Path -LiteralPath $importLogPath) {
        Get-Content -Tail 200 -LiteralPath $importLogPath | ForEach-Object { Write-Host $_ }
    }
    throw "Godot project import failed to create the global script class cache."
}

$checks = @(
    @{
        Name = "unit"
        Scene = "res://tests/test_runner.tscn"
        Marker = "GARDEN RECLAIMED TESTS: 42 passed"
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
    },
    @{
        Name = "balance-sim"
        Scene = "res://tests/balance_sim.tscn"
        Marker = "GARDEN RECLAIMED BALANCE SIM: 12 commissions x 3 profiles passed"
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
        "--quit-after",
        "1200",
        $check.Scene
    )

    Write-Host ("Running {0}..." -f $check.Name)
    $process = Start-Process -FilePath $godotExecutable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if (Test-Path -LiteralPath $logPath) {
        Get-Content -LiteralPath $logPath | ForEach-Object { Write-Host $_ }
    }
    if ($process.ExitCode -ne 0) {
        throw ("{0} failed with exit code {1}. See {2}." -f $check.Name, $process.ExitCode, $logPath)
    }

    if (-not (Select-String -LiteralPath $logPath -SimpleMatch $check.Marker -Quiet)) {
        throw ("{0} exited without its pass marker. See {1}." -f $check.Name, $logPath)
    }
}

Write-Host "All Garden Reclaimed checks passed."
