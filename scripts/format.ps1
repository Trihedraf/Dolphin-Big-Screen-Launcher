#!/usr/bin/env pwsh
$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$OdinfmtVersion = "dev-2026-05"
$OlsDir = "tools/ols"

# Find odinfmt: PATH first, then local .exe.
$Odinfmt = $null
if (Get-Command odinfmt -ErrorAction SilentlyContinue) {
    $Odinfmt = "odinfmt"
} else {
    $Local = @(Get-ChildItem "$OlsDir/odinfmt-*.exe" -ErrorAction SilentlyContinue)[0]
    if ($Local -and (Test-Path $Local.FullName)) {
        $Odinfmt = $Local.FullName
    }
}

if (-not $Odinfmt) {
    Write-Host "odinfmt not found. Downloading ols $OdinfmtVersion..."

    $Arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        "arm64"
    } else {
        "x86_64"
    }

    $OlsZip = "ols-$Arch-pc-windows-msvc.zip"
    $OlsUrl = "https://github.com/DanielGavin/ols/releases/download/$OdinfmtVersion/$OlsZip"

    New-Item -ItemType Directory -Force -Path $OlsDir | Out-Null

    $TempZip = "$env:TEMP\ols-download.zip"
    Write-Host "Downloading $OlsUrl ..."
    Invoke-WebRequest -Uri $OlsUrl -OutFile $TempZip

    Write-Host "Extracting..."
    Expand-Archive -Path $TempZip -DestinationPath $OlsDir -Force
    Remove-Item $TempZip -Force

    $Local = @(Get-ChildItem "$OlsDir/odinfmt-*.exe" -ErrorAction SilentlyContinue)[0]
    if (-not $Local) {
        Write-Host "Error: odinfmt.exe not found after extraction."
        Get-ChildItem $OlsDir
        exit 1
    }

    $Odinfmt = $Local.FullName
}

Write-Host "Using: $Odinfmt"

# Format all .odin files in src/.
Write-Host "Formatting source files..."
& $Odinfmt -path:src -w
Write-Host "Done."