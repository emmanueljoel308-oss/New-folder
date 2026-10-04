$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$appName = "Wi-Fi Guard"
$pyinstallerArgs = @(
    "-m", "PyInstaller",
    "--clean",
    "--noconfirm",
    "--windowed",
    "--onedir",
    "--name", $appName,
    (Join-Path $root "wifi_guard.py")
)

Push-Location $root
try {
    & python @pyinstallerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed with exit code $LASTEXITCODE."
    }

    $isccCommand = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    $isccPath = if ($isccCommand) {
        $isccCommand.Source
    } else {
        @(
            "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
            "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
            "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }

    if (-not $isccPath) {
        throw "Inno Setup 6 was not found. Install it and ensure ISCC.exe is on PATH."
    }

    & $isccPath (Join-Path $root "installer.iss")
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
