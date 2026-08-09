[CmdletBinding()]
param(
    [string]$Godot = "godot",
    [string]$Output = "build\Garden-Reclaimed.exe"
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "godot_tools.ps1")

$projectRoot = Split-Path -Parent $PSScriptRoot
$godotExecutable = Resolve-GodotExecutable -Godot $Godot
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
$process = Start-Process -FilePath $godotExecutable -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru

if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $outputPath)) {
    if (Test-Path -LiteralPath $logPath) {
        Get-Content -Tail 200 -LiteralPath $logPath | ForEach-Object { Write-Host $_ }
    }
    throw "Windows export failed. Install the Godot 4.4.1 export templates and inspect $logPath."
}

Write-Host ("Windows build created at {0}." -f $outputPath)
