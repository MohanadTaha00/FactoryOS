-- =====================================================================
-- FactoryOS - Database Schema
-- Mohanad Taha · Altinbas University · SWE491 Graduation Project
-- =====================================================================
-- This script creates all tables, enums, indexes, triggers, and views
-- that back the FactoryOS Flutter application.  Run it once against a
-- fresh Supabase project (SQL Editor → New Query → paste & run).
-- =====================================================================

-- Required extensions ------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- =====================================================================
-- 1. Enumerated types -- map directly to Dart enums in lib/data/models/enums.dart
-- =====================================================================
do $$ begin
  create type user_role as enum ('manager', 'worker', 'qa', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type work_order_status as enum (
    'pending',        -- created by manager, not assigned
    'assigned',       -- assigned to a worker, not yet started
    'in_progress',    -- worker has started production
    'ready_for_qa',   -- worker submitted, awaiting QA
    'approved',       -- QA approved (terminal)
    'rejected',       -- QA rejected, automatically reverts to in_progress
    'completed',      -- closed out by manager (terminal)
    'cancelled'       -- cancelled by manager (terminal)
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type qa_result as enum ('pass', 'fail');
exception when duplicate_object then null; end $$;

-- =====================================================================
-- 2. user_profiles
-- =====================================================================
-- Mirror of auth.users with the role + display name FactoryOS needs.
-- A row is created automatically by the trigger below whenever a new
-- user signs up via Supabase Auth.
create table if not exists public.user_profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text not null,
  role         user_role not null default 'worker',
  email        text unique,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index if not exists user_profiles_role_idx on public.user_profiles(role);

-- =====================================================================
-- 3. inventory_items
-- =====================================================================
create table if not exists public.inventory_items (
  id              uuid primary key default uuid_generate_v4(),
  sku             text not null unique,
  name            text not null,
  description     text,
  unit            text not null default 'pcs',
  quantity        numeric(14,3) not null default 0 check (quantity >= 0),
  threshold       numeric(14,3) not null default 0 check (threshold >= 0),
  unit_cost       numeric(14,2) not null default 0,
  location        text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists inventory_items_low_stock_idx
  on public.inventory_items(quantity)
  where quantity <= threshold;

-- =====================================================================
-- 4. work_orders
-- =====================================================================
create table if not exists public.work_orders (
  id                   uuid primary key default uuid_generate_v4(),
  code                 text not null unique,                  -- WO-2026-0001
  title                text not null,
  description          text,
  status               work_order_status not null default 'pending',
  priority             smallint not null default 3 check (priority between 1 and 5),

  created_by           uuid not null references public.user_profiles(id),
  assigned_to          uuid references public.user_profiles(id),
  qa_assigned_to       uuid references public.user_profiles(id),

  quantity_target      integer not null default 1 check (quantity_target > 0),
  quantity_produced    integer not null default 0 check (quantity_produced >= 0),
  attachment_url       text,

  created_at           timestamptz not null default now(),
  due_at               timestamptz,
  started_at           timestamptz,
  submitted_for_qa_at  timestamptz,
  approved_at          timestamptz,
  completed_at         timestamptz,
  updated_at           timestamptz not null default now()
);

create index if not exists work_orders_status_idx        on public.work_orders(status);
create index if not exists work_orders_assigned_to_idx   on public.work_orders(assigned_to);
create index if not exists work_orders_qa_assigned_to_idx on public.work_orders(qa_assigned_to);
create index if not exists work_orders_created_by_idx    on public.work_orders(created_by);

-- =====================================================================
-- 5. material_consumption (M:N between work_orders & inventory_items)
-- =====================================================================
create table if not exists public.material_consumption (
  id                uuid primary key default uuid_generate_v4(),
  work_order_id     uuid not null references public.work_orders(id) on delete cascade,
  inventory_id      uuid not null references public.inventory_items(id),
  quantity_planned  numeric(14,3) not null check (quantity_planned >= 0),
  quantity_actual   numeric(14,3) not null default 0 check (quantity_actual >= 0),
  deducted          boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique(work_order_id, inventory_id)
);

create index if not exists material_consumption_wo_idx  on public.material_consumption(work_order_id);
create index if not exists material_consumption_inv_idx on public.material_consumption(inventory_id);

-- =====================================================================
-- 6. quality_logs
-- =====================================================================
create table if not exists public.quality_logs (
  id              uuid primary key default uuid_generate_v4(),
  work_order_id   uuid not null references public.work_orders(id) on delete cascade,
  inspector_id    uuid not null references public.user_profiles(id),
  result          qa_result not null,
  notes           text,
  inspected_at    timestamptz not null default now()
);

create index if not exists quality_logs_wo_idx on public.quality_logs(work_order_id);

-- =====================================================================
-- 7. work_order_events (audit trail)
-- =====================================================================
create table if not exists public.work_order_events (
  id              uuid primary key default uuid_generate_v4(),
  work_order_id   uuid not null references public.work_orders(id) on delete cascade,
  actor_id        uuid references public.user_profiles(id),
  from_status     work_order_status,
  to_status       work_order_status not null,
  message         text,
  created_at      timestamptz not null default now()
);

create index if not exists work_order_events_wo_idx on public.work_order_events(work_order_id);

-- =====================================================================
-- 8. notifications
-- =====================================================================
create table if not exists public.notifications (
  id              uuid primary key default uuid_generate_v4(),
  recipient_id    uuid not null references public.user_profiles(id) on delete cascade,
  work_order_id   uuid references public.work_orders(id) on delete cascade,
  title           text not null,
  body            text,
  kind            text not null,                 -- 'task_assigned' | 'ready_for_qa' | 'rejected' | 'approved' | 'low_stock' | 'task_finished'
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists notifications_recipient_idx on public.notifications(recipient_id, read_at);

-- =====================================================================
-- 9. updated_at triggers
-- =====================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists trg_user_profiles_updated_at on public.user_profiles;
create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_inventory_items_updated_at on public.inventory_items;
create trigger trg_inventory_items_updated_at
  before update on public.inventory_items
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_work_orders_updated_at on public.work_orders;
create trigger trg_work_orders_updated_at
  before update on public.work_orders
  for each row execute function public.touch_updated_at();

drop trigger if exists trg_material_consumption_updated_at on public.material_consumption;
create trigger trg_material_consumption_updated_at
  before update on public.material_consumption
  for each row execute function public.touch_updated_at();

-- =====================================================================
-- 10. handle_new_user — auto-create user_profile on auth.users insert
-- =====================================================================
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.user_profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.email,
    coalesce((new.raw_user_meta_data->>'role')::user_role, 'worker')
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists trg_on_auth_user_created on auth.users;
create trigger trg_on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- 11. Helpful views
-- =====================================================================
create or replace view public.v_low_stock as
  select * from public.inventory_items where quantity <= threshold;

create or replace view public.v_open_work_orders as
  select * from public.work_orders
  where status not in ('approved', 'completed', 'cancelled');
