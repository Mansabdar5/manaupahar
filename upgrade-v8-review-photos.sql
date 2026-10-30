-- ManaUpahar customer photo reviews.
-- Run once in Supabase Dashboard > SQL Editor before deploying the matching website ZIP.

alter table public.reviews add column if not exists photo_path text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'reviews_photo_path_format'
      and conrelid = 'public.reviews'::regclass
  ) then
    alter table public.reviews
      add constraint reviews_photo_path_format
      check (photo_path is null or photo_path ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$');
  end if;
end $$;

-- Private bucket: customer photos are not public by default. The app creates
-- short-lived signed URLs only when the linked review is approved (or viewed by admin).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('review-photos', 'review-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg'];

drop policy if exists "Customers can upload review photos" on storage.objects;
create policy "Customers can upload review photos"
  on storage.objects for insert to anon, authenticated
  with check (
    bucket_id = 'review-photos'
    and name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'
  );

drop policy if exists "Approved review photos can be viewed" on storage.objects;
create policy "Approved review photos can be viewed"
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'review-photos'
    and exists (
      select 1 from public.reviews r
      where r.photo_path = storage.objects.name
        and (r.status = 'approved' or auth.role() = 'authenticated')
    )
  );
