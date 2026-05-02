# Supabase Setup

Run these SQL files **in order** in the Supabase SQL editor against a fresh project.

| Order | File | What it does |
|-------|------|--------------|
| 1 | `01_schema.sql` | Tables, enums, indexes, triggers, views |
| 2 | `02_functions.sql` | State-machine + inventory RPCs |
| 3 | `03_rls.sql` | Row-Level Security (RBAC) policies |
| 4 | `04_seed.sql` | Demo inventory + work orders (run **after** creating the three demo users) |

## Demo users

In **Authentication → Users**, create three users (any password ≥ 6 chars):

- `manager@factoryos.demo`
- `worker@factoryos.demo`
- `qa@factoryos.demo`

Then run `04_seed.sql`.

## Project credentials

In **Project Settings → API** copy:

- `Project URL` → `SUPABASE_URL`
- `anon public` key → `SUPABASE_ANON_KEY`

Pass them to the Flutter app as dart-defines (see the root `README.md`).

## Edge Function: manager-create-user

FactoryOS includes `supabase/functions/manager-create-user/index.ts` to let a
manager/admin create worker or QA accounts from the app without exposing the
service role key to clients.

Deploy:

```bash
npx supabase functions deploy manager-create-user --project-ref YOUR_PROJECT_REF
```

Set function secrets (CLI forbids names starting with `SUPABASE_`):

- `FACTORYOS_SUPABASE_URL`
- `FACTORYOS_SUPABASE_ANON_KEY`
- `FACTORYOS_SUPABASE_SERVICE_ROLE_KEY`

Example:

```powershell
npx supabase secrets set FACTORYOS_SUPABASE_URL=https://YOUR_REF.supabase.co FACTORYOS_SUPABASE_ANON_KEY=YOUR_ANON FACTORYOS_SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE --project-ref YOUR_REF
```
