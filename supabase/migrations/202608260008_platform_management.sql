-- FloriWeb V2.7.0
-- Gestão central da plataforma, suspensão de lojas, planos comerciais e domínios.

alter table public.stores
  add column if not exists access_status text not null default 'online',
  add column if not exists owner_name text,
  add column if not exists owner_email text;

alter table public.stores drop constraint if exists stores_access_status_check;
alter table public.stores add constraint stores_access_status_check check (access_status in ('online','suspended'));

alter table public.plans
  add column if not exists monthly_price numeric(12,2) not null default 0,
  add column if not exists setup_price numeric(12,2) not null default 0,
  add column if not exists category_limit integer,
  add column if not exists addon_limit integer,
  add column if not exists admin_user_limit integer,
  add column if not exists sort_order integer not null default 0;

alter table public.plans drop constraint if exists plans_monthly_price_ck;
alter table public.plans add constraint plans_monthly_price_ck check (monthly_price >= 0 and setup_price >= 0);

alter table public.store_subscriptions
  add column if not exists billing_amount numeric(12,2),
  add column if not exists due_day integer,
  add column if not exists next_due_date date,
  add column if not exists notes text;

alter table public.store_subscriptions drop constraint if exists store_subscriptions_due_day_ck;
alter table public.store_subscriptions add constraint store_subscriptions_due_day_ck check (due_day is null or due_day between 1 and 28);

update public.plans set name='Demo', monthly_price=0, setup_price=0, category_limit=5, addon_limit=10, admin_user_limit=1, sort_order=0 where code='DEMO';
update public.plans set name='Essencial', monthly_price=49.90, setup_price=149, category_limit=5, addon_limit=10, admin_user_limit=1, sort_order=10 where code='BASIC';
update public.plans set name='Profissional', monthly_price=89.90, setup_price=249, category_limit=15, addon_limit=40, admin_user_limit=3, sort_order=20 where code='PRO';
update public.plans set name='Premium', monthly_price=149.90, setup_price=399, category_limit=null, addon_limit=null, admin_user_limit=5, sort_order=30 where code='PREMIUM';

update public.store_subscriptions ss
set billing_amount = p.monthly_price,
    due_day = coalesce(ss.due_day, 10)
from public.plans p
where p.id=ss.plan_id and ss.billing_amount is null;

create table if not exists public.platform_admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_domains (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  domain text not null unique,
  is_primary boolean not null default true,
  active boolean not null default true,
  verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists store_domains_one_primary_idx on public.store_domains(store_id) where is_primary and active;
create index if not exists store_domains_domain_idx on public.store_domains(domain,active);

-- Slugs na raiz não podem colidir com rotas internas.
alter table public.stores drop constraint if exists stores_slug_reserved_ck;
alter table public.stores add constraint stores_slug_reserved_ck check (
  lower(slug) not in ('admin','admin-master','produto','carrinho','finalizar','pedido','404')
);

-- updated_at para tabelas novas
DO $$
begin
  drop trigger if exists platform_admins_set_updated_at on public.platform_admins;
  create trigger platform_admins_set_updated_at before update on public.platform_admins for each row execute function public.set_updated_at();
  drop trigger if exists store_domains_set_updated_at on public.store_domains;
  create trigger store_domains_set_updated_at before update on public.store_domains for each row execute function public.set_updated_at();
end $$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.platform_admins pa
    where pa.user_id=auth.uid() and pa.active
  );
$$;

revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

-- A assinatura suspensa bloqueia o painel da loja, mas o Admin Master continua com acesso.
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
      and s.active
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
      and s.active
      and s.access_status='online'
  );
$$;

-- Dados iniciais de uma nova loja. Usado pela Edge Function de onboarding.
create or replace function public.platform_seed_new_store(p_store_id uuid, p_city text, p_state text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.categories(store_id,name,slug,active,sort_order) values
    (p_store_id,'Buquês','buques',true,10),
    (p_store_id,'Rosas','rosas',true,20),
    (p_store_id,'Flores variadas','flores-variadas',true,30),
    (p_store_id,'Presentes','presentes',true,40),
    (p_store_id,'Casamentos','casamentos',true,50)
  on conflict(store_id,slug) do nothing;

  if lower(trim(p_city))='linhares' and upper(trim(p_state))='ES' then
    insert into public.delivery_zones(store_id,name,aliases,city,state,fee,active,sort_order)
    select p_store_id, x.name, '{}'::text[], 'Linhares','ES',0,false,x.ord*10
    from unnest(array[
      'Alphaville','Araçá','Aviso','Bebedouro','Betânia','Boa Vista','Canivete','Centro','Colina','Conceição','Farias','Gaivotas','Interlagos','Jardim Laguna','Jocafe','José Rodrigues Maciel','Juparanã','Lagoa do Meio','Linhares V','Movelar','Nova Esperança','Novo Horizonte','Olaria','Palmital','Planalto','Residencial Rio Doce','Rio Quartel','Santa Cruz','Shell','Três Barras','Vila Isabel'
    ]) with ordinality as x(name,ord)
    where not exists (
      select 1 from public.delivery_zones dz where dz.store_id=p_store_id and lower(dz.name)=lower(x.name)
    );
  end if;
end;
$$;
revoke all on function public.platform_seed_new_store(uuid,text,text) from public;
grant execute on function public.platform_seed_new_store(uuid,text,text) to service_role;

-- Limites adicionais dos planos. Assim como produtos, contam apenas registros ativos.
create or replace function public.enforce_category_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit integer;
  v_count integer;
begin
  if not new.active then return new; end if;
  if tg_op='INSERT' and exists(select 1 from public.categories where id=new.id) then return new; end if;
  if tg_op='UPDATE' and old.active then return new; end if;

  perform pg_advisory_xact_lock(hashtextextended('category:' || new.store_id::text, 0));
  select p.category_limit into v_limit
  from public.store_subscriptions ss
  join public.plans p on p.id=ss.plan_id
  where ss.store_id=new.store_id and ss.status in ('trial','active')
    and (ss.expires_at is null or ss.expires_at >= now())
  order by ss.started_at desc limit 1;
  if not found then select category_limit into v_limit from public.plans where code='DEMO' and active limit 1; end if;
  if v_limit is null then return new; end if;

  select count(*) into v_count from public.categories where store_id=new.store_id and active and id<>new.id;
  if v_count >= v_limit then
    raise exception 'Limite de categorias ativas do plano atingido (%). Desative uma categoria ou altere o plano.', v_limit using errcode='P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists categories_plan_limit_trg on public.categories;
create trigger categories_plan_limit_trg before insert or update of active on public.categories
for each row execute function public.enforce_category_plan_limit();

create or replace function public.enforce_addon_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit integer;
  v_count integer;
begin
  if not new.active then return new; end if;
  if tg_op='INSERT' and exists(select 1 from public.addons where id=new.id) then return new; end if;
  if tg_op='UPDATE' and old.active then return new; end if;

  perform pg_advisory_xact_lock(hashtextextended('addon:' || new.store_id::text, 0));
  select p.addon_limit into v_limit
  from public.store_subscriptions ss
  join public.plans p on p.id=ss.plan_id
  where ss.store_id=new.store_id and ss.status in ('trial','active')
    and (ss.expires_at is null or ss.expires_at >= now())
  order by ss.started_at desc limit 1;
  if not found then select addon_limit into v_limit from public.plans where code='DEMO' and active limit 1; end if;
  if v_limit is null then return new; end if;

  select count(*) into v_count from public.addons where store_id=new.store_id and active and id<>new.id;
  if v_count >= v_limit then
    raise exception 'Limite de adicionais ativos do plano atingido (%). Desative um adicional ou altere o plano.', v_limit using errcode='P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists addons_plan_limit_trg on public.addons;
create trigger addons_plan_limit_trg before insert or update of active on public.addons
for each row execute function public.enforce_addon_plan_limit();

create or replace function public.enforce_store_user_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_limit integer;
  v_count integer;
begin
  if not new.active then return new; end if;
  if tg_op='INSERT' and exists(select 1 from public.store_users where id=new.id) then return new; end if;
  if tg_op='UPDATE' and old.active then return new; end if;

  perform pg_advisory_xact_lock(hashtextextended('store-user:' || new.store_id::text, 0));
  select p.admin_user_limit into v_limit
  from public.store_subscriptions ss
  join public.plans p on p.id=ss.plan_id
  where ss.store_id=new.store_id and ss.status in ('trial','active')
    and (ss.expires_at is null or ss.expires_at >= now())
  order by ss.started_at desc limit 1;
  if not found then select admin_user_limit into v_limit from public.plans where code='DEMO' and active limit 1; end if;
  if v_limit is null then return new; end if;

  select count(*) into v_count from public.store_users where store_id=new.store_id and active and id<>new.id;
  if v_count >= v_limit then
    raise exception 'Limite de usuários administrativos ativos do plano atingido (%). Desative um usuário ou altere o plano.', v_limit using errcode='P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists store_users_plan_limit_trg on public.store_users;
create trigger store_users_plan_limit_trg before insert or update of active on public.store_users
for each row execute function public.enforce_store_user_plan_limit();

-- RLS de gestão central.
alter table public.platform_admins enable row level security;
alter table public.store_domains enable row level security;

drop policy if exists platform_admins_self_read on public.platform_admins;
drop policy if exists platform_admins_master_all on public.platform_admins;
create policy platform_admins_self_read on public.platform_admins for select to authenticated using (user_id=auth.uid());
create policy platform_admins_master_all on public.platform_admins for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists store_domains_public_read on public.store_domains;
drop policy if exists store_domains_platform_all on public.store_domains;
create policy store_domains_public_read on public.store_domains for select to anon,authenticated using (
  active and exists(select 1 from public.stores s where s.id=store_id and s.active and s.access_status='online')
);
create policy store_domains_platform_all on public.store_domains for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Recria leitura pública das lojas considerando suspensão.
drop policy if exists stores_public_read on public.stores;
create policy stores_public_read on public.stores for select to anon,authenticated using (active and access_status='online');
drop policy if exists stores_platform_all on public.stores;
create policy stores_platform_all on public.stores for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- O Admin Master precisa de leitura agregada para a gestão.
drop policy if exists store_users_platform_read on public.store_users;
create policy store_users_platform_read on public.store_users for select to authenticated using (public.is_platform_admin());

drop policy if exists products_platform_read on public.products;
create policy products_platform_read on public.products for select to authenticated using (public.is_platform_admin());

drop policy if exists orders_platform_read on public.orders;
create policy orders_platform_read on public.orders for select to authenticated using (public.is_platform_admin());

drop policy if exists plans_platform_all on public.plans;
create policy plans_platform_all on public.plans for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists subscriptions_platform_all on public.store_subscriptions;
create policy subscriptions_platform_all on public.store_subscriptions for all to authenticated using (public.is_platform_admin()) with check (public.is_platform_admin());

-- Policies públicas que dependem da loja agora respeitam o status de acesso.
drop policy if exists categories_public_read on public.categories;
create policy categories_public_read on public.categories for select to anon,authenticated using (
  active and exists(select 1 from public.stores s where s.id=store_id and s.active and s.access_status='online')
);

drop policy if exists products_public_read on public.products;
create policy products_public_read on public.products for select to anon,authenticated using (
  active
  and exists(select 1 from public.stores s where s.id=store_id and s.active and s.access_status='online')
  and exists(select 1 from public.categories c where c.id=category_id and c.store_id=store_id and c.active)
);

drop policy if exists addons_public_read on public.addons;
create policy addons_public_read on public.addons for select to anon,authenticated using (
  active and exists(select 1 from public.stores s where s.id=store_id and s.active and s.access_status='online')
);

drop policy if exists delivery_zones_public_read on public.delivery_zones;
create policy delivery_zones_public_read on public.delivery_zones for select to anon,authenticated using (
  active and exists(select 1 from public.stores s where s.id=store_id and s.active and s.access_status='online')
);

-- Suspensão operacional: além de access_status, active é desligado pelo Admin Master.
-- Isso mantém compatibilidade com RPCs anteriores que já validavam stores.active.
