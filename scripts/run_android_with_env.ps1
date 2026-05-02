# Runs `flutter run` on Android with SUPABASE_* from repo-root .env (no adb push needed).
param(
  [string]$Device = 'android'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dotEnv = Join-Path $root '.env'

if (-not (Test-Path $dotEnv)) {
  Write-Error ".env not found at $dotEnv"
}

$url = ''
$anon = ''
Get-Content $dotEnv | ForEach-Object {
  $line = $_.Trim()
  if ($line -match '^\s*#' -or $line -eq '') { return }
  if ($line -match '^SUPABASE_URL=(.+)$') { $url = $Matches[1].Trim() }
  elseif ($line -match '^SUPABASE_ANON_KEY=(.+)$') { $anon = $Matches[1].Trim() }
}

if ($url -eq '' -or $anon -eq '') {
  Write-Error ".env must define SUPABASE_URL and SUPABASE_ANON_KEY."
}

$buildDir = Join-Path $root 'build'
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
$defPath = Join-Path $buildDir 'android_dart_define.json'

$json = @{ SUPABASE_URL = $url; SUPABASE_ANON_KEY = $anon } | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($defPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host "Using dart-define-from-file: $defPath"
Set-Location $root
flutter run -d $Device --dart-define-from-file=$defPath
