# Release web build with Supabase baked in (not committed).
# Option A: project root `.env` with SUPABASE_URL and SUPABASE_ANON_KEY (see .env.example)
# Option B: set $env:SUPABASE_URL and $env:SUPABASE_ANON_KEY in this shell
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (Test-Path ".env") {
  flutter build web --release --dart-define-from-file=.env
  exit $LASTEXITCODE
}

if ($env:SUPABASE_URL -and $env:SUPABASE_ANON_KEY) {
  flutter build web --release `
    "--dart-define=SUPABASE_URL=$($env:SUPABASE_URL)" `
    "--dart-define=SUPABASE_ANON_KEY=$($env:SUPABASE_ANON_KEY)"
  exit $LASTEXITCODE
}

Write-Host "No secrets found. Either:" -ForegroundColor Yellow
Write-Host "  1. Copy .env.example to .env and fill SUPABASE_URL / SUPABASE_ANON_KEY, then re-run this script." -ForegroundColor Yellow
Write-Host "  2. Set environment variables SUPABASE_URL and SUPABASE_ANON_KEY, then re-run." -ForegroundColor Yellow
exit 1
