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
