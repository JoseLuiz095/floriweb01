-- FloriWeb V3 RC2 - validacao somente leitura
-- Execute depois do bundle 20260827_v3_rc2_bundle.sql.

with checks as (
  select
    to_regclass('public.analytics_events') is not null as analytics_table,
    to_regprocedure('public.track_public_event_v3(uuid,uuid,text,uuid)') is not null as analytics_track_rpc,
    to_regprocedure('public.get_store_analytics_v3(uuid,timestamptz,timestamptz)') is not null as analytics_report_rpc,
    to_regprocedure('public.create_public_order(jsonb)') is not null as checkout_rpc,
    to_regprocedure('public.enforce_public_order_rate_limit(uuid)') is not null as rate_limit_rpc,
    exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='public' and c.relname='analytics_events' and c.relrowsecurity
    ) as analytics_rls,
    has_function_privilege('anon','public.track_public_event_v3(uuid,uuid,text,uuid)','EXECUTE') as anon_can_track_analytics,
    not has_function_privilege('anon','public.create_public_order(jsonb)','EXECUTE') as anon_cannot_bypass_checkout,
    not has_function_privilege('authenticated','public.create_public_order(jsonb)','EXECUTE') as authenticated_cannot_bypass_checkout,
    has_function_privilege('service_role','public.create_public_order(jsonb)','EXECUTE') as service_role_can_create_order,
    exists (
      select 1 from pg_trigger
      where tgname='orders_whatsapp_analytics_v3_trg' and not tgisinternal
    ) as whatsapp_analytics_trigger,
    exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name='orders' and column_name='public_request_id'
    ) as checkout_idempotency_column,
    exists (
      select 1 from pg_trigger
      where tgname='orders_public_request_id_trg' and not tgisinternal
    ) as checkout_idempotency_trigger,
    exists (
      select 1 from pg_indexes
      where schemaname='public' and indexname='orders_store_public_request_uidx'
    ) as checkout_idempotency_unique,
    coalesce(position('x-floriweb-security-fingerprint' in pg_get_functiondef(to_regprocedure('public.enforce_public_order_rate_limit(uuid)'))) > 0,false) as explicit_checkout_fingerprint,
    coalesce(position('aal2' in pg_get_functiondef(to_regprocedure('public.is_platform_admin()'))) > 0,false) as master_still_requires_aal2,
    coalesce((
      select position('products.store_id' in coalesce(qual,'')) > 0
      from pg_policies
      where schemaname='public' and tablename='products' and policyname='products_public_read'
      limit 1
    ),false) as products_store_isolation,
    coalesce(position('3.0.0-rc.2' in pg_get_functiondef(to_regprocedure('public.platform_system_check()'))) > 0,false) as system_check_rc2
)
select jsonb_pretty(jsonb_build_object(
  'version','3.0.0-rc.2',
  'ok', analytics_table
        and analytics_track_rpc
        and analytics_report_rpc
        and checkout_rpc
        and rate_limit_rpc
        and analytics_rls
        and anon_can_track_analytics
        and anon_cannot_bypass_checkout
        and authenticated_cannot_bypass_checkout
        and service_role_can_create_order
        and whatsapp_analytics_trigger
        and checkout_idempotency_column
        and checkout_idempotency_trigger
        and checkout_idempotency_unique
        and explicit_checkout_fingerprint
        and master_still_requires_aal2
        and products_store_isolation
        and system_check_rc2,
  'checks',to_jsonb(checks)
)) as floriweb_v3_rc2_validation
from checks;
