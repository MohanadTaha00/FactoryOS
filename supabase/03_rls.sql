-- =====================================================================
-- FactoryOS - Row Level Security policies (RBAC)
-- =====================================================================
-- These policies enforce the role-based access control rules described
-- in section 2.2 of the report.  Every table is protected; clients can
-- only see and mutate rows their role is authorised to touch.
-- =====================================================================

-- enable RLS on every table -------------------------------------------
alter table public.user_profiles        enable row level security;
alter table public.inventory_items      enable row level security;
alter table public.work_orders          enable row level security;
alter table public.material_consumption enable row level security;
alter table public.quality_logs         enable row level security;
alter table public.work_order_events    enable row level security;
alter table public.notifications        enable row level security;

-- helper: returns true if current user has any of the given roles -----
create or replace function public.has_any_role(roles user_role[])
returns boolean language sql stable as $$
  select exists (
    select 1 from public.user_profiles
    where id = auth.uid() and role = any(roles)
  );
$$;

-- ---------------------------------------------------------------------
-- user_profiles
-- ---------------------------------------------------------------------
drop policy if exists user_profiles_self_read on public.user_profiles;
create policy user_profiles_self_read on public.user_profiles
  for select using (true);                          -- everyone can read display names

drop policy if exists user_profiles_self_update on public.user_profiles;
create policy user_profiles_self_update on public.user_profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists user_profiles_admin_all on public.user_profiles;
create policy user_profiles_admin_all on public.user_profiles
  for all using (public.has_any_role(array['admin']::user_role[]))
  with check (public.has_any_role(array['admin']::user_role[]));

-- ---------------------------------------------------------------------
-- inventory_items
-- ---------------------------------------------------------------------
drop policy if exists inventory_read on public.inventory_items;
create policy inventory_read on public.inventory_items
  for select using (auth.uid() is not null);        -- any authenticated user

drop policy if exists inventory_write on public.inventory_items;
create policy inventory_write on public.inventory_items
  for all using (public.has_any_role(array['manager','admin']::user_role[]))
  with check (public.has_any_role(array['manager','admin']::user_role[]));

-- ---------------------------------------------------------------------
-- work_orders
-- ---------------------------------------------------------------------
drop policy if exists work_orders_read on public.work_orders;
create policy work_orders_read on public.work_orders
  for select using (
    public.has_any_role(array['manager','admin','qa']::user_role[])
    or assigned_to    = auth.uid()
    or qa_assigned_to = auth.uid()
    or created_by     = auth.uid()
  );

drop policy if exists work_orders_insert on public.work_orders;
create policy work_orders_insert on public.work_orders
  for insert with check (public.has_any_role(array['manager','admin']::user_role[]));

drop policy if exists work_orders_update_manager on public.work_orders;
create policy work_orders_update_manager on public.work_orders
  for update using (public.has_any_role(array['manager','admin']::user_role[]))
  with check (public.has_any_role(array['manager','admin']::user_role[]));

-- workers and QA mutate via RPC functions (which are SECURITY DEFINER),
-- so we don't need a direct UPDATE policy for them.

drop policy if exists work_orders_delete on public.work_orders;
create policy work_orders_delete on public.work_orders
  for delete using (public.has_any_role(array['admin']::user_role[]));

-- ---------------------------------------------------------------------
-- material_consumption
-- ---------------------------------------------------------------------
drop policy if exists material_read on public.material_consumption;
create policy material_read on public.material_consumption
  for select using (
    public.has_any_role(array['manager','admin','qa']::user_role[])
    or exists(
      select 1 from public.work_orders w
      where w.id = work_order_id
        and (w.assigned_to = auth.uid() or w.qa_assigned_to = auth.uid())
    )
  );

drop policy if exists material_write on public.material_consumption;
create policy material_write on public.material_consumption
  for all using (public.has_any_role(array['manager','admin']::user_role[]))
  with check (public.has_any_role(array['manager','admin']::user_role[]));

-- ---------------------------------------------------------------------
-- quality_logs
-- ---------------------------------------------------------------------
drop policy if exists quality_logs_read on public.quality_logs;
create policy quality_logs_read on public.quality_logs
  for select using (
    public.has_any_role(array['manager','admin','qa']::user_role[])
    or exists(
      select 1 from public.work_orders w
      where w.id = work_order_id and w.assigned_to = auth.uid()
    )
  );

drop policy if exists quality_logs_insert on public.quality_logs;
create policy quality_logs_insert on public.quality_logs
  for insert with check (public.has_any_role(array['qa','admin']::user_role[]));

-- ---------------------------------------------------------------------
-- work_order_events (read-only for everyone with read access to the WO)
-- ---------------------------------------------------------------------
drop policy if exists wo_events_read on public.work_order_events;
create policy wo_events_read on public.work_order_events
  for select using (
    public.has_any_role(array['manager','admin','qa']::user_role[])
    or exists(
      select 1 from public.work_orders w
      where w.id = work_order_id
        and (w.assigned_to = auth.uid() or w.qa_assigned_to = auth.uid() or w.created_by = auth.uid())
    )
  );

-- ---------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------
drop policy if exists notifications_read on public.notifications;
create policy notifications_read on public.notifications
  for select using (recipient_id = auth.uid() or public.has_any_role(array['admin']::user_role[]));

drop policy if exists notifications_update on public.notifications;
create policy notifications_update on public.notifications
  for update using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- =====================================================================
-- Realtime publication (Supabase) -- enable change-feeds for sync
-- =====================================================================
do $$ begin
  perform 1 from pg_publication where pubname = 'supabase_realtime';
  if found then
    execute 'alter publication supabase_realtime add table public.work_orders, public.inventory_items, public.material_consumption, public.quality_logs, public.notifications, public.work_order_events';
  end if;
exception when duplicate_object then null;
end $$;
