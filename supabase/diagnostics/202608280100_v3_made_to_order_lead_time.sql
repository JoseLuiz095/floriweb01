-- FloriWeb V3 RC5.1 - Prazo minimo para produtos sob encomenda
-- Regra: um pedido com produto made_to_order so pode usar data desejada
-- igual ou posterior a data de criacao do pedido + production_days.
-- A validacao fica no banco para impedir bypass do frontend.

begin;

create or replace function public.enforce_order_item_made_to_order_lead_time()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_desired_date date;
  v_order_date date;
  v_product_name text;
  v_made_to_order boolean;
  v_production_days integer;
  v_minimum_date date;
begin
  if new.product_id is null then
    return new;
  end if;

  select o.desired_date, o.created_at::date
    into v_desired_date, v_order_date
  from public.orders o
  where o.id = new.order_id;

  if not found then
    return new;
  end if;

  select p.name, p.made_to_order, greatest(coalesce(p.production_days, 0), 0)
    into v_product_name, v_made_to_order, v_production_days
  from public.products p
  where p.id = new.product_id;

  if not found or not coalesce(v_made_to_order, false) or coalesce(v_production_days, 0) <= 0 then
    return new;
  end if;

  v_minimum_date := coalesce(v_order_date, current_date) + v_production_days;

  if v_desired_date < v_minimum_date then
    raise exception 'Produto sob encomenda: "%" precisa de % dia(s) de producao. Escolha % ou uma data posterior.',
      v_product_name,
      v_production_days,
      to_char(v_minimum_date, 'DD/MM/YYYY')
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_order_item_made_to_order_lead_time() from public, anon, authenticated;

drop trigger if exists order_items_made_to_order_lead_time_trg on public.order_items;
create trigger order_items_made_to_order_lead_time_trg
before insert or update of order_id, product_id on public.order_items
for each row execute function public.enforce_order_item_made_to_order_lead_time();

-- Mantem a mesma regra caso a data desejada de um pedido existente seja alterada.
create or replace function public.enforce_order_desired_date_made_to_order_lead_time()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_max_days integer := 0;
  v_minimum_date date;
begin
  select coalesce(max(greatest(coalesce(p.production_days, 0), 0)), 0)
    into v_max_days
  from public.order_items oi
  join public.products p on p.id = oi.product_id
  where oi.order_id = new.id
    and p.made_to_order;

  if v_max_days <= 0 then
    return new;
  end if;

  v_minimum_date := coalesce(new.created_at::date, current_date) + v_max_days;

  if new.desired_date < v_minimum_date then
    raise exception 'Pedido com produto sob encomenda: a primeira data permitida e %. Escolha essa data ou uma posterior.',
      to_char(v_minimum_date, 'DD/MM/YYYY')
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_order_desired_date_made_to_order_lead_time() from public, anon, authenticated;

drop trigger if exists orders_made_to_order_desired_date_trg on public.orders;
create trigger orders_made_to_order_desired_date_trg
before update of desired_date on public.orders
for each row
when (old.desired_date is distinct from new.desired_date)
execute function public.enforce_order_desired_date_made_to_order_lead_time();

commit;
