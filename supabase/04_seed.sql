-- =====================================================================
-- FactoryOS - Seed data for the demo environment
-- =====================================================================
-- Run AFTER schema/functions/RLS, and AFTER you have created at least
-- three users via Supabase Auth (Auth → Users → Add user).  Update the
-- email addresses below to match the ones you created.
-- =====================================================================

-- 1. Promote the three demo users to their roles ---------------------------
update public.user_profiles set role = 'manager', full_name = 'Demo Manager'
  where email = 'manager@factoryos.demo';
update public.user_profiles set role = 'worker', full_name = 'Demo Worker'
  where email = 'worker@factoryos.demo';
update public.user_profiles set role = 'qa',      full_name = 'Demo QA'
  where email = 'qa@factoryos.demo';

-- 2. Inventory ----------------------------------------------------------
insert into public.inventory_items (sku, name, unit, quantity, threshold, unit_cost, location)
values
  ('STL-001', 'Steel sheet 1mm',    'sheet', 250, 50, 18.50, 'Rack A1'),
  ('STL-002', 'Steel rod 10mm',     'm',     800, 100, 4.20, 'Rack A2'),
  ('PNT-001', 'White enamel paint', 'L',      40, 10, 12.00, 'Rack B1'),
  ('BLT-001', 'M8 bolt',            'pcs',  5000, 500, 0.10, 'Bin C3'),
  ('NUT-001', 'M8 nut',             'pcs',  4500, 500, 0.05, 'Bin C4'),
  ('WIR-001', '2.5mm² copper wire', 'm',    1200, 200, 1.40, 'Rack D1')
on conflict (sku) do nothing;

-- 3. Sample work orders -------------------------------------------------
do $$
declare
  v_mgr   uuid;
  v_wkr   uuid;
  v_qa    uuid;
  v_wo1   uuid;
  v_wo2   uuid;
  v_steel uuid;
  v_paint uuid;
  v_bolt  uuid;
begin
  select id into v_mgr from public.user_profiles where email = 'manager@factoryos.demo';
  select id into v_wkr from public.user_profiles where email = 'worker@factoryos.demo';
  select id into v_qa  from public.user_profiles where email = 'qa@factoryos.demo';

  if v_mgr is null or v_wkr is null or v_qa is null then
    raise notice 'demo users not found - skipping work order seed';
    return;
  end if;

  select id into v_steel from public.inventory_items where sku = 'STL-001';
  select id into v_paint from public.inventory_items where sku = 'PNT-001';
  select id into v_bolt  from public.inventory_items where sku = 'BLT-001';

  -- Order #1 - already assigned to worker
  insert into public.work_orders (code, title, description, status, priority,
                                  created_by, assigned_to, qa_assigned_to,
                                  quantity_target, due_at)
  values (public.generate_work_order_code(),
          'Cabinet panel batch A',
          'Cut and paint 20 cabinet panels for client Acme.',
          'assigned', 2, v_mgr, v_wkr, v_qa, 20, now() + interval '3 days')
  returning id into v_wo1;

  insert into public.material_consumption(work_order_id, inventory_id, quantity_planned) values
    (v_wo1, v_steel, 20),
    (v_wo1, v_paint, 4),
    (v_wo1, v_bolt,  80);

  -- Order #2 - still pending
  insert into public.work_orders (code, title, description, status, priority,
                                  created_by, qa_assigned_to,
                                  quantity_target, due_at)
  values (public.generate_work_order_code(),
          'Workshop bench frame',
          'Welded frames for the new training workshop.',
          'pending', 3, v_mgr, v_qa, 5, now() + interval '7 days')
  returning id into v_wo2;
end $$;
