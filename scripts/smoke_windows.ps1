[CmdletBinding()]
param(
    [string]$Executable = "build\Garden-Reclaimed.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$executablePath = if ([IO.Path]::IsPathRooted($Executable)) {
    [IO.Path]::GetFullPath($Executable)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Executable))
}
$logDirectory = Join-Path $projectRoot "build\logs"

if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Exported executable not found at $executablePath."
}

New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null

$checks = @(
    @{
        Name = "exported-gameplay-smoke"
        Scene = "res://tests/smoke_game.tscn"
        Marker = "GARDEN RECLAIMED SMOKE: gameplay ran 300 frames"
    },
    @{
        Name = "exported-campaign-smoke"
        Scene = "res://tests/campaign_smoke.tscn"
        Marker = "GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames"
    },
    @{
        Name = "exported-balance-sim"
        Scene = "res://tests/balance_sim.tscn"
        Marker = "GARDEN RECLAIMED BALANCE SIM: 8 commissions x 3 profiles passed"
    }
)

foreach ($check in $checks) {
    $logPath = Join-Path $logDirectory ("{0}.log" -f $check.Name)
    $arguments = @(
        "--headless",
        "--log-file",
        ('"{0}"' -f $logPath),
        "--quit-after",
        "1200",
        $check.Scene
    )

    Write-Host ("Running {0}..." -f $check.Name)
    $process = Start-Process -FilePath $executablePath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
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

Write-Host "Exported Windows build passed all smoke checks."
