begin;

-- FloriWeb V3 RC6.13
-- Precos introdutorios de teste para o nicho + Demo futuro de 14 dias.

do $$
begin
  if to_regclass('public.plans') is null
     or to_regclass('public.store_subscriptions') is null
     or to_regclass('public.platform_settings') is null then
    raise exception 'FloriWeb RC6.13 requer plans, store_subscriptions e platform_settings.';
  end if;
end $$;

update public.plans
set monthly_price = case code
  when 'BASIC' then 39.90
  when 'PRO' then 69.90
  when 'PREMIUM' then 119.90
  else monthly_price
end,
updated_at=now()
where code in ('BASIC','PRO','PREMIUM');

update public.store_subscriptions ss
set billing_amount = case p.code
  when 'BASIC' then 39.90
  when 'PRO' then 69.90
  when 'PREMIUM' then 119.90
  else ss.billing_amount
end
from public.plans p
where p.id=ss.plan_id
  and p.code in ('BASIC','PRO','PREMIUM')
  and (
    ss.billing_amount is null
    or (p.code='BASIC' and ss.billing_amount=49.90)
    or (p.code='PRO' and ss.billing_amount=89.90)
    or (p.code='PREMIUM' and ss.billing_amount=149.90)
  );

update public.platform_settings
set demo_duration_days=14,
    updated_at=now()
where id=1;

commit;
