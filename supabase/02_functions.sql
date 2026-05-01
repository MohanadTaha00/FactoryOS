-- =====================================================================
-- FactoryOS - Stored Procedures (state-machine + inventory)
-- =====================================================================
-- These functions implement the State-Machine Synchronized Inventory
-- model described in the project report.  They are invoked from the
-- Flutter client through Supabase RPC.
-- =====================================================================

-- helper: get current caller's role -----------------------------------------
create or replace function public.current_role_safe()
returns user_role language sql stable as $$
  select role from public.user_profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- transition_work_order(p_id uuid, p_to work_order_status, p_message text)
-- Validates the transition against the state machine, persists the new
-- status, writes an audit row in work_order_events and produces any
-- side-effect notifications.
-- ---------------------------------------------------------------------
create or replace function public.transition_work_order(
  p_id      uuid,
  p_to      work_order_status,
  p_message text default null
) returns public.work_orders
language plpgsql security definer set search_path = public as $$
declare
  v_from   work_order_status;
  v_role   user_role;
  v_actor  uuid := auth.uid();
  v_wo     public.work_orders;
  v_valid  boolean := false;
begin
  select role into v_role from public.user_profiles where id = v_actor;
  select status into v_from from public.work_orders where id = p_id for update;

  if v_from is null then
    raise exception 'work_order % not found', p_id;
  end if;

  -- Allowed transitions (state machine) --------------------------------
  v_valid := case
    when v_from = 'pending'      and p_to in ('assigned','cancelled')                       then v_role in ('manager','admin')
    when v_from = 'assigned'     and p_to = 'in_progress'                                   then v_role in ('worker','admin')
    when v_from = 'assigned'     and p_to = 'cancelled'                                     then v_role in ('manager','admin')
    when v_from = 'in_progress'  and p_to = 'ready_for_qa'                                  then v_role in ('worker','admin')
    when v_from = 'in_progress'  and p_to = 'cancelled'                                     then v_role in ('manager','admin')
    when v_from = 'ready_for_qa' and p_to in ('approved','rejected')                        then v_role in ('qa','admin')
    when v_from = 'rejected'     and p_to = 'in_progress'                                   then v_role in ('worker','manager','admin')
    when v_from = 'approved'     and p_to = 'completed'                                     then v_role in ('manager','admin')
    else false
  end;

  if not v_valid then
    raise exception 'invalid transition % -> % for role %', v_from, p_to, v_role;
  end if;

  -- Apply timestamps so dashboards can compute durations ---------------
  update public.work_orders set
    status              = p_to,
    started_at          = case when p_to = 'in_progress'  and started_at         is null then now() else started_at end,
    submitted_for_qa_at = case when p_to = 'ready_for_qa'                          then now() else submitted_for_qa_at end,
    approved_at         = case when p_to = 'approved'                              then now() else approved_at end,
    completed_at        = case when p_to = 'completed'                             then now() else completed_at end
  where id = p_id
  returning * into v_wo;

  -- Audit row ----------------------------------------------------------
  insert into public.work_order_events(work_order_id, actor_id, from_status, to_status, message)
  values (p_id, v_actor, v_from, p_to, p_message);

  -- Side-effect notifications -----------------------------------------
  if p_to = 'ready_for_qa' and v_wo.qa_assigned_to is not null then
    insert into public.notifications(recipient_id, work_order_id, title, body, kind)
    values (v_wo.qa_assigned_to, p_id, 'Task ready for QA', v_wo.code || ' - ' || v_wo.title, 'ready_for_qa');
  end if;

  -- QA rejection must always return the order to the worker as in_progress (not left on
  -- 'rejected'). Notify the assignee only when one exists.
  if p_to = 'rejected' then
    update public.work_orders set status = 'in_progress' where id = p_id returning * into v_wo;
    insert into public.work_order_events(work_order_id, actor_id, from_status, to_status, message)
    values (p_id, v_actor, 'rejected', 'in_progress', 'auto-revert after QA rejection');
    if v_wo.assigned_to is not null then
      insert into public.notifications(recipient_id, work_order_id, title, body, kind)
      values (v_wo.assigned_to, p_id, 'QA rejected your task', v_wo.code || ' needs revisions', 'rejected');
    end if;
  end if;

  if p_to = 'approved' and v_wo.created_by is not null then
    insert into public.notifications(recipient_id, work_order_id, title, body, kind)
    values (v_wo.created_by, p_id, 'Task approved', v_wo.code || ' has passed QA', 'approved');
  end if;

  if p_to = 'assigned' and v_wo.assigned_to is not null then
    insert into public.notifications(recipient_id, work_order_id, title, body, kind)
    values (v_wo.assigned_to, p_id, 'New task assigned', v_wo.code || ' - ' || v_wo.title, 'task_assigned');
  end if;

  return v_wo;
end $$;

-- ---------------------------------------------------------------------
-- deduct_inventory(p_work_order_id uuid)
-- Atomically subtracts material_consumption.quantity_planned from
-- inventory_items.quantity for every line that has not been deducted
-- yet.  Raises if any item would go below zero.
-- ---------------------------------------------------------------------
create or replace function public.deduct_inventory(p_work_order_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  r   record;
begin
  for r in
    select mc.id as line_id, mc.inventory_id, mc.quantity_planned
    from public.material_consumption mc
    where mc.work_order_id = p_work_order_id
      and mc.deducted = false
  loop
    update public.inventory_items
       set quantity = quantity - r.quantity_planned
     where id = r.inventory_id
       and quantity >= r.quantity_planned;

    if not found then
      raise exception 'insufficient stock for inventory item %', r.inventory_id;
    end if;

    update public.material_consumption
       set deducted        = true,
           quantity_actual = r.quantity_planned
     where id = r.line_id;

    -- low stock notification ----------------------------------------
    insert into public.notifications(recipient_id, work_order_id, title, body, kind)
    select up.id, p_work_order_id,
           'Low stock alert',
           ii.name || ' is at ' || ii.quantity::text || ' ' || ii.unit,
           'low_stock'
      from public.inventory_items ii
      cross join public.user_profiles up
     where ii.id = r.inventory_id
       and ii.quantity <= ii.threshold
       and up.role in ('manager','admin');
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- submit_for_qa(p_work_order_id uuid)
-- Convenience: the worker's "submit" button calls this, which deducts
-- inventory then transitions the order to ready_for_qa.
-- ---------------------------------------------------------------------
create or replace function public.submit_for_qa(p_work_order_id uuid)
returns public.work_orders language plpgsql security definer set search_path = public as $$
declare
  v_wo public.work_orders;
begin
  perform public.deduct_inventory(p_work_order_id);
  v_wo := public.transition_work_order(p_work_order_id, 'ready_for_qa', 'submit_for_qa()');
  return v_wo;
end $$;

-- ---------------------------------------------------------------------
-- record_qa(p_work_order_id uuid, p_result qa_result, p_notes text)
-- The QA inspector calls this. It writes a quality_logs row and then
-- transitions to approved or rejected.  Rejection auto-reverts to
-- in_progress inside transition_work_order().
-- ---------------------------------------------------------------------
create or replace function public.record_qa(
  p_work_order_id uuid,
  p_result        qa_result,
  p_notes         text default null
) returns public.work_orders language plpgsql security definer set search_path = public as $$
declare
  v_wo public.work_orders;
begin
  insert into public.quality_logs(work_order_id, inspector_id, result, notes)
  values (p_work_order_id, auth.uid(), p_result, p_notes);

  if p_result = 'pass' then
    v_wo := public.transition_work_order(p_work_order_id, 'approved', p_notes);
  else
    v_wo := public.transition_work_order(p_work_order_id, 'rejected', p_notes);
  end if;

  return v_wo;
end $$;

-- ---------------------------------------------------------------------
-- generate_work_order_code() — sequence-style code WO-YYYY-NNNN
-- ---------------------------------------------------------------------
create or replace function public.generate_work_order_code()
returns text language plpgsql as $$
declare
  v_year text := to_char(now(), 'YYYY');
  v_n    integer;
begin
  select coalesce(max((regexp_matches(code, '^WO-' || v_year || '-(\d+)$'))[1]::int), 0) + 1
    into v_n
    from public.work_orders
   where code like 'WO-' || v_year || '-%';
  return 'WO-' || v_year || '-' || lpad(v_n::text, 4, '0');
end $$;
