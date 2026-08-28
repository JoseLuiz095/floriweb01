-- FloriWeb V2.9.0 - validações somente leitura.

select 'platform_settings' as item,
       to_regclass('public.platform_settings')::text as valor;

select id, demo_duration_days, demo_warning_days
from public.platform_settings
where id=1;

select 'store_users.must_change_password' as item,
       exists(
         select 1 from information_schema.columns
         where table_schema='public'
           and table_name='store_users'
           and column_name='must_change_password'
       ) as ok;

select
  to_regprocedure('public.store_accessible(uuid)')::text as store_accessible,
  to_regprocedure('public.resolve_storefront_status(text,text)')::text as resolve_storefront_status,
  to_regprocedure('public.platform_expire_demo_trials()')::text as platform_expire_demo_trials,
  to_regprocedure('public.platform_system_check()')::text as platform_system_check;

select p.code, p.name, count(ss.id) as assinaturas,
       count(*) filter (where ss.status='trial') as em_trial,
       min(ss.expires_at) filter (where ss.status='trial') as proximo_vencimento
from public.plans p
left join public.store_subscriptions ss on ss.plan_id=p.id
where p.code in ('DEMO','BASIC','PRO','PREMIUM')
group by p.code,p.name
order by p.code;

select s.name, s.slug, s.access_status, s.active,
       p.code as plano, ss.status, ss.expires_at,
       public.store_accessible(s.id) as acesso_operacional
from public.stores s
left join lateral (
  select ss.* from public.store_subscriptions ss
  where ss.store_id=s.id
  order by ss.started_at desc
  limit 1
) ss on true
left join public.plans p on p.id=ss.plan_id
where s.archived_at is null
order by s.name;
