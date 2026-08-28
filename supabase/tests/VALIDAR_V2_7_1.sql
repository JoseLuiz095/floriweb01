-- FloriWeb V2.7.1 - validação estrutural segura (somente leitura)
-- Execute no SQL Editor depois da migration 202608260009.

select 'stores' as objeto, to_regclass('public.stores') is not null as ok
union all select 'platform_admins', to_regclass('public.platform_admins') is not null
union all select 'store_domains', to_regclass('public.store_domains') is not null
union all select 'delivery_zones', to_regclass('public.delivery_zones') is not null
union all select 'orders', to_regclass('public.orders') is not null;

select
  exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='is_platform_admin') as is_platform_admin_ok,
  exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='platform_system_check') as platform_system_check_ok,
  exists(select 1 from pg_proc where pronamespace='public'::regnamespace and proname='enforce_order_store_access') as order_guard_ok;

select
  exists(select 1 from pg_trigger where tgname='orders_store_access_trg' and not tgisinternal) as orders_store_access_trigger_ok,
  exists(select 1 from pg_trigger where tgname='store_users_plan_limit_trg' and not tgisinternal) as user_limit_trigger_ok,
  exists(select 1 from pg_trigger where tgname='categories_plan_limit_trg' and not tgisinternal) as category_limit_trigger_ok,
  exists(select 1 from pg_trigger where tgname='addons_plan_limit_trg' and not tgisinternal) as addon_limit_trigger_ok;

select
  count(*) filter (where archived_at is null) as lojas_preservadas,
  count(*) filter (where archived_at is null and access_status='online') as lojas_online,
  count(*) filter (where archived_at is null and access_status='suspended') as lojas_suspensas
from public.stores;

select
  s.id,
  s.name,
  s.slug,
  s.active,
  s.access_status,
  s.suspended_at,
  s.suspension_reason,
  count(su.id) as usuarios_vinculados,
  count(su.id) filter (where su.active) as usuarios_ativos_no_cadastro,
  count(o.id) as pedidos_preservados
from public.stores s
left join public.store_users su on su.store_id=s.id
left join public.orders o on o.store_id=s.id
where s.archived_at is null
group by s.id,s.name,s.slug,s.active,s.access_status,s.suspended_at,s.suspension_reason
order by s.name;

select
  ss.store_id,
  s.name,
  ss.status,
  ss.status_before_suspension,
  ss.billing_amount,
  ss.due_day,
  ss.next_due_date
from public.store_subscriptions ss
join public.stores s on s.id=ss.store_id
order by ss.started_at desc;

select
  code,
  name,
  product_limit,
  category_limit,
  addon_limit,
  admin_user_limit,
  monthly_price,
  active
from public.plans
order by sort_order, name;

-- Seu usuário precisa aparecer aqui para acessar /admin-master.
select pa.user_id, u.email, pa.name, pa.active
from public.platform_admins pa
join auth.users u on u.id=pa.user_id
order by pa.created_at;
