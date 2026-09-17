-- FloriWeb V3 RC6.3 - validacao de contato protegido e suporte interno
select 'platform_public_contact_rate_limits' as item,
       to_regclass('public.platform_public_contact_rate_limits') is not null as ok;

select 'get_admin_support_contact_v1' as item,
       to_regprocedure('public.get_admin_support_contact_v1()') is not null as ok
union all
select 'enforce_public_contact_rate_limit_v1',
       to_regprocedure('public.enforce_public_contact_rate_limit_v1(text)') is not null;

select public.get_public_landing_v1() as public_landing;

select
  (public.get_public_landing_v1()->>'contact_protected')::boolean is true as contact_protected,
  not (public.get_public_landing_v1() ? 'marketing_whatsapp') as no_marketing_phone,
  not (public.get_public_landing_v1() ? 'support_whatsapp') as no_support_phone,
  not (public.get_public_landing_v1() ? 'billing_whatsapp') as no_billing_phone,
  not (public.get_public_landing_v1() ? 'billing_pix_key') as no_pix_key;
