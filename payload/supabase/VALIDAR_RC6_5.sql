-- FloriWeb V3 RC6.5 - validacao somente leitura
-- Execute depois da migration 202609032030_floriweb_rc6_5_billing_access.sql.

select
  to_regprocedure('public.subscription_reference_due_v1(integer,date)') as regra_vencimento,
  to_regprocedure('public.get_store_billing_overview_v1(uuid)') as overview_loja,
  to_regprocedure('public.platform_get_billing_dashboard_v1()') as dashboard_master,
  to_regprocedure('public.platform_reject_subscription_payment_v1(uuid,text)') as negar_pagamento,
  to_regprocedure('public.platform_confirm_subscription_payment_v1(uuid)') as confirmar_pagamento;

select column_name,data_type
from information_schema.columns
where table_schema='public'
  and table_name='subscription_payments'
  and column_name in('rejected_at','rejection_reason','reviewed_by')
order by column_name;

select
  s.name as loja,
  p.name as plano,
  ss.status,
  ss.billing_amount,
  ss.due_day,
  ss.next_due_date,
  case
    when p.code='DEMO' or ss.status='trial' then 'demo'
    when ss.next_due_date<current_date then 'atrasado'
    else 'em_dia'
  end as situacao_mensalidade,
  extract(day from ss.next_due_date)::integer as dia_real_do_proximo_vencimento,
  (extract(day from ss.next_due_date)::integer=ss.due_day) as respeita_dia_configurado
from public.store_subscriptions ss
join public.stores s on s.id=ss.store_id
join public.plans p on p.id=ss.plan_id
where ss.status<>'cancelled'
order by s.name;

select
  sp.id,
  s.name as loja,
  sp.status,
  sp.due_date as referencia_vencimento,
  sp.paid_at,
  sp.rejected_at,
  sp.rejection_reason
from public.subscription_payments sp
join public.stores s on s.id=sp.store_id
order by sp.created_at desc
limit 20;
