-- FloriWeb V3 RC6.12 - Auto cadastro, escolha de plano e aprovacao do Admin Master
-- O cadastro autenticado pode preparar a floricultura, mas a vitrine permanece bloqueada ate a aprovacao.

begin;

create extension if not exists pgcrypto;

do $$
begin
  if to_regclass('public.stores') is null
     or to_regclass('public.store_users') is null
     or to_regclass('public.store_subscriptions') is null
     or to_regclass('public.plans') is null
     or to_regclass('public.platform_settings') is null then
    raise exception 'FloriWeb RC6.12 requer as migrations anteriores do FloriWeb.';
  end if;
  if to_regprocedure('public.is_platform_admin()') is null
     or to_regprocedure('public.store_accessible(uuid)') is null
     or to_regprocedure('public.platform_seed_new_store(uuid,text,text)') is null
     or to_regprocedure('public.subscription_reference_due_v1(integer,date)') is null then
    raise exception 'FloriWeb RC6.12 requer as funcoes de plataforma, acesso e seed das versoes anteriores.';
  end if;
  if exists(select 1 from public.stores where lower(slug)='cadastro' and archived_at is null) then
    raise exception 'Existe uma floricultura usando o slug reservado cadastro. Altere esse slug antes de aplicar a RC6.12.';
  end if;
end $$;

alter table public.stores
  add column if not exists approval_status text not null default 'approved',
  add column if not exists self_service boolean not null default false;

alter table public.stores drop constraint if exists stores_approval_status_ck;
alter table public.stores add constraint stores_approval_status_ck
  check (approval_status in ('pending','approved','rejected'));

-- /cadastro passa a ser rota publica da plataforma.
alter table public.stores drop constraint if exists stores_slug_reserved_ck;
alter table public.stores add constraint stores_slug_reserved_ck check (
  lower(slug) not in ('admin','admin-master','produto','carrinho','finalizar','pedido','404','cadastro')
);

create table if not exists public.flori_self_service_signup_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  store_id uuid not null unique references public.stores(id) on delete cascade,
  email text not null,
  owner_name text not null,
  requested_plan_id uuid not null references public.plans(id),
  requested_plan_code text not null,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  trial_granted boolean not null default false,
  trial_expires_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists self_service_signup_status_idx
  on public.flori_self_service_signup_requests(status,created_at desc);
create index if not exists self_service_signup_user_idx
  on public.flori_self_service_signup_requests(user_id,created_at desc);

-- O claim sobrevive a exclusao do usuario/loja para impedir repeticao do Demo pelo mesmo e-mail.
create table if not exists public.flori_trial_claims (
  email_normalized text primary key,
  user_id uuid references auth.users(id) on delete set null,
  store_id uuid references public.stores(id) on delete set null,
  claimed_at timestamptz not null default now()
);

alter table public.flori_self_service_signup_requests enable row level security;
alter table public.flori_trial_claims enable row level security;


-- Regra comercial: Demo so existe para o primeiro cadastro daquele e-mail no FloriWeb.
-- Backfill impede que clientes ja existentes ganhem Demo apagando/recriando conta.
insert into public.flori_trial_claims(email_normalized,user_id,store_id)
select lower(trim(s.owner_email)),
       (select su.user_id from public.store_users su where su.store_id=s.id and su.active and su.role='owner' order by su.created_at asc limit 1),
       s.id
from public.stores s
where nullif(trim(coalesce(s.owner_email,'')),'') is not null
on conflict(email_normalized) do nothing;

drop policy if exists self_signup_owner_read on public.flori_self_service_signup_requests;
create policy self_signup_owner_read on public.flori_self_service_signup_requests
for select to authenticated
using (user_id=auth.uid() or public.is_platform_admin());

drop policy if exists self_signup_master_all on public.flori_self_service_signup_requests;
create policy self_signup_master_all on public.flori_self_service_signup_requests
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

revoke all on table public.flori_trial_claims from anon, authenticated;

create or replace function public.self_service_slug(p_name text)
returns text
language plpgsql
immutable
set search_path=public,pg_temp
as $$
declare v text;
begin
  v:=lower(coalesce(p_name,''));
  v:=translate(v,'áàâãäéèêëíìîïóòôõöúùûüçñýÿ','aaaaaeeeeiiiiooooouuuucnyy');
  v:=regexp_replace(v,'[^a-z0-9]+','-','g');
  v:=trim(both '-' from v);
  if v='' then v:='nova-floricultura'; end if;
  return left(v,45);
end;
$$;

-- Workspace de preparacao: usuario pendente pode editar a propria loja suspensa.
-- A vitrine publica continua passando por store_accessible(), portanto permanece bloqueada.
create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select exists(
    select 1
    from public.store_users su
    join public.stores s on s.id=su.store_id
    where su.store_id=p_store_id
      and su.user_id=auth.uid()
      and su.active
      and s.active
      and s.archived_at is null
      and (public.store_accessible(s.id) or s.approval_status='pending')
  );
$$;

create or replace function public.is_store_admin(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select exists(
    select 1
    from public.store_users su
    join public.stores s on s.id=su.store_id
    where su.store_id=p_store_id
      and su.user_id=auth.uid()
      and su.active
      and su.role in ('owner','admin')
      and s.active
      and s.archived_at is null
      and (public.store_accessible(s.id) or s.approval_status='pending')
  );
$$;
revoke all on function public.is_store_member(uuid) from public;
revoke all on function public.is_store_admin(uuid) from public;
grant execute on function public.is_store_member(uuid) to authenticated;
grant execute on function public.is_store_admin(uuid) to authenticated;

create or replace function public.complete_self_service_signup_v1(
  p_store_name text default null,
  p_owner_name text default null,
  p_plan_code text default null,
  p_city text default null,
  p_state text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth,pg_temp
as $$
declare
  v_user auth.users%rowtype;
  v_meta jsonb;
  v_store_name text;
  v_owner_name text;
  v_plan_code text;
  v_city text;
  v_state text;
  v_plan public.plans%rowtype;
  v_settings public.platform_settings%rowtype;
  v_existing_store uuid;
  v_store_id uuid;
  v_slug_base text;
  v_slug text;
  v_suffix integer:=1;
  v_trial boolean:=false;
  v_trial_expires timestamptz;
  v_request_id uuid;
  v_email text;
begin
  if auth.uid() is null then
    raise exception 'Autenticacao obrigatoria para concluir o cadastro.' using errcode='42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('flori-self-signup:' || auth.uid()::text,0));

  select * into v_user from auth.users where id=auth.uid();
  if v_user.id is null then raise exception 'Usuario autenticado nao encontrado.'; end if;
  v_email:=lower(trim(coalesce(v_user.email,'')));
  if v_email='' then raise exception 'E-mail do usuario nao encontrado.'; end if;

  -- Auto cadastro cria no maximo uma floricultura para o mesmo usuario.
  select su.store_id into v_existing_store
  from public.store_users su
  where su.user_id=auth.uid() and su.active
  order by su.created_at asc limit 1;
  if v_existing_store is not null then
    return jsonb_build_object(
      'ok',true,'existing',true,'storeId',v_existing_store,
      'requestStatus',coalesce((select r.status from public.flori_self_service_signup_requests r where r.store_id=v_existing_store limit 1),'approved')
    );
  end if;

  v_meta:=coalesce(v_user.raw_user_meta_data->'floriweb_signup','{}'::jsonb);
  v_store_name:=trim(coalesce(nullif(p_store_name,''),v_meta->>'store_name',''));
  v_owner_name:=trim(coalesce(nullif(p_owner_name,''),v_meta->>'owner_name',''));
  v_plan_code:=upper(trim(coalesce(nullif(p_plan_code,''),v_meta->>'plan_code','DEMO')));
  v_city:=trim(coalesce(p_city,v_meta->>'city',''));
  v_state:=upper(left(trim(coalesce(p_state,v_meta->>'state','')),2));

  if length(v_store_name)<2 or length(v_store_name)>120 then raise exception 'Informe o nome da floricultura.'; end if;
  if length(v_owner_name)<2 or length(v_owner_name)>120 then raise exception 'Informe o nome do responsavel.'; end if;
  if v_plan_code not in ('DEMO','BASIC','PRO','PREMIUM') then
    raise exception 'Plano indisponivel para auto cadastro.';
  end if;

  select * into v_plan from public.plans where upper(code)=v_plan_code and active limit 1;
  if v_plan.id is null then raise exception 'Plano selecionado nao esta disponivel.'; end if;

  select * into v_settings from public.platform_settings where id=1;
  if v_settings.id is null then raise exception 'Configuracao global do FloriWeb nao encontrada.'; end if;

  if exists(select 1 from public.stores s where lower(trim(coalesce(s.owner_email,'')))=v_email) then
    raise exception 'Este e-mail ja possui cadastro no FloriWeb. Entre com a conta existente ou solicite revisao ao Admin Master.';
  end if;

  v_trial:=upper(v_plan.code)='DEMO';
  if v_trial then
    if coalesce(v_settings.demo_enabled,true) is false then raise exception 'O plano Demo esta temporariamente indisponivel.'; end if;
    if exists(select 1 from public.flori_trial_claims c where c.email_normalized=v_email) then
      raise exception 'Este e-mail ja utilizou o periodo Demo do FloriWeb. Escolha um plano comercial para continuar.';
    end if;
    -- O claim e reservado agora, mas os 30 dias comecam apenas quando o Admin Master aprovar.
    v_trial_expires:=null;
  end if;

  v_slug_base:=public.self_service_slug(v_store_name);
  v_slug:=v_slug_base;
  while exists(select 1 from public.stores s where lower(s.slug)=lower(v_slug))
     or v_slug in ('admin','admin-master','produto','carrinho','finalizar','pedido','404','cadastro') loop
    v_suffix:=v_suffix+1;
    v_slug:=left(v_slug_base,38)||'-'||v_suffix::text;
  end loop;

  insert into public.stores(
    slug,name,city,state,owner_name,owner_email,active,access_status,approval_status,self_service,
    suspended_at,suspension_reason
  ) values(
    v_slug,v_store_name,nullif(v_city,''),nullif(v_state,''),v_owner_name,v_email,true,'suspended','pending',true,
    now(),'Aguardando aprovacao do Admin Master'
  ) returning id into v_store_id;

  insert into public.store_users(store_id,user_id,role,active,must_change_password)
  values(v_store_id,auth.uid(),'owner',true,false);

  -- Enquanto aguarda o Master, status trial mantem o plano escolhido disponivel no workspace.
  -- Para plano pago, trial_granted permanece false e a assinatura vira active apenas na aprovacao.
  insert into public.store_subscriptions(
    store_id,plan_id,status,status_before_suspension,expires_at,billing_amount,due_day,next_due_date,notes
  ) values(
    v_store_id,v_plan.id,'trial',null,case when v_trial then v_trial_expires else null end,
    case when v_trial then 0 else v_plan.monthly_price end,
    case when v_trial then null else 10 end,
    null,
    case when v_trial then 'Auto cadastro FloriWeb - Demo' else 'Auto cadastro FloriWeb - plano escolhido aguardando aprovacao' end
  );

  -- Qualquer primeiro cadastro reserva a elegibilidade do e-mail. Assim, quem entrou direto
  -- em plano pago tambem nao pode voltar depois para obter um Demo de primeiro acesso.
  insert into public.flori_trial_claims(email_normalized,user_id,store_id)
  values(v_email,auth.uid(),v_store_id)
  on conflict(email_normalized) do nothing;

  perform public.platform_seed_new_store(v_store_id,v_city,v_state);

  insert into public.flori_self_service_signup_requests(
    user_id,store_id,email,owner_name,requested_plan_id,requested_plan_code,status,trial_granted,trial_expires_at
  ) values(
    auth.uid(),v_store_id,v_email,v_owner_name,v_plan.id,v_plan.code,'pending',v_trial,v_trial_expires
  ) returning id into v_request_id;

  return jsonb_build_object(
    'ok',true,'existing',false,'requestId',v_request_id,'storeId',v_store_id,'slug',v_slug,
    'requestStatus','pending','trialGranted',v_trial,'trialExpiresAt',v_trial_expires,'workspaceLimited',true
  );
end;
$$;
revoke all on function public.complete_self_service_signup_v1(text,text,text,text,text) from public;
grant execute on function public.complete_self_service_signup_v1(text,text,text,text,text) to authenticated;

create or replace function public.platform_list_self_service_signups_v1()
returns table(
  id uuid,store_id uuid,store_name text,store_slug text,email text,owner_name text,
  requested_plan_id uuid,requested_plan_code text,requested_plan_name text,status text,
  trial_granted boolean,trial_expires_at timestamptz,approval_status text,access_status text,
  created_at timestamptz,reviewed_at timestamptz,rejection_reason text
)
language sql
stable
security definer
set search_path=public,pg_temp
as $$
  select r.id,r.store_id,s.name,s.slug,r.email,r.owner_name,r.requested_plan_id,r.requested_plan_code,p.name,
         r.status,r.trial_granted,r.trial_expires_at,s.approval_status,s.access_status,r.created_at,r.reviewed_at,r.rejection_reason
  from public.flori_self_service_signup_requests r
  join public.stores s on s.id=r.store_id
  join public.plans p on p.id=r.requested_plan_id
  where public.is_platform_admin()
  order by case r.status when 'pending' then 0 else 1 end,r.created_at desc;
$$;
revoke all on function public.platform_list_self_service_signups_v1() from public;
grant execute on function public.platform_list_self_service_signups_v1() to authenticated;

create or replace function public.platform_approve_self_service_signup_v1(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_req public.flori_self_service_signup_requests%rowtype;
  v_sub public.store_subscriptions%rowtype;
  v_trial_expires timestamptz;
  v_demo_days integer:=30;
  v_current_plan_code text;
begin
  if not public.is_platform_admin() then raise exception 'Acesso restrito ao Admin Master.' using errcode='42501'; end if;
  select * into v_req from public.flori_self_service_signup_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitacao nao encontrada.'; end if;
  if v_req.status='approved' then return jsonb_build_object('ok',true,'alreadyApproved',true); end if;
  if v_req.status<>'pending' then raise exception 'Somente solicitacoes pendentes podem ser aprovadas.'; end if;

  update public.flori_self_service_signup_requests
  set status='approved',reviewed_by=auth.uid(),reviewed_at=now(),rejection_reason=null,updated_at=now()
  where id=v_req.id;

  update public.stores
  set approval_status='approved',access_status='online',suspended_at=null,suspension_reason=null,updated_at=now()
  where id=v_req.store_id;

  select * into v_sub from public.store_subscriptions where store_id=v_req.store_id order by started_at desc limit 1 for update;
  if v_sub.id is not null then select upper(code) into v_current_plan_code from public.plans where id=v_sub.plan_id; end if;
  if v_sub.id is not null and v_current_plan_code='DEMO' then
    select greatest(1,coalesce(demo_duration_days,30)) into v_demo_days from public.platform_settings where id=1;
    v_trial_expires:=now()+make_interval(days=>coalesce(v_demo_days,30));
    update public.store_subscriptions set status='trial',expires_at=v_trial_expires,updated_at=now() where id=v_sub.id;
    update public.flori_self_service_signup_requests set trial_expires_at=v_trial_expires,updated_at=now() where id=v_req.id;
  elsif v_sub.id is not null and v_current_plan_code<>'DEMO' and v_sub.status in ('trial','suspended') then
    update public.store_subscriptions
    set status='active',status_before_suspension=null,expires_at=null,
        due_day=coalesce(v_sub.due_day,10),
        next_due_date=public.subscription_reference_due_v1(coalesce(v_sub.due_day,10),v_sub.next_due_date),
        updated_at=now()
    where id=v_sub.id;
  end if;

  return jsonb_build_object('ok',true,'storeId',v_req.store_id);
end;
$$;
revoke all on function public.platform_approve_self_service_signup_v1(uuid) from public;
grant execute on function public.platform_approve_self_service_signup_v1(uuid) to authenticated;

create or replace function public.platform_reject_self_service_signup_v1(p_request_id uuid,p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_req public.flori_self_service_signup_requests%rowtype;
  v_sub public.store_subscriptions%rowtype;
begin
  if not public.is_platform_admin() then raise exception 'Acesso restrito ao Admin Master.' using errcode='42501'; end if;
  select * into v_req from public.flori_self_service_signup_requests where id=p_request_id for update;
  if v_req.id is null then raise exception 'Solicitacao nao encontrada.'; end if;
  if v_req.status='rejected' then return jsonb_build_object('ok',true,'alreadyRejected',true); end if;
  if v_req.status<>'pending' then raise exception 'Somente solicitacoes pendentes podem ser rejeitadas.'; end if;

  update public.flori_self_service_signup_requests
  set status='rejected',reviewed_by=auth.uid(),reviewed_at=now(),rejection_reason=nullif(trim(coalesce(p_reason,'')),''),updated_at=now()
  where id=v_req.id;

  update public.stores
  set approval_status='rejected',access_status='suspended',suspended_at=coalesce(suspended_at,now()),
      suspension_reason=coalesce(nullif(trim(coalesce(p_reason,'')),''),'Cadastro nao aprovado pelo Admin Master'),updated_at=now()
  where id=v_req.store_id;

  select * into v_sub from public.store_subscriptions where store_id=v_req.store_id order by started_at desc limit 1 for update;
  if v_sub.id is not null and v_sub.status in ('trial','active') then
    update public.store_subscriptions
    set status='suspended',status_before_suspension=v_sub.status,updated_at=now()
    where id=v_sub.id;
  end if;

  return jsonb_build_object('ok',true,'storeId',v_req.store_id);
end;
$$;
revoke all on function public.platform_reject_self_service_signup_v1(uuid,text) from public;
grant execute on function public.platform_reject_self_service_signup_v1(uuid,text) to authenticated;

notify pgrst,'reload schema';
commit;
