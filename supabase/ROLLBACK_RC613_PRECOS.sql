begin;
update public.plans
set monthly_price = case code
  when 'BASIC' then 49.90
  when 'PRO' then 89.90
  when 'PREMIUM' then 149.90
  else monthly_price
end,
updated_at=now()
where code in ('BASIC','PRO','PREMIUM');
update public.platform_settings set demo_duration_days=30,updated_at=now() where id=1;
commit;
