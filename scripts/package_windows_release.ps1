# Packages the Windows desktop build into release/Windows (exe + all DLLs + data).
# Run from repo root after: flutter build windows --release ...

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root 'build\windows\x64\runner\Release'
$dst = Join-Path $root 'release\Windows'

if (-not (Test-Path (Join-Path $src 'factoryos.exe'))) {
  Write-Error "Missing factoryos.exe under Release - run flutter build windows --release first."
}

New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dst -Recurse -Force
Write-Host "Windows bundle copied to: $dst"
$exePath = Join-Path $dst 'factoryos.exe'
Write-Host "Launch: $exePath"
