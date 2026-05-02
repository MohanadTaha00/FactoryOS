#!/bin/sh
# Runs on Vercel (Linux) when the Git integration builds this project.
# Use POSIX sh — `bash` is not guaranteed on all Vercel images (exit 127).
# Must stay LF-only (see .gitattributes).
set -eu
cd "$(dirname "$0")/.."

echo "[vercel_build] pwd=$(pwd)"

if [ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  echo "[vercel_build] Writing web/supabase-runtime-config.local.js from env"
  node <<'NODE'
const fs = require('fs');
const cfg = {
  url: process.env.SUPABASE_URL,
  anonKey: process.env.SUPABASE_ANON_KEY,
};
fs.writeFileSync(
  'web/supabase-runtime-config.local.js',
  '// Generated during Vercel build\nwindow.factoryosSupabase = ' +
    JSON.stringify(cfg) +
    ';\n'
);
NODE
fi

export GIT_TERMINAL_PROMPT=0
FLUTTER_ROOT="${HOME}/.cache/factoryos-flutter-sdk"
if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  echo "[vercel_build] Installing Flutter SDK under ${FLUTTER_ROOT} ..."
  mkdir -p "$(dirname "${FLUTTER_ROOT}")"
  rm -rf "${FLUTTER_ROOT}"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_ROOT}"
fi
export PATH="${PATH}:${FLUTTER_ROOT}/bin"

command -v flutter >/dev/null 2>&1 || {
  echo "[vercel_build] ERROR: flutter not on PATH after install"
  exit 127
}

flutter --version
flutter config --no-analytics >/dev/null
flutter precache --web
flutter pub get
flutter build web --release

if [ ! -f build/web/index.html ]; then
  echo "[vercel_build] ERROR: build/web/index.html missing after flutter build web"
  exit 1
fi
echo "[vercel_build] OK: output ready"
