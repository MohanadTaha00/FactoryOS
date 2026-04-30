insert into storage.buckets (id, name, public)
values ('order_attachments', 'order_attachments', true)
on conflict (id) do nothing;

drop policy if exists "order attachments read" on storage.objects;
create policy "order attachments read"
on storage.objects for select
to authenticated
using (bucket_id = 'order_attachments');

drop policy if exists "order attachments write" on storage.objects;
create policy "order attachments write"
on storage.objects for insert
to authenticated
with check (bucket_id = 'order_attachments');
