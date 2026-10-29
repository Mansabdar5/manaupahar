-- ManaUpahar upgrade 5: gift add-ons and delivery charges by pincode.
-- Run ONCE in Supabase > SQL Editor > New query > Run. Safe to run again.

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
