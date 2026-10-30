-- ManaUpahar upgrade 6: handicraft details and occasions on every gift.
-- Run ONCE in Supabase > SQL Editor > New query > Run. Safe to run again.

alter table public.products add column if not exists material text;
alter table public.products add column if not exists made_by text;
alter table public.products add column if not exists region text;
alter table public.products add column if not exists size text;
alter table public.products add column if not exists care text;
alter table public.products add column if not exists prep_days integer not null default 0 check (prep_days >= 0);
alter table public.products add column if not exists occasions text[] not null default '{}';

-- Gifts that used an occasion as their category keep it as an occasion.
-- Afterwards, change each gift's category to its craft (Pottery, Wood, Textiles ...) in the admin page.
update public.products set occasions = array[category]
  where category in ('Birthday','Anniversary','Wedding','Festival','Baby & Kids') and cardinality(occasions) = 0;

insert into public.settings (key, value) values
  ('handmade_note', 'Each piece is handmade, so small variations are part of its charm.')
on conflict (key) do nothing;
