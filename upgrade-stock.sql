-- ManaUpahar stock upgrade.
-- Run this ONCE in Supabase > SQL Editor > New query > Run.
-- It adds a stock count to every gift. Safe to run again.

alter table public.products add column if not exists stock integer not null default 1 check (stock >= 0);

-- Gifts that were marked available get stock 1, sold-out gifts get 0.
-- Afterwards, set the real numbers in the admin page.
do $$
begin
  if exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='products' and column_name='in_stock') then
    update public.products set stock = case when in_stock then 1 else 0 end;
    alter table public.products drop column in_stock;
  end if;
end $$;
