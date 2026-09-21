select
  (select monthly_price=39.90 from public.plans where code='BASIC') as essencial_39_90,
  (select monthly_price=69.90 from public.plans where code='PRO') as profissional_69_90,
  (select monthly_price=119.90 from public.plans where code='PREMIUM') as premium_119_90,
  (select demo_duration_days=14 from public.platform_settings where id=1) as demo_14_dias,
  to_regclass('public.flori_self_service_signup_requests') is not null as self_service_preservado,
  to_regclass('public.flori_trial_claims') is not null as elegibilidade_demo_preservada;
