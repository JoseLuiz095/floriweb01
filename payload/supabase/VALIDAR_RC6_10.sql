-- FloriWeb RC6.10 - validacao de planos
select code,
       name,
       monthly_price,
       custom_domain,
       admin_user_limit,
       active
from public.plans
where code in ('DEMO','BASIC','PRO','PREMIUM')
order by sort_order, name;

-- Deve retornar zero linhas: nenhum plano padrao deve anunciar mais de um admin.
select code,name,admin_user_limit
from public.plans
where code in ('DEMO','BASIC','PRO','PREMIUM')
  and coalesce(admin_user_limit,1) <> 1;

-- Deve retornar true.
select exists(
  select 1 from public.plans where code='PREMIUM' and custom_domain=true
) as premium_com_dominio_proprio;
