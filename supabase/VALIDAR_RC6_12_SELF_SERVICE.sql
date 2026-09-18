select
  to_regclass('public.flori_self_service_signup_requests') is not null as solicitacoes_ok,
  to_regclass('public.flori_trial_claims') is not null as demo_claim_ok,
  exists(select 1 from information_schema.columns where table_schema='public' and table_name='stores' and column_name='approval_status') as approval_status_ok,
  to_regprocedure('public.complete_self_service_signup_v1(text,text,text,text,text)') is not null as concluir_cadastro_ok,
  to_regprocedure('public.platform_list_self_service_signups_v1()') is not null as listar_master_ok,
  to_regprocedure('public.platform_approve_self_service_signup_v1(uuid)') is not null as aprovar_master_ok,
  to_regprocedure('public.platform_reject_self_service_signup_v1(uuid,text)') is not null as rejeitar_master_ok;
