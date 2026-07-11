$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$AppId = "dbsl"
$Staging = "dist/$AppId-windows-x64"
$ZipPath = "dist/$AppId-windows-x64.zip"

if (Test-Path $Staging) { Remove-Item $Staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Staging | Out-Null

Copy-Item "bin/dbsl.exe" "$Staging/dbsl.exe"
if (Test-Path "config/dbsl.json") { Copy-Item "config/dbsl.json" "$Staging/dbsl.json.example" }
if (Test-Path "README.md") { Copy-Item "README.md" "$Staging/README.md" }

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path $Staging -DestinationPath $ZipPath
Remove-Item $Staging -Recurse -Force

Write-Host "Created $ZipPath"