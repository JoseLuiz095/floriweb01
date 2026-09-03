-- FloriWeb V3 RC6.1 - validacao pos-migration

select
  to_regclass('public.subscription_payments') as subscription_payments,
  to_regclass('public.financial_entries') as financial_entries,
  to_regclass('public.financial_documents') as financial_documents;

select
  billing_pix_key_type,
  billing_pix_holder_name,
  billing_whatsapp,
  billing_proof_required,
  billing_grace_days
from public.platform_settings
where id=1;

select proname
from pg_proc
where proname in (
  'get_public_landing_v1',
  'get_store_billing_overview_v1',
  'create_manual_subscription_charge_v1',
  'mark_subscription_proof_sent_v1',
  'platform_get_billing_dashboard_v1',
  'platform_update_billing_settings_v1',
  'platform_confirm_subscription_payment_v1',
  'get_store_financial_overview_v1',
  'create_financial_entry_v1'
)
order by 1;

select id,name,public,file_size_limit
from storage.buckets
where id='flori-finance-documents';

-- Deve retornar JSON com demo_store_slug, stores e plans sem erro de coluna.
select public.get_public_landing_v1() as public_landing;

-- Confirma a coluna real utilizada pela landing.
select exists (
  select 1
  from information_schema.columns
  where table_schema='public'
    and table_name='stores'
    and column_name='cover_url'
) as stores_cover_url_ok;
