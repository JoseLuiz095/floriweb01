-- FloriWeb V3 RC6.9
-- Estabilidade, cobrança e diagnóstico de interações.
-- 1) Vencimento mensal passa a aceitar dias 1..31, usando o último dia do mês quando necessário.
-- 2) Confirmação/negação de mensalidade gera auditoria server-side.
-- 3) Confirmação de recebimento do pedido gera auditoria server-side.
-- 4) Eventos de interação/erros podem ser registrados pelo frontend sem expor dados sensíveis.
-- 5) Diagnóstico do Admin Master pode consultar os eventos recentes.
-- 6) Financeiro expõe a origem do lançamento (manual/pedido/ajuste).

begin;

do $$
begin
  if to_regclass('public.store_subscriptions') is null
     or to_regclass('public.subscription_payments') is null
     or to_regclass('public.financial_entries') is null
     or to_regclass('public.orders') is null then
    raise exception 'RC6.9 requer RC6.8 aplicado.';
  end if;
end $$;

-- Remove somente constraints CHECK que mencionam due_day para recriar com 1..31.
do $$
declare r record;
begin
  for r in
    select conname
      from pg_constraint
     where conrelid='public.store_subscriptions'::regclass
       and contype='c'
       and pg_get_constraintdef(oid) ilike '%due_day%'
  loop
    execute format('alter table public.store_subscriptions drop constraint %I',r.conname);
  end loop;
end $$;

alter table public.store_subscriptions
  add constraint store_subscriptions_due_day_ck
  check(due_day is null or due_day between 1 and 31);

create or replace function public.subscription_reference_due_v1(
  p_due_day integer,
  p_reference date default null
)
returns date
language plpgsql
stable
set search_path=public,pg_temp
as $$
declare
  v_day integer := greatest(1,least(coalesce(p_due_day,10),31));
  v_month date;
  v_last_day integer;
  v_due date;
begin
  v_month := date_trunc('month',coalesce(p_reference,current_date))::date;
  v_last_day := extract(day from (v_month + interval '1 month - 1 day'))::integer;
  v_due := make_date(
    extract(year from v_month)::integer,
    extract(month from v_month)::integer,
    least(v_day,v_last_day)
  );

  if p_reference is null and v_due < current_date then
    v_month := (v_month + interval '1 month')::date;
    v_last_day := extract(day from (v_month + interval '1 month - 1 day'))::integer;
    v_due := make_date(
      extract(year from v_month)::integer,
      extract(month from v_month)::integer,
      least(v_day,v_last_day)
    );
  end if;

  return v_due;
end $$;

revoke all on function public.subscription_reference_due_v1(integer,date) from public;
grant execute on function public.subscription_reference_due_v1(integer,date) to authenticated;

-- Mantém o mês de referência atual e corrige somente o dia, inclusive 29/30/31.
update public.store_subscriptions ss
set due_day=greatest(1,least(coalesce(ss.due_day,10),31)),
    next_due_date=public.subscription_reference_due_v1(
      greatest(1,least(coalesce(ss.due_day,10),31)),
      ss.next_due_date
    )
from public.plans p
where p.id=ss.plan_id
  and p.code<>'DEMO'
  and ss.status<>'cancelled';

create table if not exists public.platform_event_log(
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  store_id uuid references public.stores(id) on delete set null,
  kind text not null default 'interaction' check(kind in('interaction','audit')),
  action text not null,
  result text not null check(result in('started','success','error','warning')),
  route text not null default '',
  duration_ms integer,
  error_code text,
  error_message text,
  app_version text,
  correlation_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists platform_event_log_created_idx on public.platform_event_log(created_at desc);
create index if not exists platform_event_log_result_idx on public.platform_event_log(result,created_at desc);
create index if not exists platform_event_log_correlation_idx on public.platform_event_log(correlation_id) where correlation_id is not null;

alter table public.platform_event_log enable row level security;
revoke all on public.platform_event_log from anon,authenticated;

create or replace function public.log_platform_event_v1(
  p_store_id uuid,
  p_kind text,
  p_action text,
  p_result text,
  p_route text default '',
  p_duration_ms integer default null,
  p_error_code text default null,
  p_error_message text default null,
  p_app_version text default null,
  p_correlation_id text default null
)
returns uuid
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_id uuid;
  v_store uuid:=p_store_id;
  v_kind text:=case when p_kind in('interaction','audit') then p_kind else 'interaction' end;
begin
  if auth.uid() is null then
    raise exception 'Sessão necessária.' using errcode='42501';
  end if;

  if p_result not in('started','success','error','warning') then
    raise exception 'Resultado de evento inválido.';
  end if;

  if v_store is not null and not (public.is_store_admin(v_store) or public.is_platform_admin()) then
    v_store:=null;
  end if;

  if v_kind='audit' and not public.is_platform_admin() then
    v_kind:='interaction';
  end if;

  insert into public.platform_event_log(
    actor_user_id,store_id,kind,action,result,route,duration_ms,error_code,error_message,app_version,correlation_id
  ) values(
    auth.uid(),v_store,v_kind,left(coalesce(p_action,'unknown'),120),p_result,left(coalesce(p_route,''),240),
    case when p_duration_ms is null then null else greatest(0,least(p_duration_ms,3600000)) end,
    nullif(left(coalesce(p_error_code,''),120),''),nullif(left(coalesce(p_error_message,''),500),''),
    nullif(left(coalesce(p_app_version,''),80),''),nullif(left(coalesce(p_correlation_id,''),120),'')
  ) returning id into v_id;

  return v_id;
end $$;

revoke all on function public.log_platform_event_v1(uuid,text,text,text,text,integer,text,text,text,text) from public;
grant execute on function public.log_platform_event_v1(uuid,text,text,text,text,integer,text,text,text,text) to authenticated;

create or replace function public.platform_list_event_log_v1(
  p_limit integer default 100,
  p_result text default null,
  p_kind text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id',x.id,
      'createdAt',x.created_at,
      'kind',x.kind,
      'action',x.action,
      'result',x.result,
      'route',x.route,
      'storeId',x.store_id,
      'storeName',s.name,
      'durationMs',x.duration_ms,
      'errorCode',x.error_code,
      'errorMessage',x.error_message,
      'appVersion',x.app_version,
      'correlationId',x.correlation_id
    ) order by x.created_at desc)
    from (
      select *
        from public.platform_event_log e
       where (p_result is null or e.result=p_result)
         and (p_kind is null or e.kind=p_kind)
       order by e.created_at desc
       limit greatest(1,least(coalesce(p_limit,100),300))
    ) x
    left join public.stores s on s.id=x.store_id
  ),'[]'::jsonb);
end $$;

revoke all on function public.platform_list_event_log_v1(integer,text,text) from public;
grant execute on function public.platform_list_event_log_v1(integer,text,text) to authenticated;

-- Confirmação manual: preserva due_day e calcula o mês seguinte pelo dia configurado.
create or replace function public.platform_confirm_subscription_payment_v1(p_payment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  pmt public.subscription_payments%rowtype;
  sub public.store_subscriptions%rowtype;
  v_reference_due date;
  v_next_due date;
  v_due_day integer;
begin
  if not public.is_platform_admin() then
    raise exception 'Acesso negado.' using errcode='42501';
  end if;

  select * into pmt from public.subscription_payments where id=p_payment_id for update;
  if not found then raise exception 'Cobrança não encontrada.'; end if;
  if pmt.status='paid' then return jsonb_build_object('ok',true,'alreadyPaid',true); end if;
  if pmt.status in('rejected','cancelled') then raise exception 'Esta cobrança foi negada/cancelada e não pode ser confirmada.'; end if;
  if pmt.proof_required and pmt.status<>'proof_sent' then raise exception 'O comprovante ainda não foi informado.'; end if;

  select * into sub
    from public.store_subscriptions
   where store_id=pmt.store_id
   order by started_at desc
   limit 1
   for update;
  if not found then raise exception 'Assinatura da loja não encontrada.'; end if;

  v_due_day:=greatest(1,least(coalesce(sub.due_day,extract(day from pmt.due_date)::integer,10),31));
  v_reference_due:=public.subscription_reference_due_v1(v_due_day,coalesce(pmt.due_date,sub.next_due_date,current_date));
  v_next_due:=public.subscription_reference_due_v1(
    v_due_day,
    (date_trunc('month',v_reference_due)+interval '1 month')::date
  );

  update public.store_subscriptions
     set plan_id=coalesce(pmt.requested_plan_id,pmt.plan_id,sub.plan_id),
         billing_amount=pmt.amount,
         status='active',
         status_before_suspension=null,
         expires_at=null,
         due_day=v_due_day,
         next_due_date=v_next_due,
         notes=concat_ws(E'\n',notes,
           'Pagamento PIX confirmado em '||to_char(now(),'DD/MM/YYYY HH24:MI')||
           ' | referência '||to_char(v_reference_due,'DD/MM/YYYY')||
           ' | próximo vencimento '||to_char(v_next_due,'DD/MM/YYYY'))
   where id=sub.id;

  update public.stores
     set access_status='online',active=true,suspended_at=null,suspension_reason=null
   where id=pmt.store_id;

  update public.subscription_payments
     set status='paid',paid_at=now(),rejected_at=null,rejection_reason=null,reviewed_by=auth.uid(),due_date=v_reference_due
   where id=pmt.id;

  insert into public.platform_event_log(actor_user_id,store_id,kind,action,result,route,app_version,metadata)
  values(auth.uid(),pmt.store_id,'audit',
    case when pmt.payment_intent='plan_change' then 'subscription_plan_change_confirmed' else 'subscription_renewal_confirmed' end,
    'success','/admin-master/pagamentos','3.0.0-rc.6.9',
    jsonb_build_object('paymentId',pmt.id,'amount',pmt.amount,'referenceDueDate',v_reference_due,'nextDueDate',v_next_due));

  return jsonb_build_object('ok',true,'paidAt',now(),'referenceDueDate',v_reference_due,'nextDueDate',v_next_due);
end $$;

revoke all on function public.platform_confirm_subscription_payment_v1(uuid) from public;
grant execute on function public.platform_confirm_subscription_payment_v1(uuid) to authenticated;

create or replace function public.platform_reject_subscription_payment_v1(
  p_payment_id uuid,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_payment public.subscription_payments%rowtype;
  v_reason text;
begin
  if not public.is_platform_admin() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  select * into v_payment from public.subscription_payments where id=p_payment_id for update;
  if not found then raise exception 'Cobrança não encontrada.'; end if;
  if v_payment.status='paid' then raise exception 'Pagamento já confirmado não pode ser negado.'; end if;
  if v_payment.status in('cancelled','rejected') then return jsonb_build_object('ok',true,'alreadyRejected',true); end if;

  v_reason:=nullif(trim(coalesce(p_reason,'')),'');
  update public.subscription_payments
     set status='rejected',rejected_at=now(),rejection_reason=coalesce(v_reason,'Pagamento/renovação não confirmado pelo Admin Master.'),reviewed_by=auth.uid()
   where id=p_payment_id;

  insert into public.platform_event_log(actor_user_id,store_id,kind,action,result,route,app_version,metadata)
  values(auth.uid(),v_payment.store_id,'audit',
    case when v_payment.payment_intent='plan_change' then 'subscription_plan_change_rejected' else 'subscription_renewal_rejected' end,
    'success','/admin-master/pagamentos','3.0.0-rc.6.9',
    jsonb_build_object('paymentId',v_payment.id,'reason',coalesce(v_reason,'Pagamento/renovação não confirmado pelo Admin Master.')));

  return jsonb_build_object('ok',true);
end $$;

revoke all on function public.platform_reject_subscription_payment_v1(uuid,text) from public;
grant execute on function public.platform_reject_subscription_payment_v1(uuid,text) to authenticated;

create or replace function public.confirm_order_payment_v1(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
  v_order public.orders%rowtype;
  v_already_paid boolean;
begin
  select * into v_order from public.orders where id=p_order_id for update;
  if not found then raise exception 'Pedido não encontrado.'; end if;
  if not public.is_store_admin(v_order.store_id) and not public.is_platform_admin() then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if v_order.status='cancelled' then raise exception 'Não é possível confirmar o recebimento de um pedido cancelado.'; end if;
  if coalesce(v_order.total,0)<=0 then raise exception 'O pedido não possui valor válido para recebimento.'; end if;

  v_already_paid:=v_order.payment_status='paid';
  update public.orders
     set payment_status='paid',payment_received_at=coalesce(payment_received_at,now()),payment_confirmed_by=coalesce(payment_confirmed_by,auth.uid())
   where id=p_order_id
   returning * into v_order;

  if not v_already_paid then
    insert into public.platform_event_log(actor_user_id,store_id,kind,action,result,route,app_version,metadata)
    values(auth.uid(),v_order.store_id,'audit','order_payment_confirmed','success','/admin/pedidos','3.0.0-rc.6.9',
      jsonb_build_object('orderId',v_order.id,'orderNumber',v_order.order_number,'amount',v_order.total));
  end if;

  return jsonb_build_object('ok',true,'alreadyPaid',v_already_paid,'orderId',v_order.id,'paymentReceivedAt',v_order.payment_received_at,'amount',v_order.total);
end $$;

revoke all on function public.confirm_order_payment_v1(uuid) from public;
grant execute on function public.confirm_order_payment_v1(uuid) to authenticated;

-- Financeiro: mantém os dados anteriores e passa a informar claramente a origem.
create or replace function public.get_store_financial_overview_v1(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_temp
as $$
declare
  i numeric:=0;
  e numeric:=0;
  ar numeric:=0;
  ap numeric:=0;
begin
  if not public.is_store_admin(p_store_id) then raise exception 'Acesso negado.' using errcode='42501'; end if;
  if not public.store_finance_enabled(p_store_id) then raise exception 'O plano atual não inclui o módulo Financeiro.' using errcode='42501'; end if;

  select
    coalesce(sum(amount) filter(where direction='income' and status='paid'),0),
    coalesce(sum(amount) filter(where direction='expense' and status='paid'),0),
    coalesce(sum(amount) filter(where direction='income' and status='pending'),0),
    coalesce(sum(amount) filter(where direction='expense' and status='pending'),0)
  into i,e,ar,ap
  from public.financial_entries
  where store_id=p_store_id and status<>'cancelled';

  return jsonb_build_object(
    'income',i,'expense',e,'result',i-e,'receivable',ar,'payable',ap,
    'entries',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',f.id,'storeId',f.store_id,'direction',f.direction,'source',f.source,'orderId',f.order_id,
        'description',f.description,'category',f.category,'amount',f.amount,'occurredOn',f.occurred_on,
        'dueOn',f.due_on,'paidAt',f.paid_at,'status',f.status,'paymentMethod',f.payment_method,
        'counterparty',f.counterparty,'documentType',f.document_type,'documentNumber',f.document_number,
        'notes',f.notes,'createdAt',f.created_at
      ) order by f.occurred_on desc,f.created_at desc)
      from (select * from public.financial_entries where store_id=p_store_id and status<>'cancelled' order by occurred_on desc,created_at desc limit 100) f
    ),'[]'::jsonb),
    'expenseByCategory',coalesce((
      select jsonb_agg(jsonb_build_object('category',x.category,'amount',x.amount) order by x.amount desc)
      from (select category,sum(amount) amount from public.financial_entries where store_id=p_store_id and direction='expense' and status='paid' group by category)x
    ),'[]'::jsonb),
    'monthly',coalesce((
      select jsonb_agg(jsonb_build_object('month',to_char(m.month_start,'YYYY-MM'),'income',coalesce(x.income,0),'expense',coalesce(x.expense,0)) order by m.month_start)
      from (select generate_series(date_trunc('month',current_date)-interval '5 months',date_trunc('month',current_date),interval '1 month')::date month_start)m
      left join (
        select date_trunc('month',occurred_on)::date month_start,
               sum(amount) filter(where direction='income' and status='paid') income,
               sum(amount) filter(where direction='expense' and status='paid') expense
          from public.financial_entries
         where store_id=p_store_id and occurred_on>=date_trunc('month',current_date)-interval '5 months'
         group by 1
      )x using(month_start)
    ),'[]'::jsonb)
  );
end $$;

revoke all on function public.get_store_financial_overview_v1(uuid) from public;
grant execute on function public.get_store_financial_overview_v1(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
