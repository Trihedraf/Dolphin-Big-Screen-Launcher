#Requires -Version 5.1
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$odinVersion = "dev-2026-07a"
$raylibVersion = "6.0"
$odinDir = Join-Path $projectRoot "tools\odin"
$odinExe = Join-Path $odinDir "odin.exe"
$raylibWindowsDir = Join-Path $odinDir "vendor\raylib\windows"

function Ensure-Odin {
    if (Test-Path $odinExe) {
        return
    }

    Write-Host "Odin not found. Downloading Odin $odinVersion for Windows..."
    New-Item -ItemType Directory -Force -Path $odinDir | Out-Null

    $zipFile = Join-Path $env:TEMP "odin-windows.zip"
    $url = "https://github.com/odin-lang/Odin/releases/download/$odinVersion/odin-windows-amd64-$odinVersion.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing

    $extractDir = Join-Path $env:TEMP "odin-extract"
    if (Test-Path $extractDir) {
        Remove-Item $extractDir -Recurse -Force
    }
    Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

    # The zip may contain a nested directory; find the actual Odin root.
    $nested = Get-ChildItem -Path $extractDir -Directory | Select-Object -First 1
    $odinRoot = if ($nested) { $nested.FullName } else { $extractDir }

    # If tools\odin already exists (e.g. from the Linux/WSL toolchain), copy only
    # the Windows executable and any files that are not already present. This avoids
    # collisions with existing base/core/vendor directories.
    $existingItems = Get-ChildItem -Path $odinDir -Name
    Get-ChildItem -Path $odinRoot | ForEach-Object {
        $dest = Join-Path $odinDir $_.Name
        if (Test-Path $dest) {
            return
        }
        Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force
    }

    if (-not (Test-Path $odinExe)) {
        throw "Odin download/extraction failed. Expected: $odinExe"
    }

    Write-Host "Odin installed: $odinExe"
    & $odinExe version
}

function Ensure-RaylibWindows {
    $staticLib = Join-Path $raylibWindowsDir "raylib.lib"
    $dllLib = Join-Path $raylibWindowsDir "raylibdll.lib"

    if ((Test-Path $staticLib) -and (Test-Path $dllLib)) {
        return
    }

    Write-Host "Downloading raylib $raylibVersion (MSVC)..."
    New-Item -ItemType Directory -Force -Path $raylibWindowsDir | Out-Null

    # Remove any stale libraries (e.g. MinGW versions copied from WSL) before installing MSVC ones.
    if (Test-Path $staticLib) { Remove-Item $staticLib -Force }
    if (Test-Path $dllLib) { Remove-Item $dllLib -Force }

    $zipFile = Join-Path $env:TEMP "raylib-windows.zip"
    $url = "https://github.com/raysan5/raylib/releases/download/$raylibVersion/raylib-$raylibVersion`_win64_msvc16.zip"
    Invoke-WebRequest -Uri $url -OutFile $zipFile -UseBasicParsing

    $extractDir = Join-Path $env:TEMP "raylib-extract"
    if (Test-Path $extractDir) {
        Remove-Item $extractDir -Recurse -Force
    }
    Expand-Archive -Path $zipFile -DestinationPath $extractDir -Force

    $libDir = Join-Path $extractDir "raylib-$raylibVersion`_win64_msvc16\lib"
    Copy-Item -Path (Join-Path $libDir "raylib.lib") -Destination $staticLib -Force
    Copy-Item -Path (Join-Path $libDir "raylibdll.lib") -Destination $dllLib -Force

    Write-Host "raylib libraries installed."
}

$binDir = Join-Path $projectRoot "bin"
New-Item -ItemType Directory -Force -Path $binDir | Out-Null

Ensure-Odin
Ensure-RaylibWindows

Write-Host "Building..."
$Version = (Get-Content VERSION).Trim()
& $odinExe build src -out:bin\dbsl.exe -subsystem:windows -define:DBSL_VERSION=$Version @args
if ($LASTEXITCODE -ne 0) {
    throw "Build failed"
}

Write-Host "Build complete: bin\dbsl.exe"
