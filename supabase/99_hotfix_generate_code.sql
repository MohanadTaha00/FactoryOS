create or replace function public.generate_work_order_code()
returns text
language plpgsql
as $$
declare
  v_year text := to_char(now(), 'YYYY');
  v_n integer;
begin
  select coalesce(
           max(substring(code from ('^WO-' || v_year || '-([0-9]+)$'))::int),
           0
         ) + 1
    into v_n
    from public.work_orders
   where code like 'WO-' || v_year || '-%';

  return 'WO-' || v_year || '-' || lpad(v_n::text, 4, '0');
end
$$;
