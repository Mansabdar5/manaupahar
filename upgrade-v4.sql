-- ManaUpahar upgrade 4: best-seller flag, delivery date on orders, tighter order limits.
-- Run ONCE in Supabase > SQL Editor > New query > Run. Safe to run again.
-- (Run upgrade-stock.sql and upgrade-v3.sql first if you have not already.)

alter table public.products add column if not exists featured boolean not null default false;
alter table public.orders add column if not exists delivery_date text;

drop policy if exists "customers place orders" on public.orders;
create policy "customers place orders" on public.orders for insert to anon, authenticated
  with check (status = 'new' and jsonb_typeof(items) = 'array'
              and jsonb_array_length(items) between 1 and 50 and length(ref) <= 20
              and pg_column_size(items) < 20000 and length(coalesce(delivery_date, '')) <= 20);
