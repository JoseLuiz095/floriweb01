-- FloriWeb V3 RC6.1 - preflight somente leitura
-- Execute antes da migration se quiser confirmar os pre-requisitos.

select
  to_regclass('public.stores') as stores,
  to_regclass('public.store_subscriptions') as store_subscriptions,
  to_regclass('public.plans') as plans,
  to_regclass('public.platform_settings') as platform_settings,
  to_regprocedure('public.store_accessible(uuid)') as store_accessible,
  to_regprocedure('public.is_store_admin(uuid)') as is_store_admin,
  to_regprocedure('public.is_platform_admin()') as is_platform_admin;

select column_name
from information_schema.columns
where table_schema='public'
  and table_name='stores'
  and column_name in ('id','slug','name','description','logo_url','cover_url','city','state','active','access_status','created_at','archived_at')
order by column_name;

select column_name
from information_schema.columns
where table_schema='public'
  and table_name='store_subscriptions'
  and column_name in ('id','store_id','plan_id','status','started_at','expires_at','billing_amount','due_day','next_due_date','notes')
order by column_name;
