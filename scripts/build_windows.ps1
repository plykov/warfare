[CmdletBinding()]
param(
    [string]$Godot = "godot",
    [string]$Output = "build\Garden-Reclaimed.exe"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotCommand = Get-Command $Godot -ErrorAction Stop
$outputPath = if ([IO.Path]::IsPathRooted($Output)) {
    [IO.Path]::GetFullPath($Output)
} else {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $Output))
}
$outputDirectory = Split-Path -Parent $outputPath
$logPath = Join-Path $outputDirectory "windows-export.log"

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$arguments = @(
    "--headless",
    "--path",
    ('"{0}"' -f $projectRoot),
    "--log-file",
    ('"{0}"' -f $logPath),
    "--export-release",
    '"Windows Desktop"',
    ('"{0}"' -f $outputPath)
)
$process = Start-Process -FilePath $godotCommand.Source -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru

if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
    throw "Windows export failed. Install the Godot 4.4.1 export templates and inspect $logPath."
}

Write-Host ("Windows build created at {0}." -f $outputPath)
