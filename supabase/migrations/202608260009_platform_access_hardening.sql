-- FloriWeb V2.7.1
-- Hardening do Admin Master, suspensão reversível e diagnóstico da plataforma.

alter table public.store_subscriptions
  add column if not exists status_before_suspension text;

alter table public.store_subscriptions drop constraint if exists store_subscriptions_previous_status_ck;
alter table public.store_subscriptions add constraint store_subscriptions_previous_status_ck
  check (status_before_suspension is null or status_before_suspension in ('trial','active'));

alter table public.stores
  add column if not exists suspended_at timestamptz,
  add column if not exists suspension_reason text,
  add column if not exists archived_at timestamptz;

-- Na V2.7.0 a suspensão também desligava stores.active. A partir desta versão,
-- suspensão é apenas uma trava operacional reversível por access_status.
update public.stores
set active = true
where access_status in ('online','suspended')
  and archived_at is null
  and active = false;

create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.store_users su
    join public.stores s on s.id=su.store_id
    where su.store_id=p_store_id
      and su.user_id=auth.uid()
      and su.active
      and s.archived_at is null
      and s.access_status='online'
  );
$$;

create or replace function public.is_store_admin(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.store_users su
    join public.stores s on s.id=su.store_id
    where su.store_id=p_store_id
      and su.user_id=auth.uid()
      and su.active
      and su.role in ('owner','admin')
      and s.archived_at is null
      and s.access_status='online'
  );
$$;

-- A loja fica no banco e seus usuários continuam vinculados. A trava é access_status.
drop policy if exists stores_public_read on public.stores;
create policy stores_public_read on public.stores for select to anon,authenticated using (
  archived_at is null and access_status='online'
);

-- Reforça todas as leituras públicas relacionadas à loja. Na V2.7.0 algumas tabelas
-- filhas ainda dependiam apenas de stores.active.
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon,authenticated using (
  active and exists(
    select 1 from public.stores s
    where s.id=store_id and s.archived_at is null and s.access_status='online'
  )
);

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon,authenticated using (
  active
  and exists(
    select 1 from public.stores s
    where s.id=store_id and s.archived_at is null and s.access_status='online'
  )
  and exists(
    select 1 from public.categories c
    where c.id=category_id and c.store_id=store_id and c.active
  )
);

drop policy if exists addons_public_read on public.addons;
create policy addons_public_read on public.addons for select to anon,authenticated using (
  active and exists(
    select 1 from public.stores s
    where s.id=store_id and s.archived_at is null and s.access_status='online'
  )
);

drop policy if exists delivery_zones_public_read on public.delivery_zones;
create policy delivery_zones_public_read on public.delivery_zones for select to anon,authenticated using (
  active and exists(
    select 1 from public.stores s
    where s.id=store_id and s.archived_at is null and s.access_status='online'
  )
);

drop policy if exists product_images_public_read on public.product_images;
create policy product_images_public_read on public.product_images for select to anon,authenticated using (
  exists(
    select 1
    from public.products p
    join public.stores s on s.id=p.store_id
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id
      and p.active
      and c.active
      and s.archived_at is null
      and s.access_status='online'
  )
);

drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_public_read on public.product_variants for select to anon,authenticated using (
  active and exists(
    select 1
    from public.products p
    join public.stores s on s.id=p.store_id
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id
      and p.active
      and c.active
      and s.archived_at is null
      and s.access_status='online'
  )
);

drop policy if exists product_addons_public_read on public.product_addons;
create policy product_addons_public_read on public.product_addons for select to anon,authenticated using (
  exists(
    select 1
    from public.products p
    join public.stores s on s.id=p.store_id
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id
      and p.active
      and c.active
      and s.archived_at is null
      and s.access_status='online'
  )
);

-- Defesa adicional: mesmo que alguém chame uma RPC antiga diretamente, uma loja
-- suspensa não pode receber novos pedidos.
create or replace function public.enforce_order_store_access()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1 from public.stores s
    where s.id=new.store_id
      and s.archived_at is null
      and s.access_status='online'
  ) then
    raise exception 'Floricultura temporariamente indisponível.' using errcode='P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists orders_store_access_trg on public.orders;
create trigger orders_store_access_trg
before insert on public.orders
for each row execute function public.enforce_order_store_access();

-- Diagnóstico seguro para o Admin Master. Ajuda a validar migrations/RLS sem alterar dados.
create or replace function public.platform_system_check()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso restrito ao Admin Master.' using errcode='42501';
  end if;

  select jsonb_build_object(
    'version', '2.7.1',
    'platformAdmin', true,
    'stores', (select count(*) from public.stores where archived_at is null),
    'storesOnline', (select count(*) from public.stores where archived_at is null and access_status='online'),
    'storesSuspended', (select count(*) from public.stores where archived_at is null and access_status='suspended'),
    'plans', (select count(*) from public.plans),
    'subscriptions', (select count(*) from public.store_subscriptions),
    'users', (select count(*) from public.store_users),
    'products', (select count(*) from public.products),
    'orders', (select count(*) from public.orders),
    'deliveryZones', (select count(*) from public.delivery_zones),
    'domains', (select count(*) from public.store_domains)
  ) into result;

  return result;
end;
$$;

revoke all on function public.platform_system_check() from public;
grant execute on function public.platform_system_check() to authenticated;

comment on column public.stores.access_status is 'Trava operacional reversível. suspended bloqueia vitrine e painel sem apagar a loja ou seus vínculos.';
comment on column public.stores.archived_at is 'Reserva para arquivamento definitivo lógico. Nulo para clientes ativos ou suspensos.';
