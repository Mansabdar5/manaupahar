-- ManaUpahar upgrade: multiple photos, personalisation, order records.
-- Run ONCE in Supabase > SQL Editor > New query > Run. Safe to run again.
-- (Run upgrade-stock.sql first if you have not already.)

-- 1. Gifts: several photos and an optional personalisation box
alter table public.products add column if not exists images text[] not null default '{}';
alter table public.products add column if not exists personalise boolean not null default false;
alter table public.products add column if not exists personalise_label text;
update public.products set images = array[image_url]
  where image_url is not null and cardinality(images) = 0;

-- 2. Orders
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  ref text not null,
  items jsonb not null,
  total numeric not null default 0,
  status text not null default 'new' check (status in ('new','confirmed','delivered','cancelled')),
  created_at timestamptz not null default now()
);
alter table public.orders enable row level security;

grant insert on public.orders to anon;
grant select, insert, update, delete on public.orders to authenticated;

-- Customers can only add a new order. They can never read or change orders.
drop policy if exists "customers place orders" on public.orders;
create policy "customers place orders" on public.orders for insert to anon, authenticated
  with check (status = 'new' and jsonb_typeof(items) = 'array'
              and jsonb_array_length(items) between 1 and 50 and length(ref) <= 20);

-- Only the logged-in admin can see and manage orders.
drop policy if exists "admin manages orders" on public.orders;
create policy "admin manages orders" on public.orders for all to authenticated using (true) with check (true);

-- 3. Changing an order's status also adjusts stock:
--    new -> confirmed/delivered  reduces stock
--    confirmed/delivered -> new/cancelled  puts the stock back
create or replace function public.set_order_status(order_id uuid, new_status text)
returns void
language plpgsql
security invoker
set search_path = public
as $fn$
declare
  o public.orders;
  it jsonb;
  was_active boolean;
  will_be_active boolean;
begin
  if new_status not in ('new','confirmed','delivered','cancelled') then
    raise exception 'Invalid status';
  end if;
  select * into o from public.orders where id = order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  was_active := o.status in ('confirmed','delivered');
  will_be_active := new_status in ('confirmed','delivered');

  if will_be_active and not was_active then
    for it in select value from jsonb_array_elements(o.items) loop
      update public.products
        set stock = greatest(0, stock - coalesce((it->>'qty')::int, 0))
        where id::text = it->>'id';
    end loop;
  elsif was_active and not will_be_active then
    for it in select value from jsonb_array_elements(o.items) loop
      update public.products
        set stock = stock + coalesce((it->>'qty')::int, 0)
        where id::text = it->>'id';
    end loop;
  end if;

  update public.orders set status = new_status where id = order_id;
end
$fn$;

revoke all on function public.set_order_status(uuid, text) from public, anon;
grant execute on function public.set_order_status(uuid, text) to authenticated;
