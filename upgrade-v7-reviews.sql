-- ManaUpahar customer reviews.
-- Run once in Supabase Dashboard > SQL Editor before deploying the updated site.

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  customer_name text not null check (char_length(customer_name) between 2 and 70),
  rating integer not null check (rating between 1 and 5),
  review_text text not null check (char_length(review_text) between 10 and 500),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create index if not exists reviews_product_status_created_idx
  on public.reviews (product_id, status, created_at desc);

alter table public.reviews enable row level security;

drop policy if exists "Public can read approved reviews" on public.reviews;
create policy "Public can read approved reviews"
  on public.reviews for select to anon, authenticated
  using (status = 'approved');

drop policy if exists "Customers can submit pending reviews" on public.reviews;
create policy "Customers can submit pending reviews"
  on public.reviews for insert to anon, authenticated
  with check (status = 'pending');

drop policy if exists "Admin manages reviews" on public.reviews;
create policy "Admin manages reviews"
  on public.reviews for all to authenticated
  using (true) with check (true);
