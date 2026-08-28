-- FloriWeb V3 RC1 - validacao somente leitura
-- Execute depois do bundle 20260827_v3_rc1_bundle.sql.

with checks as (
  select
    to_regprocedure('public.get_public_storefront_v3(text,text)') is not null as storefront_rpc,
    to_regprocedure('public.create_public_order(jsonb)') is not null as checkout_rpc,
    to_regprocedure('public.enforce_public_order_rate_limit(uuid)') is not null as rate_limit_fn,
    to_regprocedure('public.is_platform_admin()') is not null as platform_admin_fn,
    to_regprocedure('private.store_plan_allows_custom_domain(uuid)') is not null as domain_entitlement_fn,
    exists (select 1 from pg_trigger where tgname='store_domains_plan_entitlement_trg' and not tgisinternal) as domain_entitlement_trigger,
    coalesce(position('aal2' in pg_get_functiondef(to_regprocedure('public.is_platform_admin()'))) > 0, false) as master_requires_aal2,
    coalesce(position('store_accessible' in pg_get_functiondef(to_regprocedure('public.create_public_order(jsonb)'))) > 0, false) as checkout_checks_store_access,
    coalesce(position('enforce_public_order_rate_limit' in pg_get_functiondef(to_regprocedure('public.create_public_order(jsonb)'))) > 0, false) as checkout_calls_rate_limit,
    coalesce(position('v_seen_addon_ids' in pg_get_functiondef(to_regprocedure('public.create_public_order(jsonb)'))) > 0, false) as checkout_blocks_duplicate_addons,
    coalesce((
      select position('products.store_id' in coalesce(qual,'')) > 0
      from pg_policies
      where schemaname='public' and tablename='products' and policyname='products_public_read'
      limit 1
    ), false) as products_policy_store_isolation,
    coalesce((
      select position('store_accessible' in coalesce(qual,'')) > 0
      from pg_policies
      where schemaname='storage' and tablename='objects' and policyname='floriweb_storage_public_read'
      limit 1
    ), false) as storage_public_respects_store_access,
    coalesce((
      select position('is_store_admin' in coalesce(with_check,'')) > 0
      from pg_policies
      where schemaname='storage' and tablename='objects' and policyname='floriweb_storage_member_insert'
      limit 1
    ), false) as storage_write_respects_admin_access
)
select jsonb_pretty(jsonb_build_object(
  'version','3.0.0-rc.1',
  'ok', storefront_rpc
        and checkout_rpc
        and rate_limit_fn
        and platform_admin_fn
        and domain_entitlement_fn
        and domain_entitlement_trigger
        and master_requires_aal2
        and checkout_checks_store_access
        and checkout_calls_rate_limit
        and checkout_blocks_duplicate_addons
        and products_policy_store_isolation
        and storage_public_respects_store_access
        and storage_write_respects_admin_access,
  'checks', to_jsonb(checks)
)) as floriweb_v3_rc1_validation
from checks;
