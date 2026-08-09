function Resolve-GodotExecutable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Godot
    )

    $command = Get-Command $Godot -ErrorAction Stop
    $executablePath = $command.Source

    if ([IO.Path]::GetExtension($executablePath) -or [Environment]::OSVersion.Platform -ne "Win32NT") {
        return $executablePath
    }

    $drive = [IO.Path]::GetPathRoot($executablePath).TrimEnd("\")
    $hardLinks = & fsutil.exe hardlink list $executablePath 2>$null
    foreach ($hardLink in $hardLinks) {
        $candidate = if ($hardLink.StartsWith("\")) {
            $drive + $hardLink
        } else {
            $hardLink
        }

        if ([IO.Path]::GetExtension($candidate) -eq ".exe" -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    throw "Godot command '$executablePath' is extensionless and its executable hardlink could not be resolved."
}
