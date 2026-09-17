-- FloriWeb V3 RC6.2 - validação pós-migration

select
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='platform_settings' and column_name='marketing_whatsapp') as marketing_whatsapp_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='platform_settings' and column_name='support_whatsapp') as support_whatsapp_ok,
  to_regprocedure('public.get_public_landing_v1()') is not null as public_landing_ok,
  to_regprocedure('public.platform_update_billing_settings_v2(text,text,text,text,text,text,text,text,boolean,integer)') is not null as billing_settings_v2_ok;

select
  code,
  name,
  monthly_price,
  product_limit,
  image_limit_per_product,
  reports,
  custom_domain
from public.plans
where code in ('DEMO','PRO')
order by code;

-- O retorno público pode conter WhatsApp comercial/suporte, lojas e planos,
-- mas não deve conter chave PIX nem WhatsApp financeiro.
select public.get_public_landing_v1();

select
  public.get_public_landing_v1() ? 'marketing_whatsapp' as landing_marketing_whatsapp_ok,
  public.get_public_landing_v1() ? 'support_whatsapp' as landing_support_whatsapp_ok,
  not (public.get_public_landing_v1() ? 'billing_pix_key') as landing_sem_pix_key,
  not (public.get_public_landing_v1() ? 'billing_whatsapp') as landing_sem_finance_whatsapp;
