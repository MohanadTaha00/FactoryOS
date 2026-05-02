# FactoryOS

Cross-platform industrial workflow and inventory management system (Flutter + Supabase), based on the SWE491 graduation project.

## Implemented scope

- Supabase-backed RBAC model (manager, worker, QA, admin)
- Work order lifecycle state machine
- Material consumption and inventory deduction via database RPC
- QA pass/fail flow with automatic rejection revert to `in_progress`
- Realtime table subscriptions for work orders, inventory, notifications
- Offline cache with Drift + queued mutation sync
- Role-specific dashboards (Manager, Worker, QA)
- PDF reports for individual work orders and summary
- In-app + local notification service

## Requirements

- Flutter 3.41+
- Dart 3.11+
- Supabase project
- Windows + Android targets enabled

## 1) Supabase setup

From the repo root, open and run SQL files in this order:

1. `supabase/01_schema.sql`
2. `supabase/02_functions.sql`
3. `supabase/03_rls.sql`
4. Create auth users (`manager@factoryos.demo`, `worker@factoryos.demo`, `qa@factoryos.demo`)
5. `supabase/04_seed.sql`

Detailed notes: `supabase/README.md`.

### Manager-created user accounts (worker/QA)

To let manager/admin create worker/QA accounts from the dashboard, deploy the
Edge Function in this repo:

```bash
npx supabase functions deploy manager-create-user --project-ref YOUR_PROJECT_REF
```

Then set Edge Function secrets (Supabase CLI **rejects** names starting with
`SUPABASE_`, so this repo uses these keys):

- `FACTORYOS_SUPABASE_URL` — project URL (`https://<ref>.supabase.co`)
- `FACTORYOS_SUPABASE_ANON_KEY` — anon public key
- `FACTORYOS_SUPABASE_SERVICE_ROLE_KEY` — **service role** (Dashboard → Settings → API)

Example (PowerShell; replace values):

```powershell
npx supabase secrets set `
  FACTORYOS_SUPABASE_URL=https://YOUR_REF.supabase.co `
  FACTORYOS_SUPABASE_ANON_KEY=YOUR_ANON_KEY `
  FACTORYOS_SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY `
  --project-ref YOUR_REF
```

Redeploy the function after changing secret names:

```bash
npx supabase functions deploy manager-create-user --project-ref YOUR_PROJECT_REF
```

This function enforces manager/admin access and uses the service role only on
the server side (never in the Flutter app).

## 2) Run app with credentials

Use Supabase URL + anon key as dart-defines:

```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

Android:

```bash
flutter run -d android \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

### Windows desktop “missing DLL” error

Do **not** run only `factoryos.exe` by itself from an empty folder. Flutter bundles plugins as separate DLLs next to the exe (`app_links_plugin.dll`, `connectivity_plus_plugin.dll`, etc.) plus a `data/` directory.

After `flutter build windows --release`, run the exe **from**:

`build/windows/x64/runner/Release/`

Or package everything into `release/Windows/`:

```powershell
.\scripts\package_windows_release.ps1
```

Then start `release\Windows\factoryos.exe`.

## 3) Build generated code

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 4) Test and analyze

```bash
flutter test
flutter analyze
```

## Project structure

- `lib/core/` app config, theme, routing
- `lib/data/` models, repositories, Supabase + Drift integration
- `lib/features/` auth, manager, worker, QA, shared UI, reports
- `lib/state/` Riverpod providers
- `supabase/` schema, functions, RLS, seed data

## Notes for dissertation/demo

- The database function `transition_work_order()` is the authoritative DFA guard.
- The database function `submit_for_qa()` performs inventory deduction before QA submission.
- Rejected QA decisions auto-revert the order to `in_progress`.
- Offline writes are persisted in `pending_mutations` and replayed when connectivity returns.

## Web build (Drift + WASM)

Flutter Web uses Drift’s WASM connector. This repo includes:

- `web/sqlite3.wasm` — from [sqlite3.dart releases](https://github.com/simolus3/sqlite3.dart/releases) (must match the SQLite WASM build drift expects).
- `web/drift_worker.js` — from [drift releases](https://github.com/simolus3/drift/releases) for your drift major/minor version.

They are copied into `build/web/` on `flutter build web`. Without them you’ll see:
`When compiling to the web, the web parameter needs to be set.` / provider errors after login.

## Secrets and GitHub

- **Never commit** Supabase **service role** keys or database passwords. Those belong only in Supabase Dashboard / server-side tooling.
- The **anon** key is intended for client apps but still must not live in tracked `.env` files: copy `.env.example` → `.env` locally (ignored by git) or use `--dart-define` / CI secrets.
- **Important:** Any key passed via `--dart-define` ends up **inside compiled** web/mobile/desktop binaries. Anyone can extract it from a shipped `.apk`, `.exe`, or `main.dart.js`. That’s normal for the anon key if **RLS policies** are correct; it is **not** safe for the service role key.

GitHub Actions (`.github/workflows/build_web.yml`) expects repository secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Configure under **Repository → Settings → Secrets and variables → Actions**.
