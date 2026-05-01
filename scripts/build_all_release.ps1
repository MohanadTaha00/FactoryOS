# Release builds: web + Windows + APK with Supabase defines (same as build_web.ps1).
# Uses project root `.env` or $env:SUPABASE_URL + $env:SUPABASE_ANON_KEY.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Invoke-ReleaseBuilds {
  param(
    [Parameter(Mandatory = $true)]
    [string[]] $DefineArgs
  )
  flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter build web --release @DefineArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter build windows --release @DefineArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  flutter build apk --release @DefineArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  Write-Host ""
  Write-Host "Done. Outputs:" -ForegroundColor Green
  Write-Host "  Web:     build\web\"
  Write-Host "  Windows: build\windows\x64\runner\Release\ (run factoryos.exe from this folder)"
  Write-Host "  APK:     build\app\outputs\flutter-apk\app-release.apk"
}

if (Test-Path ".env") {
  Invoke-ReleaseBuilds -DefineArgs @("--dart-define-from-file=.env")
  exit $LASTEXITCODE
}

if ($env:SUPABASE_URL -and $env:SUPABASE_ANON_KEY) {
  Invoke-ReleaseBuilds -DefineArgs @(
    "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)",
    "--dart-define=SUPABASE_ANON_KEY=$($env:SUPABASE_ANON_KEY)"
  )
  exit $LASTEXITCODE
}

Write-Host "No secrets found. Either:" -ForegroundColor Yellow
Write-Host "  1. Copy .env.example to .env and fill SUPABASE_URL / SUPABASE_ANON_KEY, then re-run." -ForegroundColor Yellow
Write-Host "  2. Set SUPABASE_URL and SUPABASE_ANON_KEY in this shell, then re-run." -ForegroundColor Yellow
exit 1
