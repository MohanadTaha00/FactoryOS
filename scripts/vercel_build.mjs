#!/usr/bin/env node
/**
 * Vercel Git build driver — runs under Node (always present), avoids sh/bash exit 127.
 */
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
process.chdir(root);

console.log('[vercel_build] cwd=', process.cwd());

function run(cmd, extraEnv = {}) {
  console.log('[vercel_build]', cmd);
  execSync(cmd, {
    stdio: 'inherit',
    env: { ...process.env, ...extraEnv },
  });
}

if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
  const cfg = {
    url: process.env.SUPABASE_URL,
    anonKey: process.env.SUPABASE_ANON_KEY,
  };
  const out = path.join(root, 'web', 'supabase-runtime-config.local.js');
  fs.writeFileSync(
    out,
    '// Generated during Vercel build\nwindow.factoryosSupabase = ' +
      JSON.stringify(cfg) +
      ';\n'
  );
  console.log('[vercel_build] wrote', out);
}

const flutterRoot = path.join(os.homedir(), '.cache', 'factoryos-flutter-sdk');
const flutterBinDir = path.join(flutterRoot, 'bin');
const flutterExe = path.join(flutterBinDir, 'flutter');

if (!fs.existsSync(flutterExe)) {
  fs.mkdirSync(path.dirname(flutterRoot), { recursive: true });
  if (fs.existsSync(flutterRoot)) fs.rmSync(flutterRoot, { recursive: true });
  run(
    `git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${flutterRoot}"`,
    { GIT_TERMINAL_PROMPT: '0' }
  );
}

const delimiter = path.delimiter;
process.env.PATH = `${flutterBinDir}${delimiter}${process.env.PATH ?? ''}`;

try {
  run('flutter --version');
  run('flutter config --no-analytics');
  run('flutter precache --web');
  run('flutter pub get');
  run('flutter build web --release');
} catch {
  process.exit(1);
}

const indexHtml = path.join(root, 'build', 'web', 'index.html');
if (!fs.existsSync(indexHtml)) {
  console.error('[vercel_build] ERROR: missing', indexHtml);
  process.exit(1);
}
console.log('[vercel_build] OK: output ready');
