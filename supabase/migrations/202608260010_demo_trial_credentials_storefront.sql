-- FloriWeb V2.9.0
-- Credencial temporária, configuração do período Demo, expiração automática e vitrine neutra para lojas indisponíveis.

-- Pré-requisitos: esta migration deve ser aplicada após a 202608260009.
do $$
begin
  if to_regclass('public.stores') is null
     or to_regclass('public.store_users') is null
     or to_regclass('public.store_subscriptions') is null
     or to_regclass('public.plans') is null
     or to_regclass('public.delivery_zones') is null
     or to_regclass('public.store_domains') is null then
    raise exception 'FloriWeb V2.9.0 requer as migrations anteriores até 202608260009_platform_access_hardening.sql.';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='stores' and column_name='access_status'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='stores' and column_name='archived_at'
  ) then
    raise exception 'Estrutura de gestão da plataforma incompleta. Aplique primeiro as migrations 008 e 009.';
  end if;
  if to_regprocedure('public.is_platform_admin()') is null then
    raise exception 'Função is_platform_admin ausente. Aplique primeiro a migration 008.';
  end if;
end $$;

alter table public.store_users
  add column if not exists must_change_password boolean not null default false;

create table if not exists public.platform_settings (
  id smallint primary key default 1 check (id = 1),
  demo_duration_days integer not null default 30 check (demo_duration_days between 1 and 365),
  demo_warning_days integer not null default 7 check (demo_warning_days between 1 and 90),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint platform_settings_demo_warning_ck check (demo_warning_days < demo_duration_days)
);

insert into public.platform_settings(id,demo_duration_days,demo_warning_days)
values (1,30,7)
on conflict(id) do nothing;

create index if not exists store_subscriptions_expiry_idx
  on public.store_subscriptions(status,expires_at)
  where expires_at is not null;

drop trigger if exists platform_settings_set_updated_at on public.platform_settings;
create trigger platform_settings_set_updated_at
before update on public.platform_settings
for each row execute function public.set_updated_at();

alter table public.platform_settings enable row level security;
drop policy if exists platform_settings_master_all on public.platform_settings;
create policy platform_settings_master_all on public.platform_settings
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

-- Garante que assinaturas Demo existentes tenham prazo definido.
update public.store_subscriptions ss
set expires_at = coalesce(
      ss.expires_at,
      ss.started_at + make_interval(days => (select demo_duration_days from public.platform_settings where id=1))
    ),
    billing_amount = 0,
    due_day = null,
    next_due_date = null,
    status = case when ss.status='active' then 'trial' else ss.status end
from public.plans p
where p.id=ss.plan_id
  and p.code='DEMO'
  and ss.status in ('trial','active','suspended');

-- Função central de disponibilidade. Mesmo que o cron ainda não tenha rodado,
-- um Demo vencido deixa de ter vitrine, admin e novos pedidos imediatamente.
create or replace function public.store_accessible(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.stores s
    where s.id=p_store_id
      and s.archived_at is null
      and s.active
      and s.access_status='online'
      and not exists (
        select 1
        from public.store_subscriptions ss
        join public.plans p on p.id=ss.plan_id
        where ss.store_id=s.id
          and p.code='DEMO'
          and ss.status='trial'
          and ss.expires_at is not null
          and ss.expires_at <= now()
      )
  );
$$;
revoke all on function public.store_accessible(uuid) from public;
grant execute on function public.store_accessible(uuid) to anon, authenticated, service_role;

create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.store_accessible(p_store_id)
    and exists (
      select 1
      from public.store_users su
      where su.store_id=p_store_id
        and su.user_id=auth.uid()
        and su.active
    );
$$;

create or replace function public.is_store_admin(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.store_accessible(p_store_id)
    and exists (
      select 1
      from public.store_users su
      where su.store_id=p_store_id
        and su.user_id=auth.uid()
        and su.active
        and su.role in ('owner','admin')
    );
$$;

-- Resolve apenas o mínimo necessário para mostrar uma mensagem pública neutra.
-- Motivo de suspensão, financeiro e dados administrativos nunca são expostos.
create or replace function public.resolve_storefront_status(p_slug text default null, p_hostname text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  v_store public.stores%rowtype;
  v_store_id uuid;
begin
  if nullif(trim(coalesce(p_hostname,'')),'') is not null then
    select sd.store_id into v_store_id
    from public.store_domains sd
    where sd.active
      and lower(sd.domain)=lower(trim(p_hostname))
    order by sd.is_primary desc, sd.created_at asc
    limit 1;
  end if;

  if v_store_id is not null then
    select * into v_store from public.stores where id=v_store_id and archived_at is null limit 1;
  elsif nullif(trim(coalesce(p_slug,'')),'') is not null then
    select * into v_store from public.stores where lower(slug)=lower(trim(p_slug)) and archived_at is null limit 1;
  end if;

  if v_store.id is null then
    return jsonb_build_object('found',false);
  end if;

  return jsonb_build_object(
    'found', true,
    'id', v_store.id,
    'slug', v_store.slug,
    'name', v_store.name,
    'status', case when public.store_accessible(v_store.id) then 'online' else 'unavailable' end
  );
end;
$$;
revoke all on function public.resolve_storefront_status(text,text) from public;
grant execute on function public.resolve_storefront_status(text,text) to anon, authenticated;

-- Expira Demo e preserva todos os dados. Somente access_status e assinatura são alterados.
create or replace function public.platform_expire_demo_trials()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_count integer := 0;
begin
  with expired as (
    update public.store_subscriptions ss
    set status='suspended',
        status_before_suspension='trial',
        updated_at=now()
    from public.plans p
    where p.id=ss.plan_id
      and p.code='DEMO'
      and ss.status='trial'
      and ss.expires_at is not null
      and ss.expires_at <= now()
    returning ss.store_id
  ), suspended as (
    update public.stores s
    set access_status='suspended',
        suspended_at=coalesce(s.suspended_at,now()),
        suspension_reason='Período de demonstração encerrado automaticamente'
    where s.id in (select store_id from expired)
      and s.archived_at is null
    returning s.id
  )
  select count(*) into v_count from suspended;

  return v_count;
end;
$$;
revoke all on function public.platform_expire_demo_trials() from public;
grant execute on function public.platform_expire_demo_trials() to service_role;

-- Tenta habilitar execução automática horária. Se pg_cron não estiver disponível,
-- store_accessible continua bloqueando o acesso no instante do vencimento.
do $$
declare
  r record;
begin
  begin
    create extension if not exists pg_cron;
  exception when others then
    raise notice 'pg_cron não pôde ser habilitado automaticamente: %', sqlerrm;
  end;

  if to_regnamespace('cron') is not null then
    begin
      for r in execute 'select jobid from cron.job where jobname = ''floriweb-expire-demo-trials''' loop
        execute format('select cron.unschedule(%s)', r.jobid);
      end loop;
      execute 'select cron.schedule(''floriweb-expire-demo-trials'', ''15 * * * *'', ''select public.platform_expire_demo_trials();'')';
    exception when others then
      raise notice 'Agendamento pg_cron não pôde ser criado automaticamente: %', sqlerrm;
    end;
  end if;
end $$;

-- Políticas públicas passam pela função central de disponibilidade.
drop policy if exists stores_public_read on public.stores;
create policy stores_public_read on public.stores for select to anon,authenticated
using (public.store_accessible(id));

drop policy if exists store_domains_public_read on public.store_domains;
create policy store_domains_public_read on public.store_domains for select to anon,authenticated
using (active and public.store_accessible(store_id));

drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon,authenticated
using (active and public.store_accessible(store_id));

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon,authenticated using (
  active
  and public.store_accessible(store_id)
  and exists(select 1 from public.categories c where c.id=category_id and c.store_id=store_id and c.active)
);

drop policy if exists addons_public_read on public.addons;
create policy addons_public_read on public.addons for select to anon,authenticated
using (active and public.store_accessible(store_id));

drop policy if exists delivery_zones_public_read on public.delivery_zones;
create policy delivery_zones_public_read on public.delivery_zones for select to anon,authenticated
using (active and public.store_accessible(store_id));

drop policy if exists product_images_public_read on public.product_images;
create policy product_images_public_read on public.product_images for select to anon,authenticated using (
  exists(
    select 1
    from public.products p
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id and p.active and c.active and public.store_accessible(p.store_id)
  )
);

drop policy if exists product_variants_public_read on public.product_variants;
create policy product_variants_public_read on public.product_variants for select to anon,authenticated using (
  active and exists(
    select 1
    from public.products p
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id and p.active and c.active and public.store_accessible(p.store_id)
  )
);

drop policy if exists product_addons_public_read on public.product_addons;
create policy product_addons_public_read on public.product_addons for select to anon,authenticated using (
  exists(
    select 1
    from public.products p
    join public.categories c on c.id=p.category_id and c.store_id=p.store_id
    where p.id=product_id and p.active and c.active and public.store_accessible(p.store_id)
  )
);

create or replace function public.enforce_order_store_access()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.store_accessible(new.store_id) then
    raise exception 'Floricultura temporariamente indisponível.' using errcode='P0001';
  end if;
  return new;
end;
$$;

-- Diagnóstico atualizado com Demo e configuração global.
create or replace function public.platform_system_check()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
  v_duration integer := 30;
  v_warning integer := 7;
  v_cron_scheduled boolean := false;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso restrito ao Admin Master.' using errcode='42501';
  end if;

  select demo_duration_days,demo_warning_days into v_duration,v_warning
  from public.platform_settings where id=1;

  if to_regnamespace('cron') is not null then
    begin
      execute 'select exists(select 1 from cron.job where jobname = ''floriweb-expire-demo-trials'')' into v_cron_scheduled;
    exception when others then
      v_cron_scheduled := false;
    end;
  end if;

  select jsonb_build_object(
    'version', '2.9.0',
    'platformAdmin', true,
    'stores', (select count(*) from public.stores where archived_at is null),
    'storesOnline', (select count(*) from public.stores where archived_at is null and public.store_accessible(id)),
    'storesSuspended', (select count(*) from public.stores where archived_at is null and not public.store_accessible(id)),
    'plans', (select count(*) from public.plans),
    'subscriptions', (select count(*) from public.store_subscriptions),
    'users', (select count(*) from public.store_users),
    'products', (select count(*) from public.products),
    'orders', (select count(*) from public.orders),
    'deliveryZones', (select count(*) from public.delivery_zones),
    'domains', (select count(*) from public.store_domains),
    'demoTrials', (
      select count(*) from public.store_subscriptions ss
      join public.plans p on p.id=ss.plan_id
      where p.code='DEMO' and ss.status='trial'
    ),
    'demoTrialsExpiringSoon', (
      select count(*) from public.store_subscriptions ss
      join public.plans p on p.id=ss.plan_id
      where p.code='DEMO' and ss.status='trial' and ss.expires_at is not null
        and ss.expires_at > now()
        and ss.expires_at <= now() + make_interval(days => v_warning)
    ),
    'demoDurationDays', v_duration,
    'demoWarningDays', v_warning,
    'demoCronScheduled', v_cron_scheduled
  ) into result;

  return result;
end;
$$;
revoke all on function public.platform_system_check() from public;
grant execute on function public.platform_system_check() to authenticated;

comment on column public.store_users.must_change_password is 'Quando true, o responsável criado com senha temporária deve trocar a senha no primeiro acesso.';
comment on table public.platform_settings is 'Configurações globais do SaaS FloriWeb administradas pelo Admin Master.';
