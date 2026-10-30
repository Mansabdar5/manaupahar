-- ManaUpahar database setup.
-- Paste this whole file into Supabase > SQL Editor > New query, then click Run. Run it once.

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  price numeric not null,
  description text,
  image_url text,
  stock integer not null default 1 check (stock >= 0),
  images text[] not null default '{}',
  personalise boolean not null default false,
  personalise_label text,
  featured boolean not null default false,
  material text,
  made_by text,
  region text,
  size text,
  care text,
  prep_days integer not null default 0 check (prep_days >= 0),
  occasions text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists public.settings (
  key text primary key,
  value text
);

alter table public.products enable row level security;
alter table public.settings enable row level security;

-- Everyone can look at gifts and settings (needed for the public shop).
drop policy if exists "public read products" on public.products;
create policy "public read products" on public.products for select using (true);
drop policy if exists "public read settings" on public.settings;
create policy "public read settings" on public.settings for select using (true);

-- Only a logged-in admin can add, change or delete.
drop policy if exists "admin write products" on public.products;
create policy "admin write products" on public.products for all to authenticated using (true) with check (true);
drop policy if exists "admin write settings" on public.settings;
create policy "admin write settings" on public.settings for all to authenticated using (true) with check (true);

-- Photo storage bucket (public so photos show in the shop).
insert into storage.buckets (id, name, public) values ('gifts', 'gifts', true)
on conflict (id) do nothing;

drop policy if exists "public read gift photos" on storage.objects;
create policy "public read gift photos" on storage.objects for select using (bucket_id = 'gifts');
drop policy if exists "admin upload gift photos" on storage.objects;
create policy "admin upload gift photos" on storage.objects for insert to authenticated with check (bucket_id = 'gifts');
drop policy if exists "admin update gift photos" on storage.objects;
create policy "admin update gift photos" on storage.objects for update to authenticated using (bucket_id = 'gifts');
drop policy if exists "admin delete gift photos" on storage.objects;
create policy "admin delete gift photos" on storage.objects for delete to authenticated using (bucket_id = 'gifts');

-- Starting settings. Change the number later in Admin > Settings.
insert into public.settings (key, value) values
  ('whatsapp', '919999999999'),
  ('note', 'Delivery and payment details will be confirmed with you on WhatsApp.'),
  ('handmade_note', 'Each piece is handmade, so small variations are part of its charm.')
on conflict (key) do nothing;

-- Orders (placed from the shop, managed in the admin page)
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  ref text not null,
  items jsonb not null,
  total numeric not null default 0,
  status text not null default 'new' check (status in ('new','confirmed','delivered','cancelled')),
  delivery_date text,
  created_at timestamptz not null default now()
);
alter table public.orders enable row level security;

grant insert on public.orders to anon;
grant select, insert, update, delete on public.orders to authenticated;

-- Customers can only add a new order. They can never read or change orders.
drop policy if exists "customers place orders" on public.orders;
create policy "customers place orders" on public.orders for insert to anon, authenticated
  with check (status = 'new' and jsonb_typeof(items) = 'array'
              and jsonb_array_length(items) between 1 and 50 and length(ref) <= 20
              and pg_column_size(items) < 20000 and length(coalesce(delivery_date, '')) <= 20);

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

-- Add-ons customers can tick (gift wrapping, greeting card, ...)
create table if not exists public.addons (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  price numeric not null default 0 check (price >= 0),
  per_item boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

-- Delivery areas: which pincodes, how much, free above what amount
create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  label text not null,
  pincodes text not null,
  charge numeric not null default 0 check (charge >= 0),
  free_above numeric check (free_above is null or free_above >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.addons enable row level security;
alter table public.delivery_zones enable row level security;

grant select on public.addons, public.delivery_zones to anon;
grant select, insert, update, delete on public.addons, public.delivery_zones to authenticated;

-- Customers see only active entries. The admin sees and manages everything.
drop policy if exists "public read addons" on public.addons;
create policy "public read addons" on public.addons for select using (active);
drop policy if exists "admin manages addons" on public.addons;
create policy "admin manages addons" on public.addons for all to authenticated using (true) with check (true);

drop policy if exists "public read zones" on public.delivery_zones;
create policy "public read zones" on public.delivery_zones for select using (active);
drop policy if exists "admin manages zones" on public.delivery_zones;
create policy "admin manages zones" on public.delivery_zones for all to authenticated using (true) with check (true);


-- Customer reviews. Public submissions are held for admin approval.
create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  customer_name text not null check (char_length(customer_name) between 2 and 70),
  rating integer not null check (rating between 1 and 5),
  review_text text not null check (char_length(review_text) between 10 and 500),
  photo_path text check (photo_path is null or photo_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);
create index if not exists reviews_product_status_created_idx
  on public.reviews (product_id, status, created_at desc);
alter table public.reviews enable row level security;
drop policy if exists "Public can read approved reviews" on public.reviews;
create policy "Public can read approved reviews" on public.reviews for select to anon, authenticated using (status = 'approved');
drop policy if exists "Customers can submit pending reviews" on public.reviews;
create policy "Customers can submit pending reviews" on public.reviews for insert to anon, authenticated with check (status = 'pending');
drop policy if exists "Admin manages reviews" on public.reviews;
create policy "Admin manages reviews" on public.reviews for all to authenticated using (true) with check (true);

-- Private storage for customer review photos. Only approved photos are readable by shoppers.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('review-photos', 'review-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 5242880, allowed_mime_types = array['image/jpeg'];
drop policy if exists "Customers can upload review photos" on storage.objects;
create policy "Customers can upload review photos" on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'review-photos' and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');
drop policy if exists "Approved review photos can be viewed" on storage.objects;
create policy "Approved review photos can be viewed" on storage.objects for select to anon, authenticated
  using (bucket_id = 'review-photos' and exists (
    select 1 from public.reviews r where r.photo_path = storage.objects.name
      and (r.status = 'approved' or auth.role() = 'authenticated')
  ));

-- ===== Order tracking (same as upgrade-v9-order-tracking.sql) =====
-- ManaUpahar order tracking.
-- Run once in Supabase Dashboard > SQL Editor BEFORE uploading the new website files.
-- Safe to run more than once.

-- 1. More order stages and tracking details
alter table public.orders add column if not exists courier text;
alter table public.orders add column if not exists tracking_no text;
alter table public.orders add column if not exists tracking_url text;
alter table public.orders add column if not exists customer_note text;
alter table public.orders add column if not exists status_log jsonb;

-- Old orders get a simple history based on what we know
update public.orders
set status_log = case when status = 'new'
    then jsonb_build_array(jsonb_build_object('s', 'new', 'at', created_at))
    else jsonb_build_array(jsonb_build_object('s', 'new', 'at', created_at),
                           jsonb_build_object('s', status, 'at', created_at)) end
where status_log is null;

alter table public.orders alter column status_log set default jsonb_build_array(jsonb_build_object('s', 'new', 'at', now()));
alter table public.orders alter column status_log set not null;

do $$
declare c text;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.orders'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) like '%status%new%' loop
    execute format('alter table public.orders drop constraint %I', c);
  end loop;
  alter table public.orders add constraint orders_status_check
    check (status in ('new','confirmed','packed','shipped','delivered','cancelled'));
  if not exists (select 1 from pg_constraint where conname = 'orders_tracking_fields_check' and conrelid = 'public.orders'::regclass) then
    alter table public.orders add constraint orders_tracking_fields_check
      check (length(coalesce(courier, '')) <= 80 and length(coalesce(tracking_no, '')) <= 80
         and length(coalesce(customer_note, '')) <= 300
         and (tracking_url is null or (tracking_url ~* '^https?://' and length(tracking_url) <= 500)));
  end if;
end $$;

-- 2. Customers may only fill in the order itself; tracking details are admin-only
revoke insert on public.orders from anon;
grant insert (ref, items, total, delivery_date) on public.orders to anon;

-- 3. Status changes keep a history and still adjust stock
--    new -> confirmed/packed/shipped/delivered  reduces stock
--    those -> new/cancelled                     puts the stock back
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
  if new_status not in ('new','confirmed','packed','shipped','delivered','cancelled') then
    raise exception 'Invalid status';
  end if;
  select * into o from public.orders where id = order_id for update;
  if not found then
    raise exception 'Order not found';
  end if;
  if o.status = new_status then
    return;
  end if;
  was_active := o.status in ('confirmed','packed','shipped','delivered');
  will_be_active := new_status in ('confirmed','packed','shipped','delivered');

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

  update public.orders
    set status = new_status,
        status_log = coalesce(status_log, '[]'::jsonb) || jsonb_build_array(jsonb_build_object('s', new_status, 'at', now()))
    where id = order_id;
end
$fn$;

revoke all on function public.set_order_status(uuid, text) from public, anon;
grant execute on function public.set_order_status(uuid, text) to authenticated;

-- 4. Public tracking lookup. Customers can only look up ONE order by its reference.
--    Prices, personalisation text and other orders are never exposed.
create or replace function public.track_order(p_ref text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  r text := upper(btrim(coalesce(p_ref, '')));
  o public.orders;
begin
  if r !~ '^MU-[A-Z0-9]{3,12}$' then
    return null;
  end if;
  select * into o from public.orders where upper(ref) = r order by created_at desc limit 1;
  if not found then
    return null;
  end if;
  return jsonb_build_object(
    'ref', o.ref,
    'status', o.status,
    'created_at', o.created_at,
    'delivery_date', o.delivery_date,
    'courier', o.courier,
    'tracking_no', o.tracking_no,
    'tracking_url', o.tracking_url,
    'customer_note', o.customer_note,
    'log', o.status_log,
    'items', coalesce((select jsonb_agg(jsonb_build_object('name', i->>'name', 'qty', i->>'qty', 'kind', i->>'kind'))
                       from jsonb_array_elements(o.items) i), '[]'::jsonb)
  );
end
$fn$;

revoke all on function public.track_order(text) from public;
grant execute on function public.track_order(text) to anon, authenticated;
