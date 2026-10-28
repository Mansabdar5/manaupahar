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
  ('note', 'Delivery and payment details will be confirmed with you on WhatsApp.')
on conflict (key) do nothing;
