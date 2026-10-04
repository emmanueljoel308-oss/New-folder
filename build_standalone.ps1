$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$appName = "Wi-Fi Guard"
$builds = @(
    @{
        Name = "x64"
        Bits = 64
        Python = if ($env:PYTHON_X64) { $env:PYTHON_X64 } else { "$env:LOCALAPPDATA\Programs\Python\Python38-x64\python.exe" }
        Machine = 0x8664
    },
    @{
        Name = "x86"
        Bits = 32
        Python = if ($env:PYTHON_X86) { $env:PYTHON_X86 } else { "$env:LOCALAPPDATA\Programs\Python\Python38-x86\python.exe" }
        Machine = 0x14C
    }
)

function Get-PythonBuildInfo($python) {
    $probe = "import struct, sys; print('%s.%s|%s' % (sys.version_info[0], sys.version_info[1], struct.calcsize('P') * 8))"
    $info = & $python -c $probe
    if ($LASTEXITCODE -ne 0) {
        throw "Could not inspect Python interpreter: $python"
    }
    return $info.Trim()
}

Push-Location $root
try {
    foreach ($build in $builds) {
        if (-not (Test-Path $build.Python)) {
            throw "Python 3.8 $($build.Name) was not found at '$($build.Python)'. Install Python 3.8 for both architectures, or set PYTHON_X64 and PYTHON_X86 to their interpreter paths."
        }

        $pythonInfo = Get-PythonBuildInfo $build.Python
        if ($pythonInfo -ne "3.8|$($build.Bits)") {
            throw "Expected Python 3.8 $($build.Name), but '$($build.Python)' reports '$pythonInfo'."
        }

        $pyinstallerVersion = & $build.Python -c "import PyInstaller; print(PyInstaller.__version__)" 2>$null
        if ($LASTEXITCODE -ne 0 -or $pyinstallerVersion.Trim() -ne "5.13.2") {
            throw "Install the pinned build dependency for Python $($build.Name): `"$($build.Python)`" -m pip install -r requirements-build.txt"
        }

        $outputDir = Join-Path $root "dist\windows-$($build.Name)"
        $workDir = Join-Path $root "build\pyinstaller-$($build.Name)"
        $arguments = @(
            "-m", "PyInstaller",
            "--clean",
            "--noconfirm",
            "--windowed",
            "--onefile",
            "--name", $appName,
            "--distpath", $outputDir,
            "--workpath", $workDir,
            "--specpath", $workDir,
            (Join-Path $root "wifi_guard.py")
        )

        & $build.Python @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "PyInstaller failed for Windows $($build.Name) with exit code $LASTEXITCODE."
        }

        $executable = Join-Path $outputDir "$appName.exe"
        if (-not (Test-Path $executable)) {
            throw "PyInstaller did not create the expected executable: $executable"
        }

        $bytes = [System.IO.File]::ReadAllBytes($executable)
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        if ($machine -ne $build.Machine) {
            throw "The Windows $($build.Name) executable has unexpected PE machine type 0x$($machine.ToString('X4'))."
        }

        $size = [math]::Round((Get-Item $executable).Length / 1MB, 2)
        Write-Host "Windows $($build.Name): $executable ($size MB)"
    }

    $packageDir = Join-Path $root "dist\payhip"
    $zipPath = Join-Path $root "dist\Wi-Fi-Guard-Windows.zip"
    if (Test-Path $packageDir) {
        Remove-Item -LiteralPath $packageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $packageDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $root "PAYHIP-README.txt") -Destination $packageDir
    foreach ($build in $builds) {
        $architectureDir = Join-Path $packageDir "windows-$($build.Name)"
        New-Item -ItemType Directory -Path $architectureDir | Out-Null
        Copy-Item -LiteralPath (Join-Path $root "dist\windows-$($build.Name)\$appName.exe") -Destination $architectureDir
    }

    if (Test-Path $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "Payhip upload: $zipPath"
}
finally {
    Pop-Location
}
